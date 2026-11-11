# PromptGate 开发计划

> 项目目标：一个借鉴操作系统 capability-based security 和 seccomp 思想的 LLM Agent 工具调用安全网关库
>
> 开发原则：人主导决策，AI 辅助执行。每个 Commit 前需要完成思考题、做出设计决策、先写测试。
>
> 总提交目标：≥10 个有实际内容的功能提交（不含合并提交）

---

## 整体架构速览

```
用户（Agent 开发者）
  │
  ▼
┌──────────────────────────────────────────────┐
│  Policy (JSON)                                │
│  声明式策略：哪些 tool/action/resource 被允许   │
└──────────────┬───────────────────────────────┘
               │ 加载
               ▼
┌──────────────────────────────────────────────┐
│  CapabilitySet                                │
│  能力集合：存储 + 匹配算法                      │
│  - 通配符匹配 (read_file, "*.mbt")            │
│  - 前缀匹配 (network, "api.example.com/*")    │
│  - 显式 deny 优先于 allow                      │
└──────────────┬───────────────────────────────┘
               │ 查询
               ▼
┌──────────────────────────────────────────────┐
│  Gate                                         │
│  核心判定引擎                                  │
│  - 输入：(tool, action, resource)             │
│  - 输出：Allow / Deny / AskUser               │
│  - 默认拒绝（default-deny）                    │
└──────┬──────────────┬────────────────────────┘
       │              │
       ▼              ▼
┌──────────┐  ┌──────────────┐
│ Budget   │  │ AuditTrail   │
│ 配额追踪  │  │ 审计日志      │
│ - token  │  │ - 每次判定    │
│ - 次数   │  │ - 时间戳      │
│ - 时间窗  │  │ - 决策原因    │
└────┬─────┘  └──────┬───────┘
     │               │
     ▼               ▼
┌──────────────────────────────┐
│  Session                      │
│  会话绑定                     │
│  - 能力只在当前会话有效        │
│  - 会话过期自动回收            │
│  - 类比：进程地址空间          │
└──────────────────────────────┘
```

---

## 十二次提交的详细计划

---

### Commit 1：项目骨架初始化

**目标**：搭建最小可编译的 MoonBit 项目

**你需要先学习的内容**：
- MoonBit 项目结构（`moon.mod`、`moon.pkg`、包和模块的关系）
- MoonBit 的公开 API 约定（`pub fn`、`pub type`、`pub let`）

**你需要做出的设计决策**：
- 项目名用 `lllg123/promptgate`（确认你的 GitHub ID 是 `lllg123`？）
- 许可证选 Apache-2.0（和 MoonPod 保持一致）

**AI 协助范围**：
- 已帮你创建了 `moon.mod`、`moon.pkg`、`.gitignore`、`.moonignore`
- 你需要自己完成：`README.md`（写 5 句话的项目简介）、`LICENSE` 文件

**提交内容**：
```
PromptGate/           ← 已创建
├── moon.mod          ← 已创建
├── moon.pkg          ← 已创建
├── .gitignore        ← 已创建
├── .moonignore       ← 已创建
├── README.md         ← 你写
├── LICENSE           ← 你创建（复制 Apache-2.0 模板）
└── docs/
    └── DEVELOPMENT_PLAN.md  ← 本文件
```

**验证标准**：`moon check` 通过（即使没有源文件也应该通过，因为 `moon.pkg` 已经引用了 core/debug 和 core/json）

**提交信息**：`init: project skeleton with moon.mod, README, Apache-2.0`

---

### Commit 2：架构决策记录 + 威胁模型

**目标**：在写任何代码之前，先记录"为什么这样做"

**你需要先学习的内容**：
- OS 中的 capability-based security 思想（10 分钟即可：读懂"能力是令牌，不是名字"）
- OS 中的 seccomp 思想（5 分钟：进程主动声明"我只能用这些系统调用"）
- 威胁模型的基本概念（10 分钟：攻击者是谁？能做什么？我们防什么？不防什么？）

