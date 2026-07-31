## File Name

```text
snake_case
```

Example

```text
network.sh
power_supply.sh
```

---

## Function

```text
snake_case
```

Example

```bash
collect_cpu
parse_arguments
build_json
load_module
```

---

## Private Function

Prefix

```text
_
```

Example

```bash
_json_escape
_parse_cpu
_trim
```

---

## Variable

```text
snake_case
```

Example

```bash
module_name
output_file
json_buffer
```

---

## Constant

```text
UPPER_CASE
```

Example

```bash
SCRIPT_DIR
VERSION
DEFAULT_OUTPUT
```

---

## Shell Style

Always use

```bash
$( )
```

instead of

```bash
``
```

Always use

```bash
[[ ]]
```

instead of

```bash
[ ]
```

Always quote variables

```bash
"${var}"
```

Use

```bash
local
```

inside every function.

---

## Comment Style

Comments use Chinese text but must never contain Chinese punctuation marks
such as ， 。 ： 、 ； （ ） 《 》 【 】.

Comments are single-line. Use a second line only when the comment
genuinely cannot fit on one line.

Comments must not end with any punctuation symbol.

```bash
# 正确的注释格式
# 这是第一行说明 第二行补充细节
```

Incorrect:

```bash
# 错误的注释，有逗号。
# 错误的注释: 有冒号
# 错误的注释（有括号）
```

---

## Module Self-Containment

Every module is a self-contained script:

- Does NOT source any file from lib/ or elsewhere
- Inlines its own utility functions (trim, normalize, json_escape)
- Can be invoked directly: `bash modules/os.sh`
- Outputs clean flat JSON to stdout
- All logging and errors go to stderr

---

## Root Permission

All modules and the agent require root. Modules exit with code 5
if not running as root.

```bash
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    printf '{"error":"root required (use sudo)"}\n' >&2
    exit 5
fi
```

The agent (dg-agent.sh) auto-re-execs with sudo when not root
(except for --help and -h which bypass the root check).
