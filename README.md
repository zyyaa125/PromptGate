# PromptGate

借鉴操作系统 **capability-based security** 和 **seccomp** 思想的 LLM Agent 工具调用安全网关库。MoonBit 实现，可嵌入任何 Agent 框架。

## 核心思想

```
OS 概念                 →  PromptGate 映射
capability（能力令牌）    →  只有持有能力的 Agent 才能调用对应工具
seccomp（系统调用过滤）   →  策略声明"允许哪些工具调用"，其余默认拒绝
cgroup（资源配额）       →  token 消耗预算 + 调用次数限制
/proc（可观测性）        →  每次判定的审计日志，可追溯可导出
进程地址空间             →  Session 绑定能力，会话结束能力回收
```

## 与其他项目的差异

| 项目 | 定位 | 关系 |
|---|---|---|
| [MoonPermit](https://github.com/doffice/moonpermit) | 计划编译最小权限 + 运行时检查 | 互补：MoonPermit 管"这次任务需要什么权限"，PromptGate 管"这个环境允许什么操作" |
| [MoonPod](https://github.com/yadidyc/moonpod) | 通用策略执行与审计引擎 | 互补：MoonPod 覆盖文件/命令/网络通用策略，PromptGate 专注于 Agent 工具调用的能力边界 |

PromptGate 不复制以上项目的能力，而是填补"Agent 工具调用前的静态安全门禁"这个细分空白。

## 三个完整使用场景

### 场景 1：AI 代码助手安全门禁

```text
IDE 中的 AI 助理被授予限制能力：
  allow: (read_file, read, "workspace/**")
  allow: (run_shell, execute, "moon*")
  deny:  (read_file, read, "*.env")
  deny:  (run_shell, execute, "rm*")

当 LLM 试图读取 .env 时 → Deny（审计记录：匹配 deny 规则）
当 LLM 运行 moon test 时 → Allow
当 LLM 运行 rm -rf 时 → Deny（审计记录：匹配 deny 规则）
```

### 场景 2：多租户 Agent API 网关

```text
租户 A：capabilities 绑定 db/tenant_a/*
租户 B：capabilities 绑定 db/tenant_b/*

每个租户的 Agent session 拥有独立的 Gate + Budget + AuditTrail。
租户 A 调用 db/tenant_b/data → Deny（资源不匹配任何 allow 规则，default-deny）
```

### 场景 3：CI/CD Agent 发布流水线

```text
allow: (api_call, get, "ci.example.com/status/*")
allow: (api_call, post, "ci.example.com/deploy/*")
ask:   (api_call, post, "ci.example.com/deploy/production/*")
deny:  (api_call, delete, "ci.example.com/*")

部署到 staging → Allow（自动）
部署到 production → AskUser（需要人工确认）
删除服务 → Deny（审计记录中永久保留）
```

## 安装与使用

```bash
# 克隆仓库
git clone https://github.com/zyyaa125/PromptGate.git
cd PromptGate

# 检查
moon check --deny-warn

# 测试（48 个测试用例）
moon test --deny-warn

# 运行示例
moon run examples/code_assistant
```

### 最简单的 API 调用

```moonbit
// 创建策略
let json = "{\"version\":\"1\",\"rules\":[{\"rule_type\":\"allow\",\"tool\":\"read_file\",\"action\":\"read\",\"resource\":\"workspace/**\"}]}"
let gate = try! @promptgate.load_policy(json)

// 创建 session
let budget = @promptgate.Budget::new(max_calls=Some(100L), max_tokens=None, window_seconds=None)
let session = @promptgate.Session::new(id="agent-1", gate=gate, budget=budget, expires_at=None)

// 工具调用判定
let (session, verdict) = session.gate_call("read_file", "read", "workspace/main.mbt")
// verdict == Verdict::Allow

// 查看审计日志
let entries = session.audit_entries()
// entries[0].verdict == "allow"
```

## 可复现验收

在仓库根目录运行：

```bash
moon fmt --check        # 格式检查
moon check --deny-warn  # 类型检查（0 错误）
moon test --deny-warn   # 48 个测试全部通过
moon run examples/code_assistant  # 输出 5 条判定结果 + 审计日志
```

示例预期输出：

```
PromptGate Code Assistant Demo
================================

call: read_file(workspace/src/main.mbt) -> Allow
call: read_file(.env) -> Deny
call: run_shell(moon test) -> Allow
call: run_shell(rm -rf /) -> Deny
call: api_call(api.github.com/gists) -> AskUser

Audit Trail:
------------
  #0: read_file workspace/src/main.mbt => allow (matched allow rule)
  #1: read_file .env => deny (default-deny or matched deny rule)
  #2: run_shell moon test => allow (matched allow rule)
  #3: run_shell rm -rf / => deny (default-deny or matched deny rule)
  #4: api_call api.github.com/gists => ask_user (matched ask-user rule)

remaining budget: 95 calls
```

## 架构

```
Policy (JSON) → CapabilitySet → Gate → Session {
    gate_call(tool, action, resource):
      1. Budget.consume()  → 超出配额则 Deny
      2. Gate.judge()      → Allow / Deny / AskUser
      3. AuditTrail.record() → 记录决策
  }

模块依赖关系：
  capability.mbt    ← 数据模型
  capability_set.mbt ← glob 匹配 + deny-first 判定
  gate.mbt          ← Allow/Deny/AskUser 三层判定
  policy.mbt        ← JSON 策略加载 + 验证
  budget.mbt        ← 调用次数/token 配额
  audit.mbt         ← 环形缓冲审计日志
  session.mbt       ← 整合以上全部模块
```

## 技术边界

- **交付**：可嵌入的 MoonBit 库，7 个公开模块，48 个测试，1 个可运行示例
- **策略格式**：JSON（任何语言都能生成）
- **匹配粒度**：(tool, action, resource pattern)，支持 `*` 和 `**` 通配符
- **默认策略**：default-deny（安全第一原则）
- **不交付**：真实沙箱隔离、OS 级 enforcement、分布式 session 管理、UI 界面

## 文档

- [开发计划](docs/DEVELOPMENT_PLAN.md) — 12 次提交的完整迭代
- [架构决策记录](docs/decisions/001-architecture.md) — 5 个核心设计决策
- [威胁模型](docs/threat-model.md) — 4 种攻击场景 + 防御
- [API 参考](docs/API.md) — 7 个模块的公开接口
- [设计文档](docs/design.md) — 架构详解与 MoonPermit 对比
- [学习日志](docs/learning-log.md) — 人类决策过程记录

## 许可证

Apache License 2.0