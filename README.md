# ZTP Containerlab Demo

A containerlab topology demonstrating Arista Zero Touch Provisioning (ZTP). Switches boot with no configuration, receive a bootstrap script via DHCP, and configure themselves automatically.

Two bootstrap workflows are included:

- **Local bootstrap** (`bootstrap.py`) — Downloads an EOS image (if version mismatches) and a per-device config from an HTTP server on `mgmt-sw01`, then applies it.
- **CloudVision bootstrap** (`bootstrap-cv.py`) — Enrolls the switch into CVaaS or on-prem CloudVision using an enrollment token, then executes the CV-provided bootstrap.

## Demo Lifecycle

```
make start          Deploy the lab (web server off, switches in ZTP mode)
     │
make ztp-start      Enable web server → switches download bootstrap → ZTP completes
     │
make ztp-stop       Disable web server (MUST do before reset, or switches re-ZTP immediately)
     │
make ztp-reset      Wipe startup-config and restart switches → back to ZTP mode
     │
make ztp-start      Re-enable web server → ZTP runs again
     │
make stop           Tear down the entire lab
```

## Topology

```
                  ┌─────────────┐
                  │  mgmt-sw01  │
                  │ DHCP + HTTPS│
                  └──┬───┬───┬──┘
           et1       │   │   │
     ┌───────────────┘   │   └───────────────┐
     │            et2    │            et3    │
┌────┴──────┐    ┌───────┴───────┐   ┌───────┴───────┐
│ztp-switch1│    │  ztp-switch2  │   │  ztp-switch3  │
│   (ZTP)   │    │    (ZTP)      │   │    (ZTP)      │
└───────────┘    └───────────────┘   └───────────────┘
```

| Node | Role | Mgmt IP |
|------|------|---------|
| mgmt-sw01 | ZTP server (DHCP + HTTPS) | 192.168.128.104 |
| ztp-switch1 | ZTP client | 192.168.128.101 |
| ztp-switch2 | ZTP client | 192.168.128.102 |
| ztp-switch3 | ZTP client | 192.168.128.103 |

## System Requirements