**你需要做出的设计决策**（写在 `docs/decisions/001-architecture.md`）：

回答以下 5 个问题：
1. PromptGate 的拦截点在哪里？（工具调用之前？工具名解析之后？参数构造之前？）
2. 策略用什么格式？（JSON？MoonBit 代码？DSL？）
3. 默认策略是什么？（默认拒绝 vs 默认允许）
4. 匹配粒度是什么？（只到工具名？到动作？到资源路径？到参数值？）
5. 和 MoonPermit 的关系？（互补？竞争？无关？）

**你需要自己写的文件**：
- `docs/decisions/001-architecture.md`（上面 5 个问题的回答 + 理由）
- `docs/threat-model.md`（攻击面分析：至少列出 3 种攻击方式 + 防御措施）

**AI 协助范围**：
- 帮你审阅决策记录的逻辑一致性
- 补充 OS 类比的具体例子

**提交信息**：`docs: architecture decision record and threat model`

---

### Commit 3：Capability 数据模型

**目标**：定义"一个能力"在代码中长什么样

**你需要先学习的内容**：
- MoonBit 的 `struct`、`enum`、`String`、`Eq` 派生
- MoonBit 测试的写法（`test "..." { ... }`）
- 路径通配符的语义：`*`（匹配一层）、`**`（匹配任意层）、完全匹配

**核心类型设计（我们一起讨论后你拍板）**：

```text
Capability {
  tool: String      // 工具名，如 "read_file", "run_shell", "api_call"
  action: String    // 动作，如 "read", "write", "execute"
  resource: String  // 资源模式，如 "workspace/*.mbt", "api.example.com:443"
}
```

设计要点：`resource` 是模式（支持通配符），不是原始值。匹配时用模式匹配。

**你需要自己写的代码**：
- `capability.mbt`：定义 `Capability` 类型、`new` 构造函数、`to_string` 方法
- `capability_test.mbt`：测试创建、相等性比较、字符串表示

**思考题**（在写代码前回答）：
1. `resource` 是 `"*.mbt"` 时，是否匹配 `"src/utils.mbt"`？是否匹配 `"src/sub/utils.mbt"`？
2. 如果 `resource` 是空字符串，表示什么？

**验证标准**：`moon test` 通过，至少 3 个测试用例

**提交信息**：`feat: add Capability data model with constructor and equality`

---

### Commit 4：CapabilitySet 匹配引擎

**目标**：实现"给定一个能力集合，判断一个具体调用是否被允许"

**你需要先学习的内容**：
- 通配符匹配算法（glob 匹配的基本实现）
- 显式 deny vs allow 的优先级规则

**核心算法（你先在白板上画出流程图，再写代码）**：

```
输入：(tool="read_file", action="read", resource="src/main.mbt")
策略集：
  allow: (read_file, read, "src/*.mbt")     ← 匹配！
  deny:  (read_file, read, "src/secret.mbt") ← 不匹配（资源不匹配）
  deny:  (read_file, *, "*.env")             ← 不匹配

判定流程：
1. 遍历所有 deny 规则，如果命中 → Deny
2. 遍历所有 allow 规则，如果命中 → Allow
3. 都不命中 → Deny（默认拒绝）
```

**你需要自己写的代码**：
- `capability_set.mbt`：CapabilitySet 类型，add_allow/add_deny 方法，match 方法返回 bool
- `capability_set_test.mbt`：正例测试（匹配成功）、反例测试（匹配失败）、deny 优先级测试、边界测试（空字符串、重复添加）

**思考题**：
1. 如果同时有 `allow: (*, *, *)` 和 `deny: (read_file, *, "*.env")`，读 `.env` 会 Deny 吗？
2. deny 规则能在 allow 规则之后添加吗？

**验证标准**：`moon test` 通过，至少 8 个测试用例（覆盖：精确匹配、通配、deny 覆盖 allow、无匹配默认拒绝）

**提交信息**：`feat: add CapabilitySet with glob matching and default-deny`

---

### Commit 5：Gate 核心判定引擎

**目标**：实现三步判定——Allow / Deny / AskUser

