/// Tests for AuditTrail.

test "record entry and retrieve" {
  let trail = @promptgate.AuditTrail::new(max_size=10)
  let t = trail.record("read_file", "read", "src/main.mbt", "allow", "matched allow rule").all()
  assert_eq(t.length(), 1)
  assert_eq(t[0].tool, "read_file")
  assert_eq(t[0].verdict, "allow")
}

test "multiple entries preserved in order" {
  let trail = @promptgate.AuditTrail::new(max_size=10)
    .record("read_file", "read", "a", "allow", "r1")
    .record("run_shell", "execute", "b", "deny", "r2")
    .record("api_call", "post", "c", "ask_user", "r3")
  let all = trail.all()
  assert_eq(all.length(), 3)
  assert_eq(all[0].resource, "a")
  assert_eq(all[1].resource, "b")
  assert_eq(all[2].resource, "c")
}

test "ring buffer evicts oldest entry" {
  let trail = @promptgate.AuditTrail::new(max_size=2)
    .record("t1", "a1", "r1", "allow", "reason1")
    .record("t2", "a2", "r2", "deny", "reason2")
    .record("t3", "a3", "r3", "allow", "reason3")
  let all = trail.all()
  assert_eq(all.length(), 2)
  assert_eq(all[0].resource, "r2")
  assert_eq(all[1].resource, "r3")
}

test "count reflects current entries" {
  let trail = @promptgate.AuditTrail::new(max_size=5)
    .record("t1", "a1", "r1", "allow", "r")
    .record("t2", "a2", "r2", "deny", "r")
  assert_eq(trail.count(), 2)
}