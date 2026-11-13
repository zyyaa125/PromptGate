// Budget: call-count and token-usage quotas for agent sessions.
//
// Modeled after Linux cgroup resource limits:
// - max_calls: CPU runtime quota (how many tool invocations allowed)
// - max_tokens: memory limit (how many tokens consumed)
// - window_seconds: time window for rate limiting (cgroup period)

#derive(Eq, Debug)
pub struct Budget {
  max_calls : Int64?
  max_tokens : Int64?
  window_seconds : Int64?
  consumed_calls : Int64
  consumed_tokens : Int64
  window_start : Int64
}

pub extend Budget with Eq::{not_equal, equal}
pub extend Budget with @moonbitlang/core/debug.Debug::{to_repr}

/// Create a Budget with optional limits.
/// Pass None for any limit to disable it.
pub fn Budget::new(
  max_calls~ : Int64?,
  max_tokens~ : Int64?,
  window_seconds~ : Int64?,
) -> Budget {
  {
    max_calls,
    max_tokens,
    window_seconds,
    consumed_calls: 0L,
    consumed_tokens: 0L,
    window_start: 0L,
  }
}

/// Attempt to consume the given amount. Returns the updated Budget and whether allowed.
pub fn Budget::consume(self : Budget, calls : Int64, tokens : Int64) -> (Budget, Bool) {
  let fresh = self.consume_at(calls, tokens)
  let over_calls = match fresh.max_calls {
    None => false
    Some(limit) => fresh.consumed_calls > limit
  }
  let over_tokens = match fresh.max_tokens {
    None => false
    Some(limit) => fresh.consumed_tokens > limit
  }
  (fresh, !(over_calls || over_tokens))
}

/// Check how many calls remain (None means unlimited).
pub fn Budget::remaining_calls(self : Budget) -> Int64? {
  match self.max_calls {
    None => None
    Some(m) => Some(m - self.consumed_calls)
  }
}

/// Check how many tokens remain (None means unlimited).
pub fn Budget::remaining_tokens(self : Budget) -> Int64? {
  match self.max_tokens {
    None => None
    Some(m) => Some(m - self.consumed_tokens)
  }
}

/// Reset consumed counters to zero. Keeps the same limits.
pub fn Budget::reset(self : Budget) -> Budget {
  {
    max_calls: self.max_calls,
    max_tokens: self.max_tokens,
    window_seconds: self.window_seconds,
    consumed_calls: 0L,
    consumed_tokens: 0L,
    window_start: 0L,
  }
}

/// Internal: apply consumption without checking limits.
fn Budget::consume_at(self : Budget, calls : Int64, tokens : Int64) -> Budget {
  {
    max_calls: self.max_calls,
    max_tokens: self.max_tokens,
    window_seconds: self.window_seconds,
    consumed_calls: self.consumed_calls + calls,
    consumed_tokens: self.consumed_tokens + tokens,
    window_start: self.window_start,
  }
}