/// Tests for CapabilitySet glob matching.

test "empty set denies everything" {
  let set = @promptgate.CapabilitySet::new()
  let r = set.match_("read_file", "read", "src/main.mbt")
  assert_eq(r, @promptgate.MatchResult::Deny)
}

test "exact match allows" {
  let cap = @promptgate.new("read_file", "read", "src/main.mbt")
  let set = @promptgate.CapabilitySet::new().add_allow(cap)
  assert_eq(set.match_("read_file", "read", "src/main.mbt"), @promptgate.MatchResult::Allow)
}

test "no match defaults to deny" {
  let cap = @promptgate.new("read_file", "read", "src/*.mbt")
  let set = @promptgate.CapabilitySet::new().add_allow(cap)
  assert_eq(set.match_("run_shell", "execute", "moon"), @promptgate.MatchResult::Deny)
}

test "deny overrides allow" {
  let cap_allow = @promptgate.new("read_file", "read", "*")
  let cap_deny = @promptgate.new("read_file", "read", "*.env")
  let set = @promptgate.CapabilitySet::new().add_allow(cap_allow).add_deny(cap_deny)
  assert_eq(set.match_("read_file", "read", ".env"), @promptgate.MatchResult::Deny)
}

test "glob star matches within segment" {
  let cap = @promptgate.new("read_file", "read", "src/*.mbt")
  let set = @promptgate.CapabilitySet::new().add_allow(cap)
  assert_eq(set.match_("read_file", "read", "src/utils.mbt"), @promptgate.MatchResult::Allow)
}

test "glob star blocks cross-segment" {
  let cap = @promptgate.new("read_file", "read", "src/*.mbt")
  let set = @promptgate.CapabilitySet::new().add_allow(cap)
  assert_eq(set.match_("read_file", "read", "src/sub/utils.mbt"), @promptgate.MatchResult::Deny)
}

test "glob double-star matches cross-segment" {
  let cap = @promptgate.new("read_file", "read", "src/**.mbt")
  let set = @promptgate.CapabilitySet::new().add_allow(cap)
  assert_eq(set.match_("read_file", "read", "src/sub/deep/utils.mbt"), @promptgate.MatchResult::Allow)
}

test "wildcard tool matches any tool" {
  let cap = @promptgate.new("*", "read", "data/*")
  let set = @promptgate.CapabilitySet::new().add_allow(cap)
  assert_eq(set.match_("read_file", "read", "data/x"), @promptgate.MatchResult::Allow)
  assert_eq(set.match_("api_call", "read", "data/x"), @promptgate.MatchResult::Allow)
}

test "action mismatch fails even when tool matches" {
  let cap = @promptgate.new("read_file", "read", "*")
  let set = @promptgate.CapabilitySet::new().add_allow(cap)
  assert_eq(set.match_("read_file", "write", "src/main.mbt"), @promptgate.MatchResult::Deny)
}

test "multiple denies all checked" {
  let cap_allow = @promptgate.new("*", "*", "*")
  let cap_d1 = @promptgate.new("read_file", "read", "*.env")
  let cap_d2 = @promptgate.new("run_shell", "execute", "rm*")
  let set = @promptgate.CapabilitySet::new().add_allow(cap_allow).add_deny(cap_d1).add_deny(cap_d2)
  assert_eq(set.match_("run_shell", "execute", "rm -rf"), @promptgate.MatchResult::Deny)
  assert_eq(set.match_("read_file", "read", ".env"), @promptgate.MatchResult::Deny)
}

test "deny added before allow still wins" {
  let cap_deny = @promptgate.new("run_shell", "*", "*")
  let cap_allow = @promptgate.new("run_shell", "execute", "moon")
  let set = @promptgate.CapabilitySet::new().add_deny(cap_deny).add_allow(cap_allow)
  assert_eq(set.match_("run_shell", "execute", "moon"), @promptgate.MatchResult::Deny)
}