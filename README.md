# dg-agent

轻量级硬件资产采集框架。一条命令导出完整服务器硬件信息为 JSON。

## 设计原则

- **KISS** — 一层一责, 不为假设的需求提前抽象
- **模块化** — 每个模块是独立脚本, 可单独或组合运行
- **高内聚低耦合** — 模块间零依赖, 模块与库零耦合
- **纯 Bash** — 核心清洗逻辑不依赖 awk/sed, 用 Bash 原生实现

## 采集内容

| 模块 | 文件 | 数据源 |
|------|------|--------|
| OS | modules/os.sh | /etc/os-release, uname |
| CPU | modules/cpu.sh | lscpu |
| 内存 | modules/memory.sh | dmidecode, /proc/meminfo |
| 磁盘 | modules/disk.sh | lsblk |
| GPU | modules/gpu.sh | nvidia-smi / rocm-smi |
| 网卡 | modules/nic.sh | /sys/class/net, lspci, ethtool |
| 电源 | modules/power.sh | dmidecode -t 39 |

## 快速开始

```bash
git clone https://github.com/FloatLifeStudio/dg-agent.git
cd dg-agent

# 运行单个模块
sudo bash modules/os.sh
sudo bash modules/cpu.sh

# 聚合运行多个模块
sudo bash dg-agent.sh --cpu --os

# 全量采集并写入文件
sudo bash dg-agent.sh --all --output /tmp/asset.json --verbose

# 查看所有选项
bash dg-agent.sh --help
```

## 输出格式

### 聚合模式 (dg-agent.sh)

```json
{
  "os": {"name":"Ubuntu","id":"ubuntu","version":"22.04","pretty_name":"Ubuntu 22.04.5 LTS","kernel":"5.15.0-185-generic"},
  "cpu": {"vendor":"GenuineIntel","model":"INTEL(R) XEON(R) PLATINUM 8581C","arch":"x86_64","cores":120,"threads":240,"socket_count":2}
}
```

### 独立模式 (modules/os.sh)

```json
{"name":"Ubuntu","id":"ubuntu","version":"22.04","pretty_name":"Ubuntu 22.04.5 LTS","kernel":"5.15.0-185-generic"}
```

## 架构

```text
dg-agent.sh (调度器 + CLI)
  -> lib/cleaner.sh   纯 Bash 字符串清洗
  -> lib/logger.sh    日志 (支持 verbose)
  -> modules/*.sh     独立采集模块 (子进程调用, 不用 source)
```

## 要求

- Bash 4.0+
- root 权限 (所有模块和调度器)
- 各模块对应工具: lscpu, dmidecode, lsblk, nvidia-smi 等

## 文档

- [架构规格](docs/zh/architecture.md)
- [模块规格](docs/zh/module-spec.md)
- [字段规格](docs/zh/field-spec.md)
- [编码规范](docs/zh/coding-style.md)
- [错误码](docs/zh/error-code.md)

## License

MIT — 见 [LICENSE](./LICENSE)
