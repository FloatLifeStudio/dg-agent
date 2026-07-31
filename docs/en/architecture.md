DG-Agent Architecture Specification

### 1. Goal

DG-Agent is a lightweight hardware asset collection framework.

Its responsibilities are:

- Collect hardware information
- Collect operating system information
- Normalize collected data
- Export data using a unified JSON interface
- Remain modular and extensible

DG-Agent is **not** responsible for:

- CMDB synchronization
- Database storage
- Service management
- Remote execution

---

### 2. Design Principles

The project follows these principles.

#### KISS

Keep every component as simple as possible.
No abstraction for hypothetical future requirements.

#### Single Responsibility

Every layer has only one responsibility.

| Layer      | Responsibility   |
| ---------- | ---------------- |
| Module     | Collect data and output JSON |
| Dispatcher | Schedule modules and aggregate |
| Library    | Shared string utilities and logging |
| Output     | Write aggregated result |

#### High Cohesion

Each module focuses on one hardware or software component only.

```text
cpu.sh  -> CPU only
os.sh   -> OS only
disk.sh -> disk only
```

#### Low Coupling

Modules must never depend on each other.
Modules must never source library files.
Only the dispatcher is allowed to invoke modules.

#### One-way Dependency

The dependency direction is fixed.

```text
dg-agent.sh
  -> lib/cleaner.sh, lib/logger.sh
  -> modules/*.sh  (invoked as subprocess, no source)
```

Reverse dependencies are prohibited.

---

### 3. Runtime Workflow

```text
CLI
  -> Root check (non-root exec sudo automatically)
  -> Argument Parser
  -> Module Runner (invoke each module as bash subprocess)
  -> JSON Aggregator (wrap results under module-name keys)
  -> Output (stdout or file)
```

---

### 4. Module Lifecycle

```text
Root check (exit 5 if not root)
  -> Collect (lscpu, dmidecode, nvidia-smi, /sys, /proc ...)
  -> Normalize (trim, filter placeholders)
  -> Output flat JSON to stdout
```

---

### 5. Output Format

#### Mode A: Aggregated (dg-agent.sh)

```json
{
  "os": { "name": "Ubuntu", "id": "ubuntu", ... },
  "cpu": { "vendor": "Intel", "model": "...", "cores": 8, ... }
}
```

Each module's JSON is wrapped under its module name as the top-level key.

#### Mode B: Standalone (modules/os.sh)

```json
{ "name": "Ubuntu", "id": "ubuntu", "version": "22.04", ... }
```

Flat JSON object, no wrapper key.

---

### 6. File Structure

```text
dg-agent/
  dg-agent.sh           Dispatch and aggregation entry point
  modules/
    os.sh               OS information
    cpu.sh              CPU information
    memory.sh           Memory information
    disk.sh             Disk information
    gpu.sh              GPU information
    nic.sh              NIC information
    power.sh            Power supply information
  lib/
    cleaner.sh          trim / normalize / json_escape (pure Bash)
    logger.sh           Logging with verbose control
    formatter.sh        key=value to JSON converter (legacy)
    tools/
      dmi.sh            Full dmidecode dump as JSON
      lshw.sh           Full lshw dump as JSON
  docs/
    en/                 Architecture and specification docs
