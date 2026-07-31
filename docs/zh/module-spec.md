# 模块规格

## 职责

模块负责:

- 检测并要求 root 权限
- 采集硬件或操作系统信息
- 标准化采集数据
- 输出扁平 JSON 对象到 stdout

模块不负责:

- 日志记录 (错误仅输出到 stderr)
- 命令行参数解析
- 输出文件写入
- 用模块名 key 包裹自身输出
- 引用库文件

---

## 生命周期

```text
Root 检测 -> 采集 -> 标准化 -> 输出 JSON
```

---

## 公共接口

每个模块是一个独立的可执行脚本

```bash
# 直接调用
bash modules/os.sh
bash modules/cpu.sh
```

模块必须向 stdout 输出恰好一个 JSON 对象并以 0 退出表示成功,
或以非零退出并在 stderr 输出错误 JSON 表示失败。

---

## 输出格式

模块输出扁平 JSON。无包裹 key。不使用 key=value。

```json
{"name":"Ubuntu","id":"ubuntu","version":"22.04"}
```

禁止的格式:

```text
带包裹的 JSON:  {"os": {"name": "Ubuntu"}}
key=value:      os_name=Ubuntu
YAML / XML / CSV
```

---

## Root 要求

所有模块必须在启动时检查 root 权限, 非 root 时以 code 5 退出

```bash
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    printf '{"error":"root required (use sudo)"}\n' >&2
    exit 5
fi
```

---

## 自包含

模块不得 source 外部文件。

每个工具函数 (trim, normalize, json_escape) 必须在模块内部内联定义。

---

## 依赖

模块可以使用:

```text
Linux 工具 (lscpu, dmidecode, nvidia-smi, ethtool, lspci, lsblk)
内核接口 (/proc/meminfo, /sys/class/net)
jq (复杂模块中用于 JSON 处理)
```

模块不得依赖:

```text
其他模块
lib/ 文件
Formatter / Logger
```

---

## 错误处理

模块出错时以非零退出。调度器 (dg-agent.sh) 捕获每个模块的失败
并继续运行剩余模块。

```bash
command -v lscpu >/dev/null 2>&1 || {
    printf '{"error":"lscpu not found"}\n' >&2
    exit 1
}
```
