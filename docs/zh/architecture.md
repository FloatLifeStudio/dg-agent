# DG-Agent 架构规格

## 1. 目标

DG-Agent 是一个轻量级硬件资产采集框架

职责:

- 采集硬件信息
- 采集操作系统信息
- 标准化采集数据
- 通过统一的 JSON 接口导出数据
- 保持模块化和可扩展

DG-Agent 不负责:

- CMDB 同步
- 数据库存储
- 服务管理
- 远程执行

---

## 2. 设计原则

### KISS

保持每个组件尽可能简单。不为假设的未来需求做抽象。

### 单一职责

每一层只有一个职责

| 层       | 职责                 |
| -------- | -------------------- |
| 模块     | 采集数据并输出 JSON  |
| 调度器   | 调度模块并聚合结果   |
| 库       | 共享字符串工具和日志 |
| 输出     | 写入聚合结果         |

### 高内聚

每个模块只关注一个硬件或软件组件

```text
cpu.sh  -> 仅 CPU
os.sh   -> 仅 OS
disk.sh -> 仅磁盘
```

### 低耦合

模块之间不能相互依赖。模块不能引用库文件。只有调度器允许调用模块。

### 单向依赖

依赖方向固定

```text
dg-agent.sh
  -> lib/cleaner.sh, lib/logger.sh
  -> modules/*.sh  (作为子进程调用, 不用 source)
```

禁止反向依赖。

---

## 3. 运行时流程

```text
CLI
  -> Root 权限检测 (非 root 自动 exec sudo)
  -> 参数解析
  -> 模块运行 (每个模块作为 bash 子进程调用)
  -> JSON 聚合 (将结果按模块名包裹为顶层 key)
  -> 输出 (stdout 或文件)
```

---

## 4. 模块生命周期

```text
Root 检测 (非 root 退出 5)
  -> 采集 (lscpu, dmidecode, nvidia-smi, /sys, /proc ...)
  -> 标准化 (去空格, 过滤占位符)
  -> 输出扁平 JSON 到 stdout
```

---

## 5. 输出格式

### 方式 A: 聚合模式 (dg-agent.sh)

```json
{
  "os": { "name": "Ubuntu", "id": "ubuntu", ... },
  "cpu": { "vendor": "Intel", "model": "...", "cores": 8, ... }
}
```

每个模块的 JSON 以其模块名作为顶层 key 包裹。

### 方式 B: 独立模式 (modules/os.sh)

```json
{ "name": "Ubuntu", "id": "ubuntu", "version": "22.04", ... }
```

扁平 JSON 对象, 无包裹 key。

---

## 6. 文件结构

```text
dg-agent/
  dg-agent.sh           调度和聚合入口
  modules/
    os.sh               操作系统
    cpu.sh              CPU
    memory.sh           内存
    disk.sh             磁盘
    gpu.sh              GPU
    nic.sh              网卡
    power.sh            电源
  lib/
    cleaner.sh          trim / normalize / json_escape (纯 Bash)
    logger.sh           日志 (支持 verbose 控制)
    formatter.sh        key=value 转 JSON (遗留)
    tools/
      dmi.sh            完整 dmidecode 导出为 JSON
      lshw.sh           完整 lshw 导出为 JSON
  docs/
    en/                 英文文档
    zh/                 中文文档
