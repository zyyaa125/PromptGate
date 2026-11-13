/// PromptGate integration example: simulated AI code assistant.

fn verdict_label(v : @promptgate.Verdict) -> String {
  match v {
    @promptgate.Verdict::Allow => "Allow"
    @promptgate.Verdict::Deny => "Deny"
    @promptgate.Verdict::AskUser => "AskUser"
  }
}

fn main {
  let json = "{\"version\":\"1\",\"rules\":[{\"rule_type\":\"deny\",\"tool\":\"read_file\",\"action\":\"read\",\"resource\":\"*.env\"},{\"rule_type\":\"deny\",\"tool\":\"run_shell\",\"action\":\"execute\",\"resource\":\"rm*\"},{\"rule_type\":\"allow\",\"tool\":\"read_file\",\"action\":\"read\",\"resource\":\"workspace/**\"},{\"rule_type\":\"allow\",\"tool\":\"run_shell\",\"action\":\"execute\",\"resource\":\"moon*\"},{\"rule_type\":\"ask\",\"tool\":\"api_call\",\"action\":\"post\",\"resource\":\"api.github.com/*\"}]}"
  let gate = try! @promptgate.load_policy(json)
  let budget = @promptgate.Budget::new(max_calls=Some(100L), max_tokens=None, window_seconds=None)
  let mut session = @promptgate.Session::new(id="code-assistant", gate=gate, budget=budget, expires_at=None)

  let calls = [
    ("read_file", "read", "workspace/src/main.mbt"),
    ("read_file", "read", ".env"),
    ("run_shell", "execute", "moon test"),
    ("run_shell", "execute", "rm -rf /"),
    ("api_call", "post", "api.github.com/gists"),
  ]

  println("PromptGate Code Assistant Demo")
  println("================================")
  println("")

  for i = 0; i < calls.length(); i = i + 1 {
    let (tool, action, resource) = calls[i]
    let (next, verdict) = session.gate_call(tool, action, resource)
    session = next
    println("call: " + tool + "(" + resource + ") -> " + verdict_label(verdict))
  }

  println("")
  println("Audit Trail:")
  println("------------")
  let entries = session.audit_entries()
  for i = 0; i < entries.length(); i = i + 1 {
    let e = entries[i]
    println("  #" + i.to_string() + ": " + e.tool + " " + e.resource + " => " + e.verdict + " (" + e.reason + ")")
  }
  println("")
  let rem = match session.remaining_budget() {
    None => "unlimited"
    Some(n) => n.to_string()
  }
  println("remaining budget: " + rem + " calls")
}