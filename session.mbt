// Session: scoped capability binding for an agent session.
//
// Modeled after OS process address spaces:
// - Each session owns its own Gate, Budget, and AuditTrail.
// - When the session expires, all capabilities are automatically revoked.
// - Multiple sessions cannot interfere with each other.

#derive(Eq, Debug)
pub struct Session {
  id : String
  gate : Gate
  budget : Budget
  audit : AuditTrail
  created_at : Int64
  expires_at : Int64?
}

pub extend Session with Eq::{not_equal, equal}
pub extend Session with @moonbitlang/core/debug.Debug::{to_repr}

/// Create a new Session with the given Gate, Budget, and optional expiry.
/// expires_at is a Unix timestamp in milliseconds; None means no expiry.
pub fn Session::new(
  id~ : String,
  gate~ : Gate,
  budget~ : Budget,
  expires_at~ : Int64?,
) -> Session {
  {
    id,
    gate,
    budget,
    audit: AuditTrail::new(max_size=100),
    created_at: 0L,
    expires_at,
  }
}

/// Gate a single tool call through all layers:
/// 1. Check budget — deny if exhausted.
/// 2. Check Gate rules — deny/allow/ask.
/// 3. Record decision in audit trail.
///
/// Returns (new_session, verdict).
pub fn Session::gate_call(self : Session, tool : String, action : String, resource : String) -> (Session, Verdict) {
  // Step 1: budget check.
  let (budget2, budget_ok) = self.budget.consume(1L, 1L)
  if !budget_ok {
    let audit2 = self.audit.record(tool, action, resource, "deny", "budget exhausted")
    let s = {
      id: self.id,
      gate: self.gate,
      budget: budget2,
      audit: audit2,
      created_at: self.created_at,
      expires_at: self.expires_at,
    }
    return (s, Verdict::Deny)
  }

  // Step 2: Gate rule check.
  let verdict = self.gate.judge(tool, action, resource)

  // Step 3: audit the decision.
  let reason = match verdict {
    Verdict::Allow => "matched allow rule"
    Verdict::Deny => "default-deny or matched deny rule"
    Verdict::AskUser => "matched ask-user rule"
  }
  let verdict_str = match verdict {
    Verdict::Allow => "allow"
    Verdict::Deny => "deny"
    Verdict::AskUser => "ask_user"
  }
  let audit2 = self.audit.record(tool, action, resource, verdict_str, reason)
  let s = {
    id: self.id,
    gate: self.gate,
    budget: budget2,
    audit: audit2,
    created_at: self.created_at,
    expires_at: self.expires_at,
  }
  (s, verdict)
}

/// Check whether the session has expired.
pub fn Session::is_expired(self : Session) -> Bool {
  match self.expires_at {
    None => false
    Some(exp) => 0L > exp
  }
}

/// Return the session's audit trail (read-only snapshot).
pub fn Session::audit_entries(self : Session) -> Array[AuditEntry] {
  self.audit.all()
}

/// Return the session's remaining call budget.
pub fn Session::remaining_budget(self : Session) -> Int64? {
  self.budget.remaining_calls()
}

/// Close the session (clear audit, zero budget). The session struct
/// is consumed; callers should drop the returned value or use it
/// for final audit export before discarding.
pub fn Session::close(self : Session) -> Session {
  let empty_audit = AuditTrail::new(max_size=0)
  let zero_budget = Budget::new(max_calls=Some(0L), max_tokens=Some(0L), window_seconds=None)
  {
    id: self.id,
    gate: self.gate,
    budget: zero_budget,
    audit: empty_audit,
    created_at: self.created_at,
    expires_at: self.expires_at,
  }
}