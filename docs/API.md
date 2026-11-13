# PromptGate API 参考

## 模块概览

| 模块 | 公开类型 | 说明 |
|---|---|---|
| `capability.mbt` | `Capability`, `new()` | (tool, action, resource) 三元组 |
| `capability_set.mbt` | `CapabilitySet`, `MatchResult` | 规则集合 + glob 匹配 |
| `gate.mbt` | `Gate`, `Verdict` | 三层判定引擎 |
| `policy.mbt` | `load_policy()`, `PolicyError` | JSON 策略加载 |
| `budget.mbt` | `Budget` | 调用次数/token 配额 |
| `audit.mbt` | `AuditTrail`, `AuditEntry` | 审计日志 |
| `session.mbt` | `Session` | 会话（整合以上全部） |

---

## capability.mbt

### `Capability`

```moonbit
pub struct Capability {
  tool : String
  action : String
  resource : String
}
```

### `new(tool, action, resource) -> Capability`

```moonbit
let cap = @promptgate.new("read_file", "read", "workspace/*.mbt")
```

---

## capability_set.mbt

### `MatchResult`

```moonbit
pub enum MatchResult { Allow, Deny }
```

### `CapabilitySet`

```moonbit
pub struct CapabilitySet
pub fn CapabilitySet::new() -> CapabilitySet
pub fn CapabilitySet::add_allow(self, cap: Capability) -> CapabilitySet
pub fn CapabilitySet::add_deny(self, cap: Capability) -> CapabilitySet
pub fn CapabilitySet::match_(self, tool, action, resource) -> MatchResult
```

### `cap_matches(rule, tool, action, resource) -> Bool`

判断单个 Capability 规则是否匹配给定请求。公开导出，可供 Gate 复用。

### `glob_match(pattern, value) -> Bool`

Glob 匹配：`*` 单段通配，`**` 跨段通配。

---

## gate.mbt

### `Verdict`

```moonbit
pub enum Verdict { Allow, Deny, AskUser }
```

### `Gate`

```moonbit
pub struct Gate
pub fn Gate::new(capabilities: CapabilitySet, ask_rules: Array[Capability]) -> Gate
pub fn Gate::judge(self, tool, action, resource) -> Verdict
```

判定顺序：ask rules → CapabilitySet（deny 优先 → allow → default-deny）

---

## policy.mbt

### `load_policy(json_str: String) -> Gate raise PolicyError`

从 JSON 字符串加载策略并构建 Gate。

**JSON Schema**：

```json
{
  "version": "1",
  "rules": [
    { "rule_type": "allow", "tool": "...", "action": "...", "resource": "..." },
    { "rule_type": "deny",  "tool": "...", "action": "...", "resource": "..." },
    { "rule_type": "ask",   "tool": "...", "action": "...", "resource": "..." }
  ]
}
```

### `PolicyError`

```moonbit
pub suberror PolicyError {
  InvalidJson(String)
  MissingField(String)
  UnknownVersion(String)
  EmptyRules
}
```

---

## budget.mbt

### `Budget`

```moonbit
pub struct Budget
pub fn Budget::new(max_calls~: Int64?, max_tokens~: Int64?, window_seconds~: Int64?) -> Budget
pub fn Budget::consume(self, calls: Int64, tokens: Int64) -> (Budget, Bool)
pub fn Budget::remaining_calls(self) -> Int64?
pub fn Budget::remaining_tokens(self) -> Int64?
pub fn Budget::reset(self) -> Budget
```

---

## audit.mbt

### `AuditEntry`

```moonbit
pub struct AuditEntry {
  timestamp : Int64
  tool : String
  action : String
  resource : String
  verdict : String
  reason : String
}
```

### `AuditTrail`

```moonbit
pub struct AuditTrail
pub fn AuditTrail::new(max_size~: Int) -> AuditTrail
pub fn AuditTrail::record(self, tool, action, resource, verdict, reason) -> AuditTrail
pub fn AuditTrail::all(self) -> Array[AuditEntry]
pub fn AuditTrail::count(self) -> Int
```

环形缓冲设计：超出 `max_size` 时自动驱逐最旧条目。

---

## session.mbt

### `Session`

```moonbit
pub struct Session
pub fn Session::new(id~: String, gate~: Gate, budget~: Budget, expires_at~: Int64?) -> Session
pub fn Session::gate_call(self, tool, action, resource) -> (Session, Verdict)
pub fn Session::is_expired(self) -> Bool
pub fn Session::audit_entries(self) -> Array[AuditEntry]
pub fn Session::remaining_budget(self) -> Int64?
pub fn Session::close(self) -> Session
```

`gate_call` 执行完整的三层判定流程：配额检查 → 规则匹配 → 审计记录。