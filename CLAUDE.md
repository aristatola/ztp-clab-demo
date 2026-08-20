# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Containerlab-based demo for Arista Zero Touch Provisioning (ZTP). Four cEOS containers form a virtual network: one management switch (`mgmt-sw01`) runs DHCP and an HTTPS server (EOS's built-in NGINX via `management api http-commands`), three client switches (`ztp-switch1/2/3`) boot with no config and self-provision via ZTP.

Two ZTP workflows:
- **Local** (`clab/bootstrap/bootstrap.py`) — downloads EOS image + per-device config from mgmt-sw01
- **CloudVision** (`clab/bootstrap/bootstrap-cv.py`) — enrolls switch into CloudVision using a token

## Configuration & Generation

All user-configurable variables live in `demo-config.yaml` at the repo root. A Python script (`scripts/generate.py`) reads this file and renders Jinja2 templates from `templates/` into the `clab/` directory:

| Template | Output |
|----------|--------|
| `templates/topology.clab.yml.j2` | `clab/topology.clab.yml` |
| `templates/mgmt-sw01.cfg.j2` | `clab/configs/mgmt-sw01.cfg` |
| `templates/bootstrap.py.j2` | `clab/bootstrap/bootstrap.py` |
| `templates/bootstrap-cv.py.j2` | `clab/bootstrap/bootstrap-cv.py` |

When modifying lab behavior, edit templates (not generated files). Run `make generate` to regenerate, or `make start` which regenerates automatically.

Dependencies: `jinja2`, `pyyaml` (declared in `pyproject.toml`).

## Lab Operations

```bash
make generate                  # Render templates from demo-config.yaml
make start                     # Generate + deploy lab
make stop                      # Destroy lab
make inspect                   # Show node IPs and status
make ztp-start                 # Enable HTTPS server on mgmt-sw01 (triggers ZTP)
make ztp-stop                  # Disable HTTPS server on mgmt-sw01
make console DEV=<node>        # Open EOS CLI (e.g., DEV=ztp-switch1)
make logs DEV=<node>           # Follow container logs
```

All containerlab commands run with `sudo`. Container names match node names directly (no prefix).

## Architecture

**ZTP trigger mechanism**: The web server on mgmt-sw01 starts **disabled** (`management api http-commands` → `shutdown`). `make ztp-start` enables it via EOS CLI commands (the `web on` alias). This lets users observe the topology before triggering ZTP.

**HTTPS serving**: EOS's `management api http-commands` runs NGINX on port 443. Bootstrap files, configs, and EOS images are bind-mounted to `/usr/share/nginx/html/` in the topology. DHCP hands switches `https://192.168.130.1/ztp/bootstrap.py` as the bootfile URL.

**Serial number → config mapping**: Each switch has a serial number file in `clab/sn/` (e.g., `ztp-switch1.txt` → `JPE10000011`). The bootstrap script reads this serial and fetches the matching config from `clab/boot_configs/` (e.g., `JPE10000011.cfg`).

**Networks**: `192.168.128.0/24` is the containerlab management network. `192.168.130.0/24` is the inband ZTP VLAN where DHCP and bootstrap traffic flows.

## Development Notes

- Bootstrap scripts run inside the cEOS container's Python interpreter, not on the host. They use EOS-specific libraries (`FastCli`, `SysdbHelperUtils`, `TerminAttr`).
- `bootstrap-cv.py` is Python 2/3 compatible (Arista-provided, Apache 2.0 licensed). `bootstrap.py` is Python 3 only.
- The topology references host NIC via `bridge_interface` in config for the macvlan uplink. Set `enable_bridge: false` to omit it.
- No tests or CI exist. Changes are validated by deploying the lab and observing ZTP behavior.
