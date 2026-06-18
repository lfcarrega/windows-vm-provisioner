# windows-vm-provisioner

## Why

Because I wanted an easy way to fully deploy Windows machines without relying on Windows-only toolkits or cloud solutions.

## How It Works

- A Windows PE is built from a full Windows Installation ISO
- The `src/overlay/` dir is injected into the final WinPE ISO
- The `src/overlay/Windows/System32/startnet.cmd` fires up with the provided logic
- A HTTP listener starts running on the WinPE
- You can control it remotely via `curl` and PowerShell scripts

## Usage

1. Clone this repo and cd into the `src` dir:
```sh
git clone https://github.com/lfcarrega/windows-vm-provisioner
cd windows-vm-provisioner/src
```

2. Download a Windows ISO, for example the Windows Server 2025 ISO https://www.microsoft.com/en-us/evalcenter/download-windows-server-2025:
```sh
wget "https://software-static.download.prss.microsoft.com/dbazure/998969d5-f34g-4e03-ac9d-1f9786c66749/26100.32230.260111-0550.lt_release_svc_refresh_SERVER_EVAL_x64FRE_en-us.iso" -O iso/win.iso
```

3. Check the Makefile and edit accordingly, mainly the REMOTE_* or the `deploy:` action:
```
### alternative

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
	sudo cp $(OUT_ISO) /var/lib/libvirt/images

server:
	darkhttpd server/
```

4. Run make:
```sh
# to build the ISO
make build
# to build the ISO with a different location and filename
make build BASE_ISO=../../Downloads/26100.32230.260111-0550.lt_release_svc_refresh_SERVER_EVAL_x64FRE_en-us.iso
# to deploy the final ISO
make deploy
```

5. Go into your WinPE machine, make sure it's connected to the network and get the IP address (the `startnet.cmd` is configured to print this information automatically)

6. Now you can control this machine remotely with `curl`, change `@server/test.ps1` to your real deploy script:
```sh
curl -X POST http://192.168.15.121:8080/ --data-binary @server/test.ps1 -H "Content-Type: text/plain; charset=utf-8"
```

## Good to Know

* `Write-Host` will print its content to the `cmd` screen, not to the `curl` output
* You can fire a HTTP file server on your "controller" and send files to the WinPE machine, there is an action called `server:` in the Makefile - you'll need `darkhttpd`, but feel free to change it
* If something goes wrong while building the ISO, you can check the log file `src/log`
* You can use the great script `mido.sh` created by @ElliotKillick to automatically download Windows ISOs
* Adapt the `src/overlay/` as you wish
* Check out the `src/server/` dir, you can find a barebones deployment script there

## TODO

- [ ] Write the PowerShell deployment script (partition, format, apply WIM, bootloader)
- [ ] Add authentication to the HTTP listener
- [ ] Improve error handling