# ZTP Clab Demo

A containerlab topology for testing Arista Zero Touch Provisioning (ZTP).

## What is ZTP?

Zero Touch Provisioning (ZTP) allows Arista switches to automatically configure
themselves when they boot up for the first time. Instead of manually logging into
each switch, ZTP automates the process:

1. The switch boots with no configuration
2. It sends a DHCP request to get an IP address
3. The DHCP server also tells the switch where to find a bootstrap script
4. The switch downloads and runs the bootstrap script, which configures it

## Topology

```
                   Management Network (172.100.100.0/24)
                   ┌──────────┬──────────┬──────────┐
                   │          │          │          │
              ┌────┴────┐ ┌──┴───┐ ┌───┴────┐     │
              │  switch3 │ │switch1│ │switch2 │   (gateway)
              │  (server)│ │ (ZTP) │ │ (ZTP)  │
              │ DHCP+HTTP│ │      │ │        │
              └─────────┘ └──┬───┘ └───┬────┘
                              │   et1   │
                              └─────────┘
```

| Node | Role | Management IP |
|------|------|---------------|
| ztp-switch1 | ZTP client (boots with no config) | 172.100.100.101 |
| ztp-switch2 | ZTP client (boots with no config) | 172.100.100.102 |
| ztp-switch3 | ZTP server (DHCP + HTTP) | 172.100.100.103 |

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Containerlab](https://containerlab.dev/install/)
- Arista cEOS image imported as `arista/ceos:latest`
  ```bash
  docker import cEOS64-lab-<version>.tar arista/ceos:latest
  ```

## Quick Start

```bash
# Deploy the lab
containerlab deploy -t clab/topology.clab.yml

# Check that all containers are running
docker ps

# Connect to a ZTP switch to watch the ZTP process
docker exec -it ztp-switch1 Cli

# On the switch, check ZTP status
show zerotouch

# Connect to the ZTP server
docker exec -it ztp-switch3 Cli

# Tear down the lab when done
containerlab destroy -t clab/topology.clab.yml
```

## File Structure

```
clab/
  topology.clab.yml       # Main topology definition
  configs/
    empty.cfg              # Empty config (used by ZTP switches)
    ztp-switch3.cfg        # ZTP server config (DHCP + HTTP)
  sn/
    ztp-switch1.txt        # Serial number for switch 1
    ztp-switch2.txt        # Serial number for switch 2
    ztp-switch3.txt        # Serial number for switch 3
  bootstrap/
    bootstrap.py           # Python bootstrap script served to ZTP switches
  zerotouch-config         # Controls whether ZTP is enabled on the switches
```

## How ZTP Works in This Lab

1. **ztp-switch3** boots first with a full configuration that includes:
   - A DHCP server listening on the management network
   - A Python HTTP server on port 80 serving files from `/mnt/flash/bootstrap/`

2. **ztp-switch1** and **ztp-switch2** boot with no configuration and enter ZTP mode

3. Each ZTP switch sends a DHCP discover on the management interface

4. ztp-switch3's DHCP server responds with:
   - An IP address (from the 172.100.100.201-210 range)
   - The bootstrap script filename (`bootstrap.py`)
   - The HTTP server address (172.100.100.103)

5. The ZTP switch downloads `bootstrap.py` from `http://172.100.100.103/bootstrap.py`
   and executes it

## Customizing the Bootstrap Script

Edit `clab/bootstrap/bootstrap.py` with your desired ZTP logic. Common tasks:
- Apply a startup configuration
- Install EOS extensions
- Register with a management platform (e.g., CloudVision)
