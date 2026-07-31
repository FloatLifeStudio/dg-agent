## Module Specification

### Responsibilities

A module is responsible for:

- Detecting and requiring root permission
- Collecting hardware or OS information
- Normalizing collected data
- Outputting a flat JSON object to stdout

A module is NOT responsible for:

- Logging (errors go to stderr only)
- Command-line parsing
- Output file writing
- Wrapping its output under a module-name key
- Sourcing library files

---

### Lifecycle

```text
Root check -> Collect -> Normalize -> Output JSON
```

---

### Public Interface

Every module is a standalone executable script.

```bash
# Direct invocation
bash modules/os.sh
bash modules/cpu.sh
```

The module must output exactly one JSON object to stdout and exit 0
on success, or exit non-zero on failure with an error JSON on stderr.

---

### Output Format

Modules output flat JSON. No wrapper key. No key=value.

```json
{"name":"Ubuntu","id":"ubuntu","version":"22.04"}
```

Invalid formats:

```text
JSON with wrapper:  {"os": {"name": "Ubuntu"}}
key=value:          os_name=Ubuntu
YAML / XML / CSV
```

---

### Root Requirement

All modules must check for root at startup and exit with code 5 if not root.

```bash
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    printf '{"error":"root required (use sudo)"}\n' >&2
    exit 5
fi
```

---

### Self-Containment

Modules must never source external files.

Every utility function (trim, normalize, json_escape) must be
defined inline within the module itself.

---

### Dependencies

Modules may use:

```text
Linux utilities (lscpu, dmidecode, nvidia-smi, ethtool, lspci, lsblk)
Kernel interfaces (/proc/meminfo, /sys/class/net)
jq (for JSON processing in complex modules)
```

Modules must never depend on:

```text
Other modules
lib/ files
Formatter / Logger
```

---

### Error Handling

Modules exit non-zero on failure. The dispatcher (dg-agent.sh)
catches failures per module and continues with remaining modules.

```bash
command -v lscpu >/dev/null 2>&1 || {
    printf '{"error":"lscpu not found"}\n' >&2
    exit 1
}
```
