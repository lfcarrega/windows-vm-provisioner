# windows-vm-provisioner

## Why

Because I wanted an easy way to fully deploy Windows machines without relying on Windows-only toolkits or cloud solutions.

## How It Works

- A Windows PE is built from a full Windows Installation ISO
- The `src/overlay/` dir is injected into the final WinPE ISO
- The `src/overlay/Windows/System32/startnet.cmd` fires up with the provided logic
- A HTTP listener/agent starts running on the WinPE
- The agent sends information back to the controller
- You can control it remotely via `curl` and PowerShell scripts or the pre-made Ansible `src/playbook`

## Usage

#. Clone this repo and cd into the `src` dir:
```sh
git clone https://github.com/lfcarrega/windows-vm-provisioner
cd windows-vm-provisioner/src
```

#. Download a Windows ISO, for example the Windows Server 2025 ISO https://www.microsoft.com/en-us/evalcenter/download-windows-server-2025:
```sh
wget "https://software-static.download.prss.microsoft.com/dbazure/998969d5-f34g-4e03-ac9d-1f9786c66749/26100.32230.260111-0550.lt_release_svc_refresh_SERVER_EVAL_x64FRE_en-us.iso" -O iso/win.iso
```

#. Cd into the the `collector` dir and build the collector (edit the source code `main.go` and change the AuthCode/Port as needed):
```sh
cd collector/
nano main.go
make
cp collector ../server/collector
cd ..
```

#. Go back and cd into the `agent` dir, edit the source code `main.go`, like the `CollectorAddress` and `AuthToken` consts, then build it;
```sh
cd agent/
nano main.go
make
cp agent.exe ../overlay/tools/agent.exe
cd ..
```

#. On both `agent` and `collector` source codes you can find mentions to `cerberus.key` or `cerberus.crt`, these can be generated with `scripts/generate-certs.sh`:
```sh
cd scripts/
./generate-certs.sh
cp cerberus.key ../server/
cp cerberus.crt ../server/

cp cerberus.key ../overlay/tools/
cp cerberus.crt ../overlay/tools/
cd ..
```

#. Now check `src/Makefile` and edit accordingly, mainly the REMOTE_* or the `deploy:` action:
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

#. Run make:
```sh
# to build the ISO using iso/win.iso as the BASE_ISO
make build
# to build the ISO with a different BASE_ISO location/filename
make build BASE_ISO=../../Downloads/26100.32230.260111-0550.lt_release_svc_refresh_SERVER_EVAL_x64FRE_en-us.iso
# to deploy or copy the final ISO
make deploy
```

#. Start the collector:
```sh
cd server/
./collector
```

#. Add your wimfile to `server/install.wim` - can be extracted from the previously downloaded Windows ISO:
```sh
sudo mount --mkdir ../../Downloads/26100.32230.260111-0550.lt_release_svc_refresh_SERVER_EVAL_x64FRE_en-us.iso iso/win2k25
cp iso/win2k25/sources/install.wim server/
```

#. Don't forget to run your HTTP server (for the wimfile):
```sh
make server
```

#. Now you can run the Ansible playbook `src/playbook`, make sure to add you variables to the env.yaml file
```sh
cd playbook/
cp env.example.yaml env.yaml
nano env.yaml # or any text editor
ansible-playbook winpe.yaml
```
NOTE: Edit `playbook/templates/deploy.ps1.j2` as you wish

## Good to Know

* `Write-Host` will print its content to the `cmd` screen, not to the `curl` output - for now, this is only true if you're using `listener.ps1`
* You can fire a HTTP file server on your "controller" and send files to the WinPE machine, there is an action called `server:` in the Makefile - you'll need `darkhttpd`, but feel free to change it
* If something goes wrong while building the ISO, you can check the log file `src/log`
* You can use the great script `mido.sh` created by @ElliotKillick to automatically download Windows ISOs
* Adapt the `src/overlay/` as you wish
* Check out the `src/server/` dir, you can find a barebones deployment script there
* Check out `src/scripts/generate-certs.sh` if you need to generate a self-signed cert for HTTPs/TLS
* Now you can also control this machine remotely with only `curl`, change `@server/test.ps1` to your real deploy script:
```sh
curl -X POST http://<WINPE_IP>:8080/ --data-binary @server/test.ps1 -H "Content-Type: text/plain; charset=utf-8"
```
Or, if you're using the `agent.exe` instead of the default `listener.ps1` (considering you're also using HTTPs with a self-signed cert):
```sh
curl -k -X POST https://<WINPE_IP>:8443/ -d "ipconfig" -H "Content-Type: text/plain; charset=utf-8" -H "X-Auth-Token: SuperSecretToken"
```

NOTE: use `--data-binary` if you're running a separate PowerShell script, use `-d` if you're running single commands like `ipconfig`

## TODO

- [X] Write the PowerShell deployment script (partition, format, apply WIM, bootloader) - Done with a Ansible Playbook
- [X] Add authentication to the HTTP listener - Check the src/agent/ dir
- [ ] Improve error handling