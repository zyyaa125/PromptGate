/// Tests for Gate verdict engine.

test "empty gate denies everything" {
  let gate = @promptgate.Gate::new(@promptgate.CapabilitySet::new(), [])
  assert_eq(gate.judge("read_file", "read", "x"), @promptgate.Verdict::Deny)
}

test "allow rule passes" {
  let cap = @promptgate.new("read_file", "read", "workspace/*.mbt")
  let set = @promptgate.CapabilitySet::new().add_allow(cap)
  let gate = @promptgate.Gate::new(set, [])
  assert_eq(gate.judge("read_file", "read", "workspace/main.mbt"), @promptgate.Verdict::Allow)
}

test "deny rule blocks" {
  let cap_allow = @promptgate.new("read_file", "read", "*")
  let cap_deny = @promptgate.new("read_file", "read", "*.env")
  let set = @promptgate.CapabilitySet::new().add_allow(cap_allow).add_deny(cap_deny)
  let gate = @promptgate.Gate::new(set, [])
  assert_eq(gate.judge("read_file", "read", ".env"), @promptgate.Verdict::Deny)
}

test "ask-user rule triggers" {
  let cap_allow = @promptgate.new("read_file", "read", "workspace/*.mbt")
  let set = @promptgate.CapabilitySet::new().add_allow(cap_allow)
  let ask = [@promptgate.new("api_call", "post", "api.github.com/*")]
  let gate = @promptgate.Gate::new(set, ask)
  assert_eq(gate.judge("api_call", "post", "api.github.com/gists"), @promptgate.Verdict::AskUser)
}

test "ask-user matches before allow" {
  let cap = @promptgate.new("*", "*", "*")
  let set = @promptgate.CapabilitySet::new().add_allow(cap)
  let ask = [@promptgate.new("read_file", "read", "*.env")]
  let gate = @promptgate.Gate::new(set, ask)
  assert_eq(gate.judge("read_file", "read", ".env"), @promptgate.Verdict::AskUser)
}

test "default-deny for unmatched call" {
  let cap = @promptgate.new("read_file", "read", "src/*.mbt")
  let set = @promptgate.CapabilitySet::new().add_allow(cap)
  let gate = @promptgate.Gate::new(set, [])
  assert_eq(gate.judge("run_shell", "execute", "rm -rf"), @promptgate.Verdict::Deny)
}