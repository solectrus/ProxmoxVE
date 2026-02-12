# SOLECTRUS for Proxmox VE

> **Experimental** - This fork is under active development and not yet part of the official community-scripts repository. Use at your own risk.

This is a fork of [community-scripts/ProxmoxVE](https://github.com/community-scripts/ProxmoxVE) that adds a SOLECTRUS installer script.

## Installation

Run the following command in your **Proxmox VE Shell**:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/solectrus/ProxmoxVE/main/ct/solectrus.sh)"
```

This creates a Debian 13 LXC container with:

- Docker + Docker Compose
- InfluxDB, PostgreSQL, Redis
- SOLECTRUS Dashboard
- Power-Splitter
- Watchtower for automatic container updates

After installation, credentials are stored in `~/solectrus.creds` inside the container.

## Update

Run the same command again and select "Update" when prompted.

## Data Sources

SOLECTRUS does not read inverter data directly. You need a Smart Home system to collect the data and push it to InfluxDB:

- **Home Assistant:** [SOLECTRUS HA Integration](https://github.com/solectrus/ha-integration)
- **ioBroker:** [ioBroker.solectrus-influxdb](https://github.com/patricknitsch/ioBroker.solectrus-influxdb)

## Links

- [SOLECTRUS Documentation](https://docs.solectrus.de/)
- [SOLECTRUS Website](https://solectrus.de/)