**你需要先学习的内容**：
- 三层判定的语义区别：
  - `Allow`：明确允许，可以自动执行
  - `Deny`：明确拒绝，绝对不能执行（返回错误给 Agent）
  - `AskUser`：策略中没有明确规定，需要用户确认（弹窗/人工审批）

**判定流程（你先画流程图）**：

```
              ┌─────────────────┐
              │ 收到工具调用请求  │
              └────────┬────────┘
                       ▼
              ┌─────────────────┐
              │ deny 规则命中？   │── Yes ──→ Deny + 审计
              └────────┬────────┘
                       │ No
                       ▼
              ┌─────────────────┐
              │ allow 规则命中？  │── Yes ──→ Allow + 审计
              └────────┬────────┘
                       │ No
                       ▼
              ┌─────────────────┐
              │ 策略中有显式      │── Yes ──→ AskUser + 审计
              │ ask_user 标记？   │
              └────────┬────────┘
                       │ No
                       ▼
                     Deny (default-deny)
```

**你需要自己写的代码**：
- `gate.mbt`：定义 `Verdict` 枚举（Allow, Deny, AskUser），Gate 类型（持有 CapabilitySet），`judge` 方法
- `gate_test.mbt`：Allow 场景、Deny 场景、AskUser 场景、空策略（全部 Deny）

**思考题**：
1. AskUser 的判定结果是同步的还是异步的？（决定了 API 设计）
2. 如果一个调用被 Deny，应该返回什么信息给调用方？（错误码？原因字符串？结构化信息？）

**验证标准**：`moon test` 通过，至少 6 个测试用例

**提交信息**：`feat: add Gate engine with Allow/Deny/AskUser verdict`

---

### Commit 6：策略加载器

**目标**：从 JSON 文件加载策略，验证格式正确性

**你需要先学习的内容**：
- MoonBit 中 JSON 解析的 API（`@json.parse`、`@json.Json` 类型）
- 策略的 JSON Schema 设计

**策略 JSON 格式设计（你设计，AI 审阅）**：

```json
{
  "version": "1.0",
  "rules": [
    { "type": "deny",  "tool": "read_file", "action": "read", "resource": "*.env" },
    { "type": "deny",  "tool": "run_shell", "action": "*",    "resource": "*" },
    { "type": "allow", "tool": "read_file", "action": "read", "resource": "workspace/**" },
    { "type": "allow", "tool": "api_call",  "action": "*",    "resource": "api.example.com:443/*" },
    { "type": "ask",   "tool": "run_shell", "action": "execute", "resource": "moon" }
  ],
  "default": "deny"
}
```

**你需要自己写的代码**：
- `policy.mbt`：Policy 类型、`from_json(json_str: String) -> Policy!Error`、`validate` 方法
- `policy_test.mbt`：合法 JSON、非法 JSON、缺少字段、空规则列表、版本不匹配

**思考题**：
1. 如果 JSON 中某个 rule 的 `tool` 字段缺失，应该怎么处理？（报错 vs 设为通配符）
2. `version` 字段的作用是什么？（为未来的策略格式升级做准备）

**验证标准**：`moon test` 通过，至少 5 个测试用例

**提交信息**：`feat: add JSON policy loader with validation`

---

### Commit 7：审计日志

**目标**：每次判定都留下可追溯的记录

**你需要先学习的内容**：
- 审计日志的最佳实践（不可篡改、时间戳、决策原因）
- `/proc` 文件系统中的审计思想

**审计条目设计**：

```text
AuditEntry {
  timestamp: Int64       // Unix 时间戳（毫秒）
  tool: String           // 请求的工具名
  action: String         // 请求的动作
  resource: String       // 请求的资源
  verdict: String        // "allow" | "deny" | "ask_user"
  reason: String         // 匹配了哪条规则（或"no matching rule"）
}
```

**你需要自己写的代码**：
- `audit.mbt`：AuditEntry 类型、AuditTrail 类型（环形缓冲、最大条目数）、`record`/`export_json`/`query` 方法
- `audit_test.mbt`：记录条目、导出 JSON、缓冲区溢出（旧条目被覆盖）、空日志查询

