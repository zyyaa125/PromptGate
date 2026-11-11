# PromptGate

一个借鉴操作系统 **capability-based security** 和 **seccomp** 思想的 LLM Agent 工具调用安全网关库。

采用 MoonBit 实现，可嵌入到任何 Agent 框架中，在工具执行前进行能力边界判定。

## 核心思想

```
OS 概念                →  PromptGate 映射
─────────────────────────────────────────
capability（能力令牌）   →  只有持有能力的 Agent 才能调用对应工具
seccomp（系统调用过滤）  →  策略声明"允许哪些工具调用"，其余默认拒绝
cgroup（资源配额）      →  token 消耗预算 + 调用次数限制
/proc（可观测性）       →  每次判定的审计日志，可追溯可导出
进程地址空间            →  Session 绑定能力，会话结束能力回收
```

## 当前状态

**开发阶段：Commit 1 之前**

详细开发计划见 [docs/DEVELOPMENT_PLAN.md](docs/DEVELOPMENT_PLAN.md)

## 安装与使用

```bash
# 克隆仓库
git clone https://github.com/zyyaa125/PromptGate.git
cd PromptGate

# 检查
moon check --deny-warn

# 测试
moon test --deny-warn

# 运行示例
moon run examples/code_assistant
```

## 文档

- [开发计划](docs/DEVELOPMENT_PLAN.md)
- [架构决策记录](docs/decisions/001-architecture.md)
- [威胁模型](docs/threat-model.md)
- [学习日志](docs/learning-log.md)

## 许可证

Apache License 2.0