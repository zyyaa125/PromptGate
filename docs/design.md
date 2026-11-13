# PromptGate 设计文档

## 架构概览

```
Policy (JSON)
    │ load_policy()
    ▼
CapabilitySet (allow/deny 规则 + glob 匹配)
    │
    ▼
Gate (Verdict: Allow | Deny | AskUser)
    │
    ▼
Session {
    gate_call(tool, action, resource):
      1. Budget.consume() → 配额检查
      2. Gate.judge()     → 规则判定
      3. Audit.record()   → 审计记录
}
```

## OS 概念到 PromptGate 的映射

| OS 概念 | OS 中的体现 | PromptGate 映射 | 实现位置 |
|---|---|---|---|
| Capability | `open()` 返回文件描述符 → 持有才能 `read()` | 策略中声明 `(tool, action, resource)` → 匹配才能执行 | `capability.mbt` |
| seccomp | `prctl(PR_SET_SECCOMP, ...)` 声明允许的系统调用 | 加载策略后，所有调用必须通过 Gate | `gate.mbt` |
| cgroup | `cpu.max` 限制 CPU 配额 | `max_calls` + `max_tokens` 配额 | `budget.mbt` |
| /proc/pid/status | `cat /proc/1234/status` 查看进程状态 | `session.audit_entries()` 查看判定历史 | `audit.mbt` |
| 进程地址空间 | clone() 复制页表 → 子进程独立内存 | Session::new() → 独立的 Gate + Budget + Audit | `session.mbt` |
| Default-deny | iptables 默认 DROP 策略 | CapabilitySet 无匹配 → Deny | `capability_set.mbt` |
| TOCTOU | open() + fstat() 代替 stat() + open() | 文档声明宿主负责 final execution guard | `docs/threat-model.md` |

## 与 MoonPermit 的详细对比

### 安全模型差异

| 维度 | MoonPermit | PromptGate |
|---|---|---|
| **安全范式** | 计划驱动的动态授权 | 策略驱动的静态门禁 |
| **类比** | "出差申请表"（动态审批预算） | "公司门禁刷工卡"（静态策略检查） |
| **核心不变式** | `child_permit <= parent_permit`（权限衰减证明） | `(tool, action, resource) in CapabilitySet`（规则匹配判定） |
| **参数检查** | 效果类型比较（`read_file` 是 read 效果） | 参数模式匹配（`.env` 不匹配 `*.mbt`） |
| **生命周期** | Permit 可委托、可衰减 | Session-scoped，过期自动废弃 |

### 协作场景

两者可以组合：MoonPermit 编译出最小 permit（允许 Agent 只读 `workspace/src/*.mbt`），PromptGate 在此基础上叠加静态 deny（禁止读 `.env`）。Agent 调用 `read_file(".env")` 时，PromptGate 的 deny 优先于 MoonPermit 的 allow。

## 判定流程详解

```
Session::gate_call(tool, action, resource)
    │
    ├─ 1. Budget.consume(1, 1)
    │      └─ 超出配额 → return (Deny, "budget exhausted")
    │
    ├─ 2. Gate.judge(tool, action, resource)
    │      ├─ ask_rules 中有匹配？ → AskUser
    │      ├─ CapabilitySet.match_()
    │      │   ├─ deny 规则匹配？ → Deny
    │      │   ├─ allow 规则匹配？ → Allow
    │      │   └─ 无匹配 → Deny (default-deny)
    │
    └─ 3. AuditTrail.record(tool, action, resource, verdict, reason)
           └─ 环形缓冲，满时驱逐最旧条目
```

## 匹配算法

`glob_match(pattern, value)` 使用递归 DFS：

- `*` 匹配零或多个非 `/` 字符（单段通配）
- `**` 匹配零或多个任意字符（跨段通配）
- 字面字符精确匹配
- 空模式 + 空值 → 匹配成功

时间复杂度：O(p * v) 其中 p 是模式长度，v 是值长度。

## 设计取舍

| 决策 | 选择 | 理由 |
|---|---|---|
| 策略格式 | JSON | 任何语言都能生成，CI 友好 |
| 默认策略 | Default-deny | 安全第一原则 |
| 匹配粒度 | (tool, action, resource) | 实用且可在赛期内完成 |
| 拦截点 | 参数构造后、执行前 | 能检查完整三元组 |
| 审计存储 | 内存环形缓冲 | 库不自行做持久化决策 |

## 已知限制

1. 不支持参数值级别的匹配（如：只允许读取小于 1KB 的文件）
2. 时间戳使用固定值 0（测试确定性），生产环境需替换为系统时间
3. 不支持网络协议导出审计日志（仅提供 JSON 导出接口）
4. 单实例内存中运行，不支持分布式 session 共享
5. 不支持运行时动态修改策略（策略加载后不变）