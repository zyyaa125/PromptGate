///|
/// Tests for policy loader.
test "valid policy loads successfully" {
  let json = "{\"version\":\"1\",\"rules\":[{\"rule_type\":\"allow\",\"tool\":\"read_file\",\"action\":\"read\",\"resource\":\"workspace/**\"}]}"
  let gate = try! @promptgate.load_policy(json)
  assert_eq(
    gate.judge("read_file", "read", "workspace/main.mbt"),
    @promptgate.Verdict::Allow,
  )
  assert_eq(gate.judge("run_shell", "execute", "rm"), @promptgate.Verdict::Deny)
}

///|
test "policy with deny rule blocks access" {
  let json = "{\"version\":\"1\",\"rules\":[{\"rule_type\":\"allow\",\"tool\":\"read_file\",\"action\":\"read\",\"resource\":\"*\"},{\"rule_type\":\"deny\",\"tool\":\"read_file\",\"action\":\"read\",\"resource\":\"*.env\"}]}"
  let gate = try! @promptgate.load_policy(json)
  assert_eq(
    gate.judge("read_file", "read", "README.md"),
    @promptgate.Verdict::Allow,
  )
  assert_eq(gate.judge("read_file", "read", ".env"), @promptgate.Verdict::Deny)
}

///|
test "policy with ask rule triggers AskUser" {
  let json = "{\"version\":\"1\",\"rules\":[{\"rule_type\":\"allow\",\"tool\":\"read_file\",\"action\":\"read\",\"resource\":\"src/*.mbt\"},{\"rule_type\":\"ask\",\"tool\":\"api_call\",\"action\":\"post\",\"resource\":\"api.github.com/*\"}]}"
  let gate = try! @promptgate.load_policy(json)
  assert_eq(
    gate.judge("api_call", "post", "api.github.com/gists"),
    @promptgate.Verdict::AskUser,
  )
}

///|
test "missing version returns error" {
  let json = "{\"rules\":[{\"rule_type\":\"allow\",\"tool\":\"read_file\",\"action\":\"read\",\"resource\":\"*\"}]}"
  let caught = try {
    let _ = @promptgate.load_policy(json)
    "no_error"
  } catch {
    e =>
      match e {
        @promptgate.PolicyError::MissingField(f) => f
        _ => "wrong_error"
      }
  }
  assert_eq(caught, "version")
}

///|
test "unknown version returns error" {
  let json = "{\"version\":\"99\",\"rules\":[{\"rule_type\":\"allow\",\"tool\":\"read_file\",\"action\":\"read\",\"resource\":\"*\"}]}"
  let caught = try {
    let _ = @promptgate.load_policy(json)
    "no_error"
  } catch {
    e =>
      match e {
        @promptgate.PolicyError::UnknownVersion(v) => v
        _ => "wrong_error"
      }
  }
  assert_eq(caught, "99")
}

///|
test "malformed json returns error" {
  let json = "not json at all"
  let caught = try {
    let _ = @promptgate.load_policy(json)
    "no_error"
  } catch {
    e =>
      match e {
        @promptgate.PolicyError::InvalidJson(_) => "invalid"
        _ => "wrong_error"
      }
  }
  assert_eq(caught, "invalid")
}

///|
test "unknown rule type returns error" {
  let json = "{\"version\":\"1\",\"rules\":[{\"rule_type\":\"bogus\",\"tool\":\"x\",\"action\":\"y\",\"resource\":\"z\"}]}"
  let caught = try {
    let _ = @promptgate.load_policy(json)
    "no_error"
  } catch {
    e =>
      match e {
        @promptgate.PolicyError::InvalidJson(_) => "invalid"
        _ => "wrong_error"
      }
  }
  assert_eq(caught, "invalid")
}

///|
test "empty rules returns error" {
  let json = "{\"version\":\"1\",\"rules\":[]}"
  let caught = try {
    let _ = @promptgate.load_policy(json)
    "no_error"
  } catch {
    e =>
      match e {
        @promptgate.PolicyError::EmptyRules => "empty"
        _ => "wrong_error"
      }
  }
  assert_eq(caught, "empty")
}
