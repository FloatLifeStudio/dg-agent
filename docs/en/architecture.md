DG-Agent Architecture Specification

### 1. Goal

DG-Agent is a lightweight asset collection framework.

Its responsibilities are:

- Collect hardware information

- Collect operating system information

- Normalize collected data

- Export data using a unified interface

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

Avoid unnecessary abstraction.

---

#### Single Responsibility

Every layer has only one responsibility.

| Layer      | Responsibility   |
| ---------- | ---------------- |
| Module     | Collect data     |
| Dispatcher | Schedule modules |
| Formatter  | Convert data     |
| Output     | Write data       |
| Library    | Shared utilities |

---

#### High Cohesion

Each module focuses on one hardware or software component only.

Example

```text
cpu.sh
```

collects CPU information only.

---

#### Low Coupling

Modules must never depend on each other.

Only the dispatcher is allowed to invoke modules.

---

#### One-way Dependency

The dependency direction is fixed.

```text
dg-agent.sh
  ↓
Dispatcher
  ↓
Module
  ↓
Formatter
  ↓
Output
```

Reverse dependencies are prohibited.

---

### 3. Runtime Workflow

```text
CLI
  ↓
Argument Parser
  ↓
Dispatcher
  ↓
Module
  ↓
Formatter
  ↓
Output
```

---

### 4. Module Lifecycle

```text
Load
  ↓
Collect
  ↓
Normalize
  ↓
Return key=value
  ↓
Formatter
  ↓
Output
```