///|
/// Outcome of matching against a CapabilitySet.
#derive(Eq, Debug)
pub(all) enum MatchResult {
  Allow
  Deny
}

///|
pub extend MatchResult with Eq::{not_equal, equal}

///|
pub extend MatchResult with @moonbitlang/core/debug.Debug::{to_repr}

///|
#derive(Eq, Debug)
pub struct CapabilitySet {
  allows : Array[Capability]
  denys : Array[Capability]
}

///|
pub extend CapabilitySet with Eq::{not_equal, equal}

///|
pub extend CapabilitySet with @moonbitlang/core/debug.Debug::{to_repr}

///|
/// Create an empty CapabilitySet.
pub fn CapabilitySet::new() -> CapabilitySet {
  { allows: [], denys: [], }
}

///|
/// Add an allow rule.
pub fn CapabilitySet::add_allow(
  self : CapabilitySet,
  cap : Capability,
) -> CapabilitySet {
  { allows: self.allows + [cap], denys: self.denys, }
}

///|
/// Add a deny rule.
pub fn CapabilitySet::add_deny(
  self : CapabilitySet,
  cap : Capability,
) -> CapabilitySet {
  { allows: self.allows, denys: self.denys + [cap], }
}

///|
/// Match a concrete (tool, action, resource) against this set.
/// Deny rules are checked first and take absolute priority.
pub fn CapabilitySet::match_(
  self : CapabilitySet,
  tool : String,
  action : String,
  resource : String,
) -> MatchResult {
  for i = 0; i < self.denys.length(); i = i + 1 {
    if cap_matches(self.denys[i], tool, action, resource) {
      return MatchResult::Deny
    }
  }
  for i = 0; i < self.allows.length(); i = i + 1 {
    if cap_matches(self.allows[i], tool, action, resource) {
      return MatchResult::Allow
    }
  }
  MatchResult::Deny
}

///|
/// Check if a single Capability rule matches the given request.
pub fn cap_matches(
  rule : Capability,
  tool : String,
  action : String,
  resource : String,
) -> Bool {
  glob_match(rule.tool, tool) &&
  glob_match(rule.action, action) &&
  glob_match(rule.resource, resource)
}

///|
/// Glob-style pattern matching.
/// `*` matches any non-`/` character sequence within one segment.
/// `**` matches any sequence including `/`.
pub fn glob_match(pattern : String, value : String) -> Bool {
  if pattern == "*" || pattern == "**" {
    return true
  }
  if pattern == value {
    return true
  }
  if !pattern.contains("*") {
    return false
  }
  glob_dfs(pattern, 0, value, 0)
}

///|
fn glob_dfs(p : String, pi : Int32, v : String, vi : Int32) -> Bool {
  let pl = p.length()
  let vl = v.length()
  if pi >= pl && vi >= vl {
    return true
  }
  if pi >= pl {
    return false
  }
  let pc = p[pi]
  if pi + 1 < pl && pc == '*' && p[pi + 1] == '*' {
    if glob_dfs(p, pi + 2, v, vi) {
      return true
    }
    if vi < vl && glob_dfs(p, pi, v, vi + 1) {
      return true
    }
    return false
  }
  if pc == '*' {
    if glob_dfs(p, pi + 1, v, vi) {
      return true
    }
    if vi < vl && v[vi] != '/' && glob_dfs(p, pi, v, vi + 1) {
      return true
    }
    return false
  }
  if vi < vl && pc == v[vi] {
    return glob_dfs(p, pi + 1, v, vi + 1)
  }
  false
}
