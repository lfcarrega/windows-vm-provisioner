# firejail profile

# Based on qemu-common but allowing KVM
include /etc/firejail/qemu-common.profile

# Override restrictive settings
ignore nogroups
ignore private-dev
