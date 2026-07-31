# 编码规范

## 文件命名

```text
snake_case
```

示例

```text
network.sh
power_supply.sh
```

---

## 函数

```text
snake_case
```

示例

```bash
collect_cpu
parse_arguments
build_json
load_module
```

---

## 私有函数

前缀

```text
_
```

示例

```bash
_json_escape
_parse_cpu
_trim
```

---

## 变量

```text
snake_case
```

示例

```bash
module_name
output_file
json_buffer
```

---

## 常量

```text
UPPER_CASE
```

示例

```bash
SCRIPT_DIR
VERSION
DEFAULT_OUTPUT
```

---

## Shell 语法

始终使用

```bash
$( )
```

不使用

```bash
``
```

始终使用

```bash
[[ ]]
```

不使用

```bash
[ ]
```

始终给变量加引号

```bash
"${var}"
```

每个函数内使用

```bash
local
```

---

## 注释规范

注释使用中文但禁止包含中文标点符号
如 ， 。 ： 、 ； （ ） 《 》 【 】 等

注释为单行。只有当一行确实写不下时才使用第二行

注释结尾不加任何标点符号

```bash
# 正确格式
# 这是第一行说明 第二行补充
```

错误示例:

```bash
# 错误, 有逗号
# 错误: 有冒号
# 错误（有括号）
```

---

## 模块自包含

每个模块是自包含的脚本:

- 不 source lib/ 或其他任何文件
- 内联自己的工具函数 (trim, normalize, json_escape)
- 可直接调用: `bash modules/os.sh`
- 输出干净的扁平 JSON 到 stdout
- 所有日志和错误输出到 stderr

---

## Root 权限

所有模块和调度器需要 root 权限。模块非 root 运行时以 code 5 退出

```bash
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    printf '{"error":"root required (use sudo)"}\n' >&2
    exit 5
fi
```

调度器 (dg-agent.sh) 非 root 时自动 exec sudo 重新执行
(--help 和 -h 除外, 这两个不需要 root)
