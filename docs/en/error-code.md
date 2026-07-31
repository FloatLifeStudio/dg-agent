| Code | Name               | Description                      |
| ----:| ------------------ | -------------------------------- |
|    0 | SUCCESS            | Operation completed successfully |
|    1 | UNKNOWN_ERROR      | Unknown error                    |
|    2 | INVALID_ARGUMENT   | Invalid command-line argument    |
|    3 | MODULE_NOT_FOUND   | Requested module not found       |
|    4 | DEPENDENCY_MISSING | Required dependency is missing   |
|    5 | PERMISSION_DENIED  | Root required (module or agent)  |
|    6 | COLLECT_FAILED     | Module collection failed         |
|    7 | FORMAT_FAILED      | Output formatting failed         |
|    8 | OUTPUT_FAILED      | Failed to write output           |
|    9 | INTERNAL_ERROR     | Internal program error           |

---

### Module Error Codes

| Code | Meaning                          |
| ----:| -------------------------------- |
|    1 | Collection tool not found        |
|    5 | Not running as root              |

Modules exit non-zero on error. The aggregator (dg-agent.sh) catches
module failures and reports them as error objects in the aggregated
output without aborting the entire run.
