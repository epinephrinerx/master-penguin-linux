#!/bin/sh
# Checks the three things PID 1 has to get right, then powers off.
# Runs automatically when the kernel command line contains `selftest`.

sleep 1
fail=0
check() {
    if [ "$2" = "$3" ]; then
        echo "  ok    $1"
    else
        echo "  FAIL  $1 -- got '$2', wanted '$3'"
        fail=1
    fi
}

# The supervised shell is the one whose parent is PID 1.
shell_pid() {
    for d in /proc/[0-9]*; do
        [ -r "$d/stat" ] || continue
        # /proc/<pid>/stat: pid (comm) state ppid ...
        set -- $(cat "$d/stat" 2>/dev/null)
        [ "$2" = "(sh)" ] && [ "$4" = "1" ] && { echo "$1"; return; }
    done
}

echo
echo "=== mpinit selftest ==="

check "pid 1 is mpinit" "$(basename "$(readlink -f /proc/1/exe)")" "mpinit"

# 1. Orphan adoption. The inner shell starts a sleep, records its pid and exits
#    immediately, which leaves the sleep parentless for the kernel to hand to
#    PID 1. We then read that pid's ppid from the outside.
#
#    Note it has to be read from outside: `cat /proc/self/stat` would report
#    cat's own ppid, since /proc/self is whichever process does the reading.
rm -f /tmp/orphan.pid
sh -c 'sleep 5 & echo $! > /tmp/orphan.pid'
sleep 2
orphan=$(cat /tmp/orphan.pid 2>/dev/null)
check "orphan reparented to pid 1" "$(awk '{print $4}' /proc/$orphan/stat 2>/dev/null)" "1"

# 2. Reaping: nothing left in state Z once init has waited on them.
check "no zombies left behind" "$(awk '$3=="Z"' /proc/[0-9]*/stat 2>/dev/null | wc -l)" "0"

# 3. Respawn: kill the supervised shell, a different one should replace it.
old=$(shell_pid)
kill -9 "$old" 2>/dev/null
sleep 3
new=$(shell_pid)
if [ -n "$new" ] && [ "$new" != "$old" ]; then
    echo "  ok    respawned the shell (pid $old -> $new)"
else
    echo "  FAIL  respawn -- old '$old', new '$new'"
    fail=1
fi

if [ $fail -eq 0 ]; then echo "=== selftest PASSED ==="; else echo "=== selftest FAILED ==="; fi
echo

# Also exercises the clean shutdown path: poweroff signals PID 1, which stops
# everything, syncs, remounts / read-only and calls reboot(RB_POWER_OFF).
poweroff
