## General Rules

Field names use

```text
snake_case
```

Structure

```text
<module_output_top_level>
```

No module-name wrapper in standalone output.
The aggregator adds the module-name key.

---

## OS (modules/os.sh)

```text
name          string   Distribution name (e.g. Ubuntu)
id            string   Distribution ID (e.g. ubuntu)
version       string   Version number (e.g. 22.04)
pretty_name   string   Human-readable name
kernel        string   Kernel version from uname -r
```

Example:

```json
{"name":"Ubuntu","id":"ubuntu","version":"22.04","pretty_name":"Ubuntu 22.04.5 LTS","kernel":"5.15.0-185-generic"}
```

---

## CPU (modules/cpu.sh)

```text
vendor        string   CPU vendor (GenuineIntel, AuthenticAMD)
model         string   Model name from lscpu
arch          string   Architecture (x86_64, aarch64)
cores         integer  Total physical cores (sockets * cores_per_socket)
threads       integer  Total logical threads
socket_count  integer  Number of physical CPU sockets
```

Example:

```json
{"vendor":"GenuineIntel","model":"INTEL(R) XEON(R) PLATINUM 8581C","arch":"x86_64","cores":120,"threads":240,"socket_count":2}
```

---

## Memory (modules/memory.sh)

```text
total_bytes      integer   Total physical memory in bytes
available_bytes  integer   Available memory in bytes
modules          array     DIMM module details
  vendor         string    Manufacturer
  model          string    Part number
  type           string    DDR type (DDR3, DDR4, DDR5)
  capacity       string    Capacity (e.g. 64GB)
  speed          string    Rated speed
  serial         string    Serial number
```

Example:

```json
{"total_bytes":1081384607744,"available_bytes":1069742297088,"modules":[{"vendor":"Samsung","model":"M321R8GA0BB0-CQKZJ","type":"DDR5","capacity":"64GB","speed":"4800 MT/s","serial":"48815A2E"}]}
```

---

## Disk (modules/disk.sh)

```text
disks           array    Physical disk devices
  vendor        string   Vendor name
  model         string   Model name
  size_bytes    integer  Raw size in bytes
  type          string   NVMe SSD / SSD / HDD / DISK
  serial        string   Serial number
```

Example:

```json
{"disks":[{"vendor":"","model":"Samsung SSD 990 EVO 1TB","size_bytes":1000204886016,"type":"NVMe SSD","serial":"S7GCNL0XB05230K"}]}
```

---

## GPU (modules/gpu.sh)

```text
[array of objects]
  vendor       string   NVIDIA / AMD
  index        string   GPU index
  name         string   GPU product name
  uuid         string   GPU UUID
  pci_bus_id   string   PCI bus address
  vbios        string   VBIOS version
  serial       string   Serial number
  memory       string   VRAM (e.g. 84GB)
  driver       string   Driver version
```

---

## NIC (modules/nic.sh)

```text
nics              array    Network adapters
  slot            string   PCI base address
  model           string   Model from lspci
  sn              string   Serial number
  type            string   PCIe / OCP / rNDC / Mezzanine / LOM
  port_count      integer  Number of ports
  ports           array    Port details
    slot          string   PCI slot (with function number)
    interface     string   Interface name (ens15f0)
    mac           string   MAC address
    current_speed string   Current link speed or NotConnected
    max_speed      string  Maximum supported speed
```

---

## Power (modules/power.sh)

```text
supplies        array     Power supply units
  vendor        string    Manufacturer
  model         string    Part number
  serial        string    Serial number
  location      string    Physical slot
  max_power     string    Rated power (e.g. 2700 W)
  status        string    Present, OK / other
  type          string    Switching / Linear
```

---

## Unit Naming Convention

Include unit in field name when holding a numeric value.

```text
_bytes
_mhz
_ghz
_count
_percent
```