**思考题**：
1. 审计日志存在哪里？（内存？文件？）——设计为可插拔的 trait
2. 环形缓冲区多大合适？写死 1000 条还是有参数控制？

**验证标准**：`moon test` 通过，至少 4 个测试用例

**提交信息**：`feat: add audit trail with ring buffer and JSON export`

---

### Commit 8：配额追踪

**目标**：类比 cgroup 的资源限制，实现调用次数和 token 预算控制

**你需要先学习的内容**：
- Linux cgroup 的设计思想（CPU quota、memory limit）
- 配额 vs 硬限制的区别

**配额模型设计**：

```text
Budget {
  max_calls: Int64?           // 最大调用次数（None 表示无限制）
  max_tokens: Int64?          // 最大 token 消耗（None 表示无限制）
  window_seconds: Int64?      // 时间窗口（None 表示从会话开始计算）
  consumed_calls: Int64       // 已消耗的调用次数
  consumed_tokens: Int64      // 已消耗的 token 数
  window_start: Int64         // 窗口开始时间戳
}
```

**你需要自己写的代码**：
- `budget.mbt`：Budget 类型、`consume(calls, tokens)` 方法（返回是否超额）、`remaining` 方法、`reset` 方法
- `budget_test.mbt`：正常消耗、超额、窗口重置、无限制、边界值

**思考题**：
1. token 消耗量由谁提供？（调用方传入——因为 PromptGate 不知道每个工具调用消耗多少 token）
2. 时间窗口过期后，consumed 计数自动归零还是需要手动 reset？

**验证标准**：`moon test` 通过，至少 5 个测试用例

**提交信息**：`feat: add budget tracking with call/token quotas and time windows`

---

### Commit 9：会话模型

**目标**：能力绑定到会话——类比进程地址空间

**你需要先学习的内容**：
- 进程地址空间的概念——每个进程有自己的内存空间，进程结束空间回收
- Session 的生命周期：创建 → 激活 → 过期/销毁

**会话模型设计**：

```text
Session {
  id: String                    // 唯一会话 ID
  capabilities: CapabilitySet   // 该会话拥有的能力
  budget: Budget                // 该会话的配额
  audit: AuditTrail             // 该会话的审计日志
  created_at: Int64             // 创建时间
  expires_at: Int64?            // 过期时间（None 表示永不过期）
}
```

**你需要自己写的代码**：
- `session.mbt`：Session 类型、`new` 构造函数、`gate` 方法（综合调用 Gate + Budget + Audit）、`is_expired` 方法、`close` 方法
- `session_test.mbt`：正常调用、过期拒绝、配额耗尽拒绝、审计自动记录

**思考题**：
1. 会话过期后，审计日志是否还能读取？
2. 多个会话能共享同一个 CapabilitySet 吗？（共享内存类比）

**验证标准**：`moon test` 通过，至少 5 个测试用例

**提交信息**：`feat: add session model with scoped capabilities and expiry`

---

### Commit 10：集成示例 —— 模拟 Agent 宿主

**目标**：一个可运行的完整示例，展示 PromptGate 在实际场景中的用法

**场景设计**：模拟一个"AI 代码助手"的工具调用流程

**你需要自己写的代码**：
- `examples/code_assistant/main.mbt`：创建一个 Session，加载策略，注入能力，然后模拟 5 个工具调用请求（2 个允许、2 个拒绝、1 个 AskUser），输出判定结果
- `examples/code_assistant/policy.json`：示例策略文件

**示例流程**：
```
策略：
  deny:  (read_file, read, "*.env")
  deny:  (run_shell, execute, "rm*")
  allow: (read_file, read, "workspace/**")
  allow: (run_shell, execute, "moon")
  ask:   (api_call, post, "api.github.com/*")

模拟调用：
1. read_file("workspace/src/main.mbt")   → Allow   ✓
2. read_file(".env")                     → Deny    ✗（命中 deny 规则）
3. run_shell("moon test")               → Allow   ✓
4. run_shell("rm -rf /")                → Deny    ✗（命中 deny 规则）
5. api_call("api.github.com/gists")      → AskUser ?（需要用户确认）
```

