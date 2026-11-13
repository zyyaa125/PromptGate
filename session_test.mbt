///|
/// Tests for Session.
test "session gates call through all layers" {
  let cap = @promptgate.new("read_file", "read", "workspace/*.mbt")
  let set = @promptgate.CapabilitySet::new().add_allow(cap)
  let gate = @promptgate.Gate::new(set, [])
  let budget = @promptgate.Budget::new(
    max_calls=Some(10L),
    max_tokens=None,
    window_seconds=None,
  )
  let s = @promptgate.Session::new(id="s1", gate~, budget~, expires_at=None)
  let (_s2, v) = s.gate_call("read_file", "read", "workspace/main.mbt")
  assert_eq(v, @promptgate.Verdict::Allow)
}

///|
test "session denies when budget exhausted" {
  let cap = @promptgate.new("*", "*", "*")
  let set = @promptgate.CapabilitySet::new().add_allow(cap)
  let gate = @promptgate.Gate::new(set, [])
  let budget = @promptgate.Budget::new(
    max_calls=Some(2L),
    max_tokens=None,
    window_seconds=None,
  )
  let s = @promptgate.Session::new(id="s1", gate~, budget~, expires_at=None)
  let (s2, v1) = s.gate_call("t1", "a1", "r1")
  assert_eq(v1, @promptgate.Verdict::Allow)
  let (s3, v2) = s2.gate_call("t2", "a2", "r2")
  assert_eq(v2, @promptgate.Verdict::Allow)
  let (_s4, v3) = s3.gate_call("t3", "a3", "r3")
  assert_eq(v3, @promptgate.Verdict::Deny)
}

///|
test "session records audit entries" {
  let cap = @promptgate.new("*", "*", "*")
  let set = @promptgate.CapabilitySet::new().add_allow(cap)
  let gate = @promptgate.Gate::new(set, [])
  let budget = @promptgate.Budget::new(
    max_calls=None,
    max_tokens=None,
    window_seconds=None,
  )
  let s = @promptgate.Session::new(id="s1", gate~, budget~, expires_at=None)
  let (s2, _) = s.gate_call("read_file", "read", "src/x.mbt")
  let entries = s2.audit_entries()
  assert_eq(entries.length(), 1)
  assert_eq(entries[0].tool, "read_file")
  assert_eq(entries[0].verdict, "allow")
}

///|
test "session default-deny for unmatched rules" {
  let set = @promptgate.CapabilitySet::new()
  let gate = @promptgate.Gate::new(set, [])
  let budget = @promptgate.Budget::new(
    max_calls=None,
    max_tokens=None,
    window_seconds=None,
  )
  let s = @promptgate.Session::new(id="s1", gate~, budget~, expires_at=None)
  let (_s2, v) = s.gate_call("run_shell", "execute", "rm -rf")
  assert_eq(v, @promptgate.Verdict::Deny)
}

///|
test "session close clears budget" {
  let cap = @promptgate.new("*", "*", "*")
  let set = @promptgate.CapabilitySet::new().add_allow(cap)
  let gate = @promptgate.Gate::new(set, [])
  let budget = @promptgate.Budget::new(
    max_calls=Some(5L),
    max_tokens=None,
    window_seconds=None,
  )
  let s = @promptgate.Session::new(id="s1", gate~, budget~, expires_at=None)
  let (s2, _) = s.gate_call("t1", "a1", "r1")
  // Verify we consumed 1 call.
  let rem = match s2.remaining_budget() {
    None => -1L
    Some(n) => n
  }
  assert_eq(rem, 4L)
}

///|
test "session ask-user records in audit" {
  let set = @promptgate.CapabilitySet::new()
  let ask = [@promptgate.new("api_call", "post", "*")]
  let gate = @promptgate.Gate::new(set, ask)
  let budget = @promptgate.Budget::new(
    max_calls=None,
    max_tokens=None,
    window_seconds=None,
  )
  let s = @promptgate.Session::new(id="s1", gate~, budget~, expires_at=None)
  let (s2, v) = s.gate_call("api_call", "post", "api.example.com/endpoint")
  assert_eq(v, @promptgate.Verdict::AskUser)
  let entries = s2.audit_entries()
  assert_eq(entries[0].verdict, "ask_user")
}

///|
test "session is not expired by default" {
  let set = @promptgate.CapabilitySet::new()
  let gate = @promptgate.Gate::new(set, [])
  let budget = @promptgate.Budget::new(
    max_calls=None,
    max_tokens=None,
    window_seconds=None,
  )
  let s = @promptgate.Session::new(id="s1", gate~, budget~, expires_at=None)
  assert_eq(s.is_expired(), false)
}
