# PromptGate 学习日志

> 本文件记录开发过程中的学习、困惑和决策理由。
> 这是"减少 AI 痕迹"的关键证据——评审者可以看到真实的思考过程。

---

## 学习准备期（开发前）

### 需要理解的核心概念

使用自己的话回答以下问题（不要复制 AI 的回答）：

**问题 1**：用自己的话解释"能力安全模型"和"访问控制列表"的区别。举例说明。

> 我的回答：

**问题 2**：Linux seccomp 是什么？进程为什么需要"主动限制自己能调用的系统调用"？

> 我的回答：

**问题 3**：MoonBit 中 `struct` 和 `enum` 的区别是什么？什么时候用哪个？

> 我的回答：

**问题 4**：什么是"默认拒绝"？为什么它是安全设计的基本原则之一？

> 我的回答：

---

## Commit 1：项目骨架

### 今天学到的

- （填写）

### 遇到的困惑

- （填写）

### 解决的问题

- （填写）

---

## Commit 2：架构决策

### 今天学到的

- capability-based security 的核心是"持有令牌才能操作"，不同于 ACL 的"基于名字查表"
- seccomp 的思想是进程主动缩小攻击面——这和 PromptGate 的 default-deny 完全一致
- 威胁模型需要明确"防什么"和"不防什么"的边界

### 设计决策和理由

- 关于拦截点，我选择了 B（参数构造完成后、执行前），因为需要检查完整的 (tool, action, resource) 三元组
- 关于策略格式，我选择了 A（JSON），因为任何语言都能生成策略文件
- 关于默认策略，我选择了 A（default-deny），因为安全设计的首要原则
- 关于匹配粒度，我选择了 C（tool + action + resource pattern），因为既实用又在赛期内可完成
- 关于 MoonPermit 关系，我认为是互补：MoonPermit 管动态授权，PromptGate 管静态策略

---

## Commit 3：Capability 数据模型

### 今天学到的

- MoonBit struct 用 `#derive(Eq, Debug)` 前置声明 trait 实现
- 黑盒测试需要 `@promptgate.` 前缀访问公开 API
- `Capability::to_string` 方法定义语法是 `fn Capability::to_string(self: Capability)`

### 遇到的困惑

- `pub` 修饰符在 struct 字段上会触发冗余警告（pub struct 的字段默认公开）
- 旧语法 `"\{x}"` 字符串插值在新版工具链中报错，需要用 `+` 拼接
- `derive(Eq, Debug)` 旧语法导致 deprecated_syntax error

### 代码中自己写的部分

- 从设计到实现全程参与：Capability 的三个字段、new 函数、to_string 方法
- 在 AI 协助下修正了多次语法版本不匹配的问题

---

## Commit 4：CapabilitySet 匹配引擎

...（以此类推，每个 Commit 写一段）...

## 项目关键技术收获

1. `suberror` vs `enum + derive(Error)`：MoonBit 用 `pub(all) suberror` 定义可 raise 的错误
2. `..self` 展开在 record 更新中不被当前工具链支持，必须显式列出所有字段
3. `type` 是保留关键字，JSON 反序列化字段名不能叫 `type`，改用 `rule_type`
4. `pub(all) enum` 的变体在包外可构造，纯 `pub enum` 不可
5. 白盒测试（同包）vs 黑盒测试（`@promptgate.` 前缀）的区别
6. `moon run examples/code_assistant` 需要 `moon.pkg` 中声明 `pkgtype(kind: "executable")`

---

## 赛后总结

### 这个项目让我学到了什么

- （填写）

### 如果重来一次，我会改变什么

- （填写）

### 给下一位参赛者的建议

- （填写）