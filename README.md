# SOLECTRUS for Proxmox VE

This is a fork of [community-scripts/ProxmoxVE](https://github.com/community-scripts/ProxmoxVE) that adds a SOLECTRUS installer script.

> **Work in progress** - This fork is under active development. The goal is to get SOLECTRUS included in the official community-scripts repository.

## Installation

Run the following command in your **Proxmox VE Shell**:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/solectrus/ProxmoxVE/main/ct/solectrus.sh)"
```

This creates a Debian 13 LXC container with Docker and Docker Compose and installs [HELIOS](https://github.com/solectrus/helios), the SOLECTRUS configuration manager. Credentials are generated automatically and HELIOS is started on port `3999`.

Open the HELIOS web interface at `http://<ip>:3999` and log in with the generated admin password. From there you configure and start the full SOLECTRUS stack (Dashboard, InfluxDB, PostgreSQL, Redis, collectors, Watchtower) — no Docker or Linux expertise required.

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
