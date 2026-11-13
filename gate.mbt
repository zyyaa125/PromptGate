/// Verdict for a single tool-call request.
#derive(Eq, Debug)
pub(all) enum Verdict {
  Allow
  Deny
  AskUser
}

pub extend Verdict with Eq::{not_equal, equal}
pub extend Verdict with @moonbitlang/core/debug.Debug::{to_repr}

#derive(Eq, Debug)
pub struct Gate {
  capabilities : CapabilitySet
  ask_rules : Array[Capability]
}

pub extend Gate with Eq::{not_equal, equal}
pub extend Gate with @moonbitlang/core/debug.Debug::{to_repr}

/// Create a new Gate from a CapabilitySet and optional ask-user rules.
pub fn Gate::new(capabilities : CapabilitySet, ask_rules : Array[Capability]) -> Gate {
  { capabilities, ask_rules, }
}

/// Judge a tool call and return Allow, Deny, or AskUser.
///
/// Evaluation order:
/// 1. Ask-user rules match → AskUser
/// 2. CapabilitySet gives Allow → Allow
/// 3. CapabilitySet gives Deny or nothing matched → Deny (default-deny)
pub fn Gate::judge(self : Gate, tool : String, action : String, resource : String) -> Verdict {
  for i = 0; i < self.ask_rules.length(); i = i + 1 {
    if cap_matches(self.ask_rules[i], tool, action, resource) {
      return Verdict::AskUser
    }
  }
  match self.capabilities.match_(tool, action, resource) {
    MatchResult::Allow => Verdict::Allow
    MatchResult::Deny => Verdict::Deny
  }
}