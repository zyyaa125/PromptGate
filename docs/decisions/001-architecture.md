# 架构决策记录 001：PromptGate 的核心设计选择

> 状态：已确认
>
> 日期：2026-09-07

## 类比来源

PromptGate 的设计借鉴了操作系统的两个核心安全机制：

### 1. Capability-based Security（能力安全模型）

在传统 OS 中，访问控制有两种模式：
- **ACL（访问控制列表）**：基于名字检查权限。"用户 `alice` 可以读文件 `/etc/passwd` 吗？"→ 查 ACL
- **Capability（能力）**：持有令牌才能操作。进程必须持有文件描述符才能 read()，而这个描述符是通过 open() 获得的——open() 本身就是一道门禁。

PromptGate 采用 capability 模型：Agent 只能调用它"持有能力"的工具。

### 2. seccomp（安全计算模式）

Linux seccomp 允许进程在运行时声明："从此之后，我只允许以下系统调用：read, write, exit。"其他所有系统调用都会被内核拒绝（SIGKILL）。这是"主动缩小攻击面"的思想。

PromptGate 借鉴 seccomp：在 Agent 初始化时加载策略，之后所有工具调用都必须通过 Gate 判定。

---

## 五个待回答的决策问题

### 决策 1：拦截点在哪里？

PromptGate 的 Gate 在工具调用链中的哪个位置？

选项：
- A）在 Agent 生成工具调用意图后、参数构造前 → 可以拦截不完整的调用
- B）在参数构造完成后、实际执行前 → 可以检查完整的 (tool, action, resource) 三元组
- C）在工具执行器中，每次工具被调用时 → 侵入性最大但最安全

**你的选择：B，理由：已确认**

### 决策 2：策略用什么格式表达？

选项：
- A）JSON 文件 → 人类可读，任何语言都能生成，适合 CI/Makefile
- B）MoonBit 代码（实际类型） → 编译期检查，无解析错误，但只能用 MoonBit 写策略
- C）自创 DSL → 表达能力最强，但有学习成本

**你的选择：A，理由：已确认**

### 决策 3：默认策略是什么？

当没有任何规则匹配时，Gate 应该返回什么？

选项：
- A）默认拒绝（default-deny）→ 更安全，"不声明就不能做"
- B）默认允许（default-allow）→ 更宽松，但安全保证弱

**你的选择：A，理由：已确认**

### 决策 4：匹配粒度是什么？

`(tool, action, resource)` 的匹配可以到多细的粒度？

选项：
- A）只匹配 tool 名 → 最粗，"允许 read_file 工具的所有调用"
- B）匹配 (tool, action) → 中等，"允许 read_file 的 read 动作"
- C）匹配 (tool, action, resource pattern) → 最细，"允许 read_file 读 workspace/*.mbt"
- D）匹配到参数值 → 最细，"允许 read_file 读取路径 /a/b，但内容必须是 JSON"

**你的选择：C，理由：已确认**

### 决策 5：和 MoonPermit 的关系是什么？

MoonPermit 已经做了"计划编译为最小权限 Permit + 运行时检查"。
PromptGate 和它的关系是？

选项：
- A）互补：MoonPermit 管"这次任务需要什么权限"，PromptGate 管"这个环境允许什么操作"
- B）替代：PromptGate 可以覆盖 MoonPermit 的场景
- C）无关：两个项目的目标和受众完全不同

**你的选择：A，理由：已确认**

---

## 回答后更新

当参赛者回答完以上 5 个问题后，本文件的"待定"状态将更新为"已确认"，并将这些决策作为不可变的基础约束写入代码。