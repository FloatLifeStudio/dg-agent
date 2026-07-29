
[![License: MIT](https://img.shields.io/badge/license-MIT-brightgreen.svg)](./LICENSE)
[![Shell](https://img.shields.io/badge/shell-Bash-green.svg)](https://www.gnu.org/software/bash/)
[![GitHub issues](https://img.shields.io/github/issues/FloatLifeStudio/dg-agent)](https://github.com/FloatLifeStudio/dg-agent/issues)
[![GitHub stars](https://img.shields.io/github/stars/FloatLifeStudio/dg-agent)](https://github.com/FloatLifeStudio/dg-agent/stargazers)

# dg-agent

**dg-agent** is an automated collection system that quickly gathers server information and exports it as JSON files. It makes data collection easy and effortless.

## Design Principles

- **Simple** — One command, one JSON file. No complicated setup.
- **Modular** — Each collector is a separate script; add or remove as needed.
- **Zero dependencies** — Pure Bash + standard Linux utilities.

## What it collects

- System: OS, kernel, hostname, architecture, uptime
- CPU: model, cores, sockets, load average, frequency
- Memory: total, used, available, swap
- Disk: devices, mount points, usage
- GPU: utilization, memory, temperature, fan speed
- Network: interfaces, IP addresses
- BIOS: vendor, version, release date

## Use dg-agent

You can clone and run dg-agent directly. See our [Quick Start](#quick-start) for details on getting started.

Power users and contributors can run the `main` branch, which has the latest features and fixes. Although it is reasonably stable, you may encounter changes. We recommend getting involved in the dg-agent community if you want to run the latest code.

### Quick Start

```bash
git clone https://github.com/FloatLifeStudio/dg-agent.git
cd dg-agent
bash dg-agent.sh
```

## License

See the [LICENSE](./LICENSE) file for the full text.
