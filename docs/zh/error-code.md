# 错误码

## 调度器错误码 (dg-agent.sh)

| 码 | 名称             | 说明                         |
| -: | ---------------- | ---------------------------- |
|  0 | SUCCESS          | 操作成功完成                 |
|  1 | UNKNOWN_ERROR    | 未知错误                     |
|  2 | INVALID_ARGUMENT | 无效的命令行参数             |
|  3 | MODULE_NOT_FOUND | 请求的模块不存在             |
|  4 | DEPENDENCY_MISSING | 缺少必要的依赖             |
|  5 | PERMISSION_DENIED | 需要 root 权限 (模块或调度器) |
|  6 | COLLECT_FAILED   | 模块采集失败                 |
|  7 | FORMAT_FAILED    | 输出格式化失败               |
|  8 | OUTPUT_FAILED    | 写入输出失败                 |
|  9 | INTERNAL_ERROR   | 内部程序错误                 |

---

## 模块错误码

| 码 | 含义                     |
| -: | ------------------------ |
|  1 | 采集工具未找到           |
|  5 | 未以 root 身份运行       |

模块出错时以非零退出。调度器捕获模块失败并以错误对象形式
报告在聚合输出中, 不会中止整个采集任务。
