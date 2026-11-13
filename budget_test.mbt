/// Tests for Budget.

test "unlimited budget always allows" {
  let b = @promptgate.Budget::new(max_calls=None, max_tokens=None, window_seconds=None)
  let (b2, ok) = b.consume(100L, 10000L)
  assert_eq(ok, true)
  assert_eq(b2.remaining_calls(), None)
}

test "calls limit blocks when exceeded" {
  let b = @promptgate.Budget::new(max_calls=Some(5L), max_tokens=None, window_seconds=None)
  let (b2, ok1) = b.consume(4L, 0L)
  assert_eq(ok1, true)
  let (_b3, ok2) = b2.consume(2L, 0L)
  assert_eq(ok2, false)
}

test "tokens limit blocks when exceeded" {
  let b = @promptgate.Budget::new(max_calls=None, max_tokens=Some(100L), window_seconds=None)
  let (_b2, ok) = b.consume(0L, 101L)
  assert_eq(ok, false)
}

test "remaining calls reflects consumption" {
  let b = @promptgate.Budget::new(max_calls=Some(10L), max_tokens=None, window_seconds=None)
  let (b2, _) = b.consume(3L, 0L)
  assert_eq(b2.remaining_calls(), Some(7L))
}

test "reset clears consumption" {
  let b = @promptgate.Budget::new(max_calls=Some(5L), max_tokens=None, window_seconds=None)
  let (b2, _) = b.consume(5L, 0L)
  assert_eq(b2.remaining_calls(), Some(0L))
  let b3 = b2.reset()
  assert_eq(b3.remaining_calls(), Some(5L))
}