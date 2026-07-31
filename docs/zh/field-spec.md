# 字段规格

## 通用规则

字段名使用

```text
snake_case
```

结构

```text
<模块输出顶层>
```

独立输出无模块名包裹。聚合器添加模块名 key。

---

## OS (modules/os.sh)

```text
name          string   发行版名称 (如 Ubuntu)
id            string   发行版 ID (如 ubuntu)
version       string   版本号 (如 22.04)
pretty_name   string   可读名称
kernel        string   内核版本 来自 uname -r
```

示例:

```json
{"name":"Ubuntu","id":"ubuntu","version":"22.04","pretty_name":"Ubuntu 22.04.5 LTS","kernel":"5.15.0-185-generic"}
```

---

## CPU (modules/cpu.sh)

```text
vendor        string   CPU 厂商 (GenuineIntel, AuthenticAMD)
model         string   lscpu 中的型号名
arch          string   架构 (x86_64, aarch64)
cores         integer  物理核心总数 (路数 * 每路核心数)
threads       integer  逻辑线程总数
socket_count  integer  物理 CPU 路数
```

示例:

```json
{"vendor":"GenuineIntel","model":"INTEL(R) XEON(R) PLATINUM 8581C","arch":"x86_64","cores":120,"threads":240,"socket_count":2}
```

---

## Memory (modules/memory.sh)

```text
total_bytes      integer   物理内存总量 单位字节
available_bytes  integer   可用内存 单位字节
modules          array     DIMM 模块详情
  vendor         string    制造商
  model          string    部件号
  type           string    DDR 类型 (DDR3, DDR4, DDR5)
  capacity       string    容量 (如 64GB)
  speed          string    标称速率
  serial         string    序列号
```

示例:

```json
{"total_bytes":1081384607744,"available_bytes":1069742297088,"modules":[{"vendor":"Samsung","model":"M321R8GA0BB0-CQKZJ","type":"DDR5","capacity":"64GB","speed":"4800 MT/s","serial":"48815A2E"}]}
```

---

## Disk (modules/disk.sh)

```text
disks           array    物理磁盘设备
  vendor        string   厂商名
  model         string   型号名
  size_bytes    integer  原始大小 单位字节
  type          string   NVMe SSD / SSD / HDD / DISK
  serial        string   序列号
```

示例:

```json
{"disks":[{"vendor":"","model":"Samsung SSD 990 EVO 1TB","size_bytes":1000204886016,"type":"NVMe SSD","serial":"S7GCNL0XB05230K"}]}
```

---

## GPU (modules/gpu.sh)

```text
[对象数组]
  vendor       string   NVIDIA / AMD
  index        string   GPU 索引
  name         string   GPU 产品名
  uuid         string   GPU UUID
  pci_bus_id   string   PCI 总线地址
  vbios        string   VBIOS 版本
  serial       string   序列号
  memory       string   显存 (如 84GB)
  driver       string   驱动版本
```

---

## NIC (modules/nic.sh)

```text
nics              array    网卡设备
  slot            string   PCI 基地址
  model           string   lspci 中的型号
  sn              string   序列号
  type            string   PCIe / OCP / rNDC / Mezzanine / LOM
  port_count      integer  端口数量
  ports           array    端口详情
    slot          string   PCI 槽位 (含功能号)
    interface     string   接口名 (ens15f0)
    mac           string   MAC 地址
    current_speed string   当前链路速率或 NotConnected
    max_speed      string  支持的最高速率
```

---

## Power (modules/power.sh)

```text
supplies        array     电源模块
  vendor        string    制造商
  model         string    部件号
  serial        string    序列号
  location      string    物理槽位
  max_power     string    额定功率 (如 2700 W)
  status        string    Present, OK / 其他
  type          string    Switching / Linear
```

---

## 单位命名规范

数值字段在字段名中注明单位

```text
_bytes
_mhz
_ghz
_count
_percent
```
