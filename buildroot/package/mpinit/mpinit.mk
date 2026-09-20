################################################################################
#
# mpinit — PID 1 for master penguin linux
#
# The source is shared with the hand-built track at the top of the repo, so
# there is exactly one copy of the init and both targets compile it: this one
# with Buildroot's cross toolchain, the other with the host compiler.
#
################################################################################

MPINIT_VERSION = 1.0
MPINIT_SITE = $(BR2_EXTERNAL_MASTER_PENGUIN_PATH)/../src
MPINIT_SITE_METHOD = local
MPINIT_LICENSE = MIT

define MPINIT_BUILD_CMDS
	$(TARGET_CC) $(TARGET_CFLAGS) -Wall -Wextra \
		-o $(@D)/mpinit $(@D)/mpinit.c $(TARGET_LDFLAGS)
endef

define MPINIT_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/mpinit $(TARGET_DIR)/sbin/mpinit
	ln -sf mpinit $(TARGET_DIR)/sbin/init
endef

$(eval $(generic-package))
