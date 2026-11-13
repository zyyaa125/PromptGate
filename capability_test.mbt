///|
/// Tests for the Capability data model.
test "create capability and check fields" {
  let c = @promptgate.new("read_file", "read", "workspace/*.mbt")
  assert_eq(c.tool, "read_file")
  assert_eq(c.action, "read")
  assert_eq(c.resource, "workspace/*.mbt")
}

///|
test "capability equality" {
  let a = @promptgate.new("read_file", "read", "workspace/*.mbt")
  let b = @promptgate.new("read_file", "read", "workspace/*.mbt")
  let c = @promptgate.new("read_file", "write", "workspace/*.mbt")
  assert_eq(a, b)
  assert_eq(a == c, false)
}

///|
test "new with empty strings is valid" {
  let c = @promptgate.new("", "", "")
  assert_eq(c.tool, "")
  assert_eq(c.resource, "")
}

///|
test "to_string includes tool and action" {
  let c = @promptgate.new("run_shell", "execute", "moon")
  let s = c.to_string()
  assert_eq(s.contains("run_shell"), true)
  assert_eq(s.contains("execute"), true)
  assert_eq(s.contains("moon"), true)
}