| Requirement | Notes |
|-------------|-------|
| Docker | Container runtime for cEOS images |
| [Containerlab](https://containerlab.dev/install/) | Network lab orchestration (`sudo` required) |
| Python 3.11+ | For config generation (`jinja2`, `pyyaml`) |
| Arista cEOS image | Download from [arista.com](https://www.arista.com/en/support/software-download) (free account required) |

### Import the cEOS image

Download the cEOS-lab tarball from the Arista software portal, then import it:

```bash
# For .tar files
docker import images/cEOS64-lab-4.35.6M.tar ceos:4.35.6M

# For .tar.xz files
xz -d images/cEOS64-lab-4.36.2F.tar.xz
docker import images/cEOS64-lab-4.36.2F.tar ceos:4.36.2F
```

The Docker tag (e.g., `ceos:4.35.6M`) must match the `ceos_image` value in `demo-config.yaml`.

### Install Python dependencies

```bash
pip install jinja2 pyyaml
```

## Getting Started

### 1. Configure the lab

Edit `demo-config.yaml` — this is the single source of configuration for the entire lab:

```yaml
ceos_image: "ceos:4.35.6M"            # Must match your imported Docker image

enable_bridge: true                   # Connect lab to host network?
bridge_interface: "enp86s0"           # Your host NIC (run 'ip link show')
egress_ip: "10.0.100.226/24"          # IP for mgmt-sw01 uplink
egress_gateway: "10.0.100.1"          # Default gateway

bootstrap_type: "local"               # "local" or "cloudvision"
desired_eos_version: "4.35.7M"        # Must match a file in clab/eos_images/
```

See [Configuration Reference](#configuration-reference) for all available options.

### 2. Deploy the lab

```bash
make start
```

This generates all config files from templates, then deploys via containerlab. The web server on `mgmt-sw01` starts **disabled** — ZTP will not begin until you enable it.

### 3. Verify the lab is up

```bash
make inspect
```

Wait for all nodes to show a healthy status. You can also check individual devices:

```bash
make console DEV=mgmt-sw01       # Open EOS CLI
make logs DEV=ztp-switch1        # Follow container logs
```

### 4. Start ZTP

When you're ready to begin the ZTP process:

```bash
make ztp-start
```

This enables the web server on `mgmt-sw01`. The ZTP switches will begin downloading and executing their bootstrap scripts.

### 5. Watch it happen

```bash
# Follow logs on a ZTP switch to see the bootstrap in action
make logs DEV=ztp-switch1

# Or open a CLI to check the config was applied
make console DEV=ztp-switch1
```

### 6. Reset and re-run ZTP

To wipe the switches and re-run ZTP from scratch:

```bash
make ztp-stop         # MUST stop the web server first, or switches re-ZTP immediately
make ztp-reset        # Wipe startup-config on all ZTP switches and restart them
make ztp-start        # Re-enable web server → ZTP runs again
```

To reset a single switch:

```bash
make ztp-stop
make ztp-reset DEV=ztp-switch2
make ztp-start
```

### 7. Tear down

```bash
make stop         # Destroy the entire lab
```

## Configuration Reference

All options are in `demo-config.yaml`:

| Key | Default | Description |
|-----|---------|-------------|
| `ceos_image` | `ceos:4.35.6M` | Docker image tag for all nodes |
| `enable_bridge` | `true` | Create macvlan uplink to host network |
| `bridge_interface` | `enp86s0` | Host NIC for macvlan (required if bridge enabled) |
| `egress_ip` | `10.0.100.226/24` | IP/mask for mgmt-sw01 Ethernet10 |
| `egress_gateway` | `10.0.100.1` | Default route via Ethernet10 |
| `bootstrap_type` | `local` | `"local"` or `"cloudvision"` |
| `desired_eos_version` | `4.35.7M` | Target EOS version for local bootstrap |
| `cv_url` | `www.cv-staging.corp.arista.io` | CloudVision address |
| `enrollment_token` | `token-here` | CV enrollment token (from Device Registration page) |
| `ntp_server` | `50.205.57.38` | NTP server for CV bootstrap |
| `boot_sleep_time` | `15` | Seconds to pause after simulated image install |
| `restart_wait_time` | `15` | Seconds to pause before ProcMgr restart |

After editing, run `make generate` (or just `make start`, which regenerates automatically).

## Lab Workflow

### What happens during ZTP

1. **Lab deploys** — All 4 switches boot. `mgmt-sw01` loads its full config (DHCP server, VLANs). ZTP switches boot with empty configs and enter ZTP mode.
2. **You enable the web server** (`make ztp-start`) — The HTTPS server on `mgmt-sw01` starts serving bootstrap files.
3. **DHCP** — Each ZTP switch sends a DHCP discover on the inband VLAN (192.168.130.0/24). `mgmt-sw01` responds with an IP and the bootstrap script URL.
4. **Bootstrap runs** — The switch downloads and executes the bootstrap script. For local bootstrap:
   - Reads device serial number via `show version`
   - Compares EOS version, downloads new image if mismatched
   - Downloads per-device config from `https://192.168.130.1/configs/<serial>.cfg`
   - Runs `zerotouch cancel` and restarts services

### What success looks like

- ZTP switch gets a hostname (e.g., `spine-sw01` instead of `localhost`)
- `show running-config` shows the full per-device config
- `show zerotouch` shows ZTP is cancelled
- Inter-switch links come up with the configured VLANs and MLAG

### What failure looks like

| Symptom | Likely Cause |
|---------|-------------|
| ZTP switch stuck at `localhost` | Web server not enabled (`make ztp-start`) or DHCP not reaching switch |
| `Download failed` in logs | Wrong `desired_eos_version` or missing file in `clab/eos_images/` |
| `Configuration download failed` | Serial number doesn't match any file in `clab/boot_configs/` |
| DHCP timeout | Check that mgmt-sw01 is up and the inband VLAN is configured |
| Token expired (CV bootstrap) | Enrollment token has expired — generate a new one in CloudVision |

## Accessing Devices

| Method | Command |
|--------|---------|
| EOS CLI | `make console DEV=<node>` |
| Container logs | `make logs DEV=<node>` |
| SSH | `ssh admin@<node>` (password: `admin`) |
| SSH | `ssh arista@<node>` (password: `arista`) |

Node names: `mgmt-sw01`, `ztp-switch1`, `ztp-switch2`, `ztp-switch3`

## File Structure

```
demo-config.yaml              # Central configuration — edit this
scripts/generate.py            # Renders templates into lab files
templates/                     # Jinja2 source templates
  topology.clab.yml.j2
  mgmt-sw01.cfg.j2
  bootstrap.py.j2
  bootstrap-cv.py.j2
clab/                          # Generated + static lab files
  topology.clab.yml            # Generated from template
  configs/
    mgmt-sw01.cfg              # Generated from template
    empty.cfg                  # Static — triggers ZTP mode
  bootstrap/
    bootstrap.py               # Generated from template
    bootstrap-cv.py            # Generated from template
  boot_configs/
    <serial>.cfg               # Per-device configs (static)
  eos_images/
    EOS-<version>.swi          # EOS images served to switches
  sn/
    *.txt                      # Serial number files per node
```

## Virtual Caveats

This lab runs on cEOS, which has some differences from hardware:

- **No real reload** — `bootstrap.py` simulates the boot-system/reload step since cEOS doesn't support it. On real hardware, the switch would install the SWI and reload.
- **zerotouch-config** — The file is bind-mounted and may not be deletable from within the container. The bootstrap uses `zerotouch cancel` instead.
- **NTP sync** — `bootstrap-cv.py` requires NTP sync before contacting CloudVision. In a virtual lab, NTP may behave differently than on physical switches.

## Troubleshooting

### AppArmor (Ubuntu)

If containerlab has permission issues on Ubuntu:

```bash
# Add apparmor=0 to GRUB_CMDLINE_LINUX in /etc/default/grub
sudo vi /etc/default/grub
GRUB_CMDLINE_LINUX="apparmor=0"

# Then run update and reboot
sudo update-grub
sudo reboot
```

### Bridge interface not found

If the lab fails to start with a macvlan error, verify your host NIC name:

```bash
ip link show
```

Update `bridge_interface` in `demo-config.yaml` to match, or set `enable_bridge: false` to disable external connectivity.

### External access to lab network

If you need to reach the 192.168.128.0/24 management network from your host, you may need static routes. The lab uses containerlab's built-in management network for this subnet. 