**验证标准**：`moon run examples/code_assistant` 输出 5 条判定结果

**提交信息**：`feat: add code-assistant integration example`

---

### Commit 11：CI 配置 + 全覆盖测试

**目标**：章程要求的 CI 检查、构建、测试全通过

**你需要先学习的内容**：
- GitHub Actions 的基本语法（`.github/workflows/ci.yml`）
- MoonBit 的 CI 最佳实践

**你需要自己写的代码**：
- `.github/workflows/ci.yml`：`moon fmt --check`、`moon check --deny-warn`、`moon test --deny-warn`、`moon build`
- 补充遗漏的测试用例（检查覆盖率）
- 补充边界测试：超大策略集（1000 条规则）、并发 session、空字符串、特殊字符

**AI 协助范围**：
- 帮你检查 CI 文件的语法
- 审阅测试覆盖的盲区

**验证标准**：CI 全部绿色，`moon test` 测试数 ≥ 30

**提交信息**：`ci: add GitHub Actions workflow with fmt/check/test/build`

---

### Commit 12：文档完成 + 发布准备

**目标**：章程要求的 README、API 文档、mooncakes 发布材料

**你需要自己写的文件**：
- `README.md` 完整版（目标、安装、使用方法、3 个完整场景、可复现示例）
- `docs/API.md`（公开 API 的完整说明）
- `docs/design.md`（架构设计文档，和 MoonPermit 的差异对比）
- `docs/learning-log.md`（你整个开发过程中的学习笔记——这是"减少 AI 痕迹"的关键证据）

**AI 协助范围**：
- 审阅文档完整性
- 帮你检查章程检查清单

**验证标准**：
- 从干净克隆能完整复现：`git clone → moon check → moon test → moon run`
- README 中的 3 个使用场景有对应代码可运行

**提交信息**：`docs: complete README, API reference, and learning log`

---

## 时间节奏建议（9 月赛期）

| 时间段 | 提交 | 核心任务 |
|---|---|---|
| 第 1-2 天 | Commit 1-2 | 项目骨架 + 架构决策 |
| 第 3-4 天 | Commit 3 | Capability 数据模型 |
| 第 5-6 天 | Commit 4 | CapabilitySet 匹配引擎 |
| 第 7-8 天 | Commit 5-6 | Gate 引擎 + 策略加载 |
| 第 9-10 天 | Commit 7-8 | 审计 + 配额 |
| 第 11-12 天 | Commit 9 | 会话模型 |
| 第 13-14 天 | Commit 10 | 集成示例 |
| 第 15-16 天 | Commit 11 | CI + 补测试 |
| 第 17-18 天 | Commit 12 | 文档完成 |

> 注意：这是一个弹性节奏，每个 Commit 的完成标准是"你能口头解释它做了什么 + 测试全绿"。

---

## 章程合规检查清单

开发完成后逐项打勾：

- [ ] 个人参赛，一个项目
- [ ] MoonBit 为主要实现语言
- [ ] GitHub 仓库公开，提交记录清晰（≥10 次有效提交）
- [ ] 无空提交、无机械拆分、无复制提交
- [ ] README 说明目标、安装、使用方法、可复现示例
- [ ] CI 覆盖 `fmt --check`、`check --deny-warn`、`test --deny-warn`、`build`
- [ ] 核心路径有完整测试（≥30 个测试用例）
- [ ] 至少 1 个可运行示例（`moon run examples/code_assistant`）
- [ ] 发布到 mooncakes.io
- [ ] OSI 认可的许可证（Apache-2.0）
- [ ] 明确说明和 MoonPermit 的差异及互补关系
- [ ] 申报书回答生态缺口、通用性、3 个场景、核心功能、不做内容、实现路径
- [ ] 保留学习日志（`docs/learning-log.md`）作为人为决策证据