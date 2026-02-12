# SOLECTRUS for Proxmox VE

This is a fork of [community-scripts/ProxmoxVE](https://github.com/community-scripts/ProxmoxVE) that adds a SOLECTRUS installer script.

> **Work in progress** - This fork is under active development. The goal is to get SOLECTRUS included in the official community-scripts repository.

## Installation

Run the following command in your **Proxmox VE Shell**:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/solectrus/ProxmoxVE/main/ct/solectrus.sh)"
```

This creates a Debian 13 LXC container with Docker and Docker Compose. During installation, `compose.yaml` and `.env` are fetched from the SOLECTRUS repository. Credentials are generated automatically and the following containers are started:

- InfluxDB, PostgreSQL, Redis
- SOLECTRUS Dashboard
- Power-Splitter
- Watchtower for automatic container updates

After installation, credentials are stored in `~/solectrus.creds` inside the container.

## Update

Log into the LXC container and run `update`. Additionally, [Watchtower](https://watchtower.nickfedor.com/) checks once daily for new Docker images and updates them automatically.

## Data Sources

SOLECTRUS does not read sensor data directly. You need a Smart Home system to collect the data and push it to InfluxDB:

- **Home Assistant:** [SOLECTRUS HA Integration](https://github.com/solectrus/ha-integration)
- **ioBroker:** [ioBroker.solectrus-influxdb](https://github.com/patricknitsch/ioBroker.solectrus-influxdb)

## Links

- [SOLECTRUS Documentation](https://docs.solectrus.de/)
- [SOLECTRUS Website](https://solectrus.de/)
