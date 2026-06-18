REMOTE_ADDRESS = 192.168.15.2
REMOTE_USER = root
REMOTE_PATH = /var/lib/libvirt/images

BASE_ISO ?= iso/win.iso
OUT_ISO ?= out/winpe.iso
OVERLAY_DIR ?= overlay

.PHONY: build build_debug deploy server

all: build

build:
	@echo "Building WinPE ISO"
	sudo scripts/create-iso.sh $(BASE_ISO) $(OUT_ISO) $(OVERLAY_DIR)

build_debug:
	@echo "Building WinPE ISO (debug)"
	sudo DEBUG=1 scripts/create-iso.sh $(BASE_ISO) $(OUT_ISO) $(OVERLAY_DIR)

deploy:
	@echo "Copying files to ${REMOTE_USER}@${REMOTE_ADDRESS}:${REMOTE_PATH}"
	scp $(OUT_ISO) ${REMOTE_USER}@${REMOTE_ADDRESS}:${REMOTE_PATH}

server:
	darkhttpd server/