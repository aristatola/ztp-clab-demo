# ZTP Containerlab Demo

A containerlab topology demonstrating Arista Zero Touch Provisioning (ZTP) — switches boot with no configuration, receive a bootstrap script via DHCP, and configure themselves automatically.

Two bootstrap workflows are included:

- **`bootstrap.py`** — Standalone ZTP: downloads an EOS image (if needed) and a per-device config from an HTTP server, then applies it.
- **`bootstrap-cv.py`** — CloudVision ZTP: enrolls the switch into CVaaS/on-prem CV using an enrollment token, then executes the CV-provided bootstrap.

## Topology

```
                  ┌─────────────┐
                  │  mgmt-sw01  │
                  │ DHCP + HTTP │
                  └──┬───┬───┬──┘
           et1       │   │   │
     ┌───────────────┘   │   └───────────────┐
     │            et2    │            et3     │
┌────┴──────┐   ┌───────┴───────┐   ┌───────┴───────┐
│ztp-switch1│   │  ztp-switch2  │   │  ztp-switch3  │
│   (ZTP)   │   │    (ZTP)      │   │    (ZTP)      │
└───────────┘   └───────────────┘   └───────────────┘
```

| Node | Role | Mgmt IP |
|------|------|---------|
| mgmt-sw01 | ZTP server (DHCP + NGINX) | 192.168.128.104 |
| ztp-switch1 | ZTP client | 192.168.128.101 |
| ztp-switch2 | ZTP client | 192.168.128.102 |
| ztp-switch3 | ZTP client | 192.168.128.103 |

## Prerequisites

- Docker
- [Containerlab](https://containerlab.dev/install/)
- Arista cEOS image imported:
  ```bash
  docker import cEOS64-lab-<version>.tar ceos:<version>
  ```

## Quick Start

```bash
make start     # deploy the lab
make inspect   # show node IPs and status
make stop      # tear down the lab
```

Connect to a switch:

```bash
docker exec -it ztp-switch1 Cli
show zerotouch
```

## How It Works

1. **mgmt-sw01** boots with a full config: DHCP server on the management network, NGINX serving bootstrap scripts and configs.
2. **ztp-switch{1,2,3}** boot with empty configs and enter ZTP mode.
3. Each ZTP switch sends a DHCP discover; mgmt-sw01 responds with an IP and the bootstrap script URL.
4. The switch downloads and executes the bootstrap script.

## File Structure

```
clab/
  topology.clab.yml          # Containerlab topology
  configs/
    empty.cfg                # Empty config for ZTP switches
    mgmt-sw01.cfg            # DHCP + NGINX server config
  bootstrap/
    bootstrap.py             # Standalone bootstrap (no CV)
    bootstrap-cv.py          # CloudVision bootstrap
  boot_configs/
    <serial>.cfg             # Per-device configs (keyed by serial number)
  eos_images/
    EOS-<version>.swi        # EOS images served to ZTP switches
  sn/
    *.txt                    # Serial number files for each node
  zerotouch-config           # Controls ZTP mode on boot
```

## Virtual Caveats

This lab runs on cEOS, which has some differences from hardware:

- **No real reload** — `bootstrap.py` simulates the boot-system/reload step since cEOS doesn't support it the same way. On real hardware, the switch would install the SWI and reload.
- **zerotouch-config** — The file is bind-mounted and may not be deletable from within the container. The bootstrap uses `zerotouch cancel` instead.
- **NTP sync** — `bootstrap-cv.py` requires NTP sync before contacting CV. In a virtual lab, NTP may behave differently than on physical switches.

## Customization

Edit `bootstrap.py` to change the standalone ZTP logic (server IP, desired EOS version, config retrieval). For CV enrollment, update `bootstrap-cv.py` with your `cvAddr`, `enrollmentToken`, and `ntpServer`.

Per-device configs go in `clab/boot_configs/` named by serial number (e.g., `JPE10000011.cfg`).

## Disabling AppArmor (Ubuntu)

If containerlab has permission issues on Ubuntu:

```bash
# Add apparmor=0 to GRUB_CMDLINE_LINUX in /etc/default/grub
sudo update-grub
sudo reboot
```
