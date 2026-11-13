// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

name = "zyyaa125/promptgate"

version = "0.1.0"

readme = "README.md"

repository = "https://github.com/zyyaa125/PromptGate"

license = "Apache-2.0"

keywords = [ "agent", "security", "capability", "gate", "policy", "tool-call" ]

preferred_target = "wasm"

description = "A capability-based security gate for AI agent tool-call interception, with session-scoped policies and default-deny enforcement"
