/*
 * mpinit - PID 1 for master penguin linux.
 *
 * The kernel gives PID 1 three jobs nobody else can do:
 *
 *   1. Never exit. If PID 1 returns or is killed, the kernel panics on the
 *      spot: "Attempted to kill init!". Every path below either loops forever
 *      or calls reboot(). There is no third option.
 *
 *   2. Reap the dead. When a process exits, its children are reparented to
 *      PID 1. If PID 1 never calls wait() on them they stay as zombies -
 *      an exit status nobody collected, still holding a process table slot.
 *      Leak enough of those and the machine can no longer fork.
 *
 *   3. Keep services running, and bring the system down cleanly when asked.
 *
 * Compiled static, because the root filesystem has no shared libc to load.
 */

#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mount.h>
#include <sys/reboot.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

#define CONF_PATH     "/etc/mpinit.conf"
#define MAX_SERVICES  16
#define MAX_ARGS      16
#define LINE_MAX_LEN  256

/* Respawn throttle: more than BURST restarts inside WINDOW seconds and we back
 * off, so a service that dies instantly cannot spin the CPU forever. */
#define RESPAWN_BURST   5
#define RESPAWN_WINDOW  10
#define RESPAWN_PAUSE   5

/*
 * A_RESPAWN and A_DAEMON differ in exactly one thing: whether the service gets
 * a controlling terminal. Only one session can own the console at a time, so
 * handing it to every service means they fight over it. Interactive things (a
 * shell) need it; a compositor talking to DRM does not.
 */
enum action { A_SYSINIT, A_RESPAWN, A_DAEMON };

struct service {
    enum action action;
    char        line[LINE_MAX_LEN];   /* backing store that argv points into */
    char       *argv[MAX_ARGS + 1];
    pid_t       pid;                  /* 0 when not running */
    int         restarts;
    time_t      window_start;
};

static struct service services[MAX_SERVICES];
static int            nservices;

/* What a shutdown signal asked for. Deliberately a small enum of our own rather
 * than the RB_* constants: those are unsigned and not all of them fit in a
 * sig_atomic_t, which is the only type a signal handler may write safely. */
enum shutdown_kind { SD_NONE = 0, SD_HALT, SD_POWEROFF, SD_REBOOT };

/* The real work happens back in the main loop, once waitpid() is interrupted. */
static volatile sig_atomic_t want_shutdown;   /* an enum shutdown_kind */

static void say(const char *msg)
{
    /* One write() rather than three, so a message cannot be interleaved with
     * whatever a service is printing to the same console. Only ever called
     * from normal context - the signal handler below just sets a flag. */
    char buf[LINE_MAX_LEN];
    int  n = snprintf(buf, sizeof buf, "[mpinit] %s\n", msg);

    if (n > 0 && write(STDOUT_FILENO, buf, (size_t)n) < 0) {
        /* The console is gone. There is nowhere left to report that. */
    }
}

static void on_signal(int sig)
{
    /* The BusyBox halt/poweroff/reboot applets signal PID 1 exactly this way,
     * so those commands keep working even though init is no longer BusyBox. */
    switch (sig) {
    case SIGUSR1: want_shutdown = SD_HALT;     break;
    case SIGUSR2: want_shutdown = SD_POWEROFF; break;
    case SIGTERM: want_shutdown = SD_REBOOT;   break;
    case SIGINT:  want_shutdown = SD_REBOOT;   break;  /* ctrl-alt-del */
    }
}

/* ---------------------------------------------------------------- config -- */

/* Split a line in place into argv. Returns the number of arguments. */
static int tokenize(char *s, char **argv, int max)
{
    int n = 0;

    while (*s && n < max) {
        while (*s == ' ' || *s == '\t') *s++ = '\0';
        if (!*s) break;
        argv[n++] = s;
        while (*s && *s != ' ' && *s != '\t') s++;
    }
    argv[n] = NULL;
    return n;
}

static void add_service(enum action action, const char *cmd)
{
    struct service *sv;

    if (nservices >= MAX_SERVICES) return;

    sv = &services[nservices];
    sv->action = action;
    snprintf(sv->line, sizeof sv->line, "%s", cmd);
    if (tokenize(sv->line, sv->argv, MAX_ARGS) == 0) return;
    nservices++;
}

/*
 * /etc/mpinit.conf, one service per line:
 *
 *     sysinit /etc/init.d/rcS    run once, to completion, before anything else
 *     respawn /bin/sh            keep running; restart whenever it exits
 */
static void load_config(void)
{
    char  line[LINE_MAX_LEN];
    FILE *f = fopen(CONF_PATH, "r");

    if (!f) {
        say("no " CONF_PATH ", falling back to a bare shell");
        add_service(A_RESPAWN, "/bin/sh");
        return;
    }

    while (fgets(line, sizeof line, f)) {
        char *p = line;
        char *verb;

        line[strcspn(line, "\n")] = '\0';
        while (*p == ' ' || *p == '\t') p++;
        if (*p == '#' || *p == '\0') continue;

        verb = p;
        while (*p && *p != ' ' && *p != '\t') p++;
        if (*p) *p++ = '\0';
        while (*p == ' ' || *p == '\t') p++;
        if (!*p) continue;

        if      (!strcmp(verb, "sysinit")) add_service(A_SYSINIT, p);
        else if (!strcmp(verb, "respawn")) add_service(A_RESPAWN, p);
        else if (!strcmp(verb, "daemon"))  add_service(A_DAEMON,  p);
        else                               say("unknown action in config");
    }
    fclose(f);

    if (nservices == 0) add_service(A_RESPAWN, "/bin/sh");
}

/* ------------------------------------------------------------- spawning -- */

/*
 * Everything a freshly forked child needs before exec:
 *
 *  - /dev/console on stdin, stdout and stderr
 *  - default signal handling, because handlers and masks survive fork()
 *  - and for interactive services only, its own session with the console as a
 *    controlling terminal, which is what makes Ctrl-C and job control work
 *    (exactly what BusyBox cttyhack does)
 *
 * That last part is deliberately withheld from sysinit scripts. A session
 * leader that owns a controlling terminal triggers disassociate_ctty() when it
 * exits, and on the console that means a vhangup which throws away whatever
 * output is still queued. A boot script that prints and exits would lose its
 * last few lines, which is a miserable thing to debug.
 */
static void child_setup(int want_ctty)
{
    int fd;

    if (want_ctty) setsid();

    fd = open("/dev/console", O_RDWR);
    if (fd >= 0) {
        if (want_ctty) ioctl(fd, TIOCSCTTY, 1);
        dup2(fd, STDIN_FILENO);
        dup2(fd, STDOUT_FILENO);
        dup2(fd, STDERR_FILENO);
        if (fd > STDERR_FILENO) close(fd);
    }

    signal(SIGUSR1, SIG_DFL);
    signal(SIGUSR2, SIG_DFL);
    signal(SIGTERM, SIG_DFL);
    signal(SIGINT,  SIG_DFL);
    signal(SIGHUP,  SIG_DFL);
}

static pid_t spawn(struct service *sv)
{
    pid_t pid = fork();

    if (pid < 0) return -1;
    if (pid == 0) {
        child_setup(sv->action == A_RESPAWN);
        execv(sv->argv[0], sv->argv);
        _exit(127);            /* exec failed; never fall back into init code */
    }
    return pid;
}

/* ------------------------------------------------------------- shutdown -- */

static void shutdown_system(enum shutdown_kind kind)
{
    int         how;
    const char *what;

    switch (kind) {
    case SD_HALT:     how = (int)RB_HALT_SYSTEM; what = "halting";      break;
    case SD_POWEROFF: how = (int)RB_POWER_OFF;   what = "powering off"; break;
    default:          how = (int)RB_AUTOBOOT;    what = "rebooting";    break;
    }
    say(what);

    /* Ask everything to stop, give it a moment, then insist. kill(-1, ...)
     * means every process we are allowed to signal, except ourselves. */
    kill(-1, SIGTERM);
    sync();
    sleep(2);
    kill(-1, SIGKILL);
    sleep(1);

    /* Flush, then drop the root filesystem to read-only. Without this the ext4
     * journal is left dirty and the next boot has to recover it. */
    sync();
    if (mount(NULL, "/", NULL, MS_REMOUNT | MS_RDONLY, NULL) != 0)
        say("could not remount / read-only");

    reboot(how);

    /* reboot() only returns on failure - and PID 1 still may not exit. */
    say("reboot() failed; parking here");
    for (;;) pause();
}

/* ------------------------------------------------------------------ main -- */

int main(void)
{
    struct sigaction sa;
    int fd;
    int i;

    if (getpid() != 1) {
        fprintf(stderr, "mpinit: must run as PID 1\n");
        return 1;
    }

    close(STDIN_FILENO);
    close(STDOUT_FILENO);
    close(STDERR_FILENO);

    fd = open("/dev/console", O_RDWR);
    if (fd < 0) {
        /* No /dev yet. Booting a real root filesystem, either the kernel
         * mounted devtmpfs itself or an initramfs moved it across before
         * switch_root. Booting *as* an initramfs — a live CD, say — neither
         * happens, and without /dev/console there is nowhere to say so. */
        mount("devtmpfs", "/dev", "devtmpfs", MS_NOSUID, "mode=0755");
        fd = open("/dev/console", O_RDWR);
    }
    if (fd >= 0) {
        dup2(fd, STDOUT_FILENO);
        dup2(fd, STDERR_FILENO);
        if (fd > STDERR_FILENO) close(fd);
    }

    memset(&sa, 0, sizeof sa);
    sa.sa_handler = on_signal;
    sigemptyset(&sa.sa_mask);
    /* Deliberately no SA_RESTART: these should interrupt waitpid() so the main
     * loop wakes up and notices want_shutdown. */
    sigaction(SIGUSR1, &sa, NULL);
    sigaction(SIGUSR2, &sa, NULL);
    sigaction(SIGTERM, &sa, NULL);
    sigaction(SIGINT,  &sa, NULL);
    signal(SIGHUP, SIG_IGN);

    /* Deliver Ctrl-Alt-Del to us as SIGINT rather than letting the kernel
     * reboot instantly, so we get the chance to shut down cleanly. */
    reboot(RB_DISABLE_CAD);

    say("starting");
    load_config();

    /* Phase 1: sysinit, one at a time, each to completion. Nothing else should
     * run while the filesystems are still being set up. */
    for (i = 0; i < nservices; i++) {
        pid_t pid;
        pid_t done;
        int   status;

        if (services[i].action != A_SYSINIT) continue;

        pid = spawn(&services[i]);
        if (pid < 0) continue;
        do {
            done = waitpid(pid, &status, 0);
        } while (done < 0 && errno == EINTR);
    }

    /* Phase 2: supervise. From here the loop only ever leaves via reboot(). */
    for (;;) {
        time_t now;
        pid_t  pid;
        int    status;

        if (want_shutdown != SD_NONE)
            shutdown_system((enum shutdown_kind)want_shutdown);

        now = time(NULL);
        for (i = 0; i < nservices; i++) {
            struct service *sv = &services[i];

            if (sv->action == A_SYSINIT || sv->pid != 0) continue;

            if (now - sv->window_start > RESPAWN_WINDOW) {
                sv->window_start = now;
                sv->restarts = 0;
            }
            if (++sv->restarts > RESPAWN_BURST) {
                say("respawning too fast, backing off");
                sleep(RESPAWN_PAUSE);
                sv->window_start = time(NULL);
                sv->restarts = 0;
            }
            sv->pid = spawn(sv);
        }

        /* The one call that does the reaping. It blocks until some child dies:
         * a service we started, or an orphan the kernel handed us. */
        pid = waitpid(-1, &status, 0);
        if (pid < 0) {
            if (errno == EINTR)  continue;      /* signal arrived; loop around */
            if (errno == ECHILD) { sleep(1); continue; }
            continue;
        }

        for (i = 0; i < nservices; i++)
            if (services[i].pid == pid) services[i].pid = 0;

        /* A pid that matched nothing was an orphan. Reaping it was the entire
         * job; there is nothing else to do with it. */
    }
}
