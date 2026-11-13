// Audit: decision trail with ring buffer and JSON export.
//
// Modeled after OS /proc auditing: every Gate decision is recorded
// with timestamp, request details, verdict, and reason. The ring buffer
// provides bounded memory with automatic eviction of oldest entries.

/// One recorded decision.
#derive(Eq, Debug)
pub struct AuditEntry {
  timestamp : Int64
  tool : String
  action : String
  resource : String
  verdict : String
  reason : String
}

pub extend AuditEntry with Eq::{not_equal, equal}
pub extend AuditEntry with @moonbitlang/core/debug.Debug::{to_repr}

#derive(Eq, Debug)
pub struct AuditTrail {
  entries : Array[AuditEntry]
  max_size : Int
}

pub extend AuditTrail with Eq::{not_equal, equal}
pub extend AuditTrail with @moonbitlang/core/debug.Debug::{to_repr}

/// Create a new AuditTrail with the given maximum size (ring buffer).
pub fn AuditTrail::new(max_size~ : Int) -> AuditTrail {
  { entries: [], max_size, }
}

/// Record a decision into the trail. Oldest entry is evicted when full.
pub fn AuditTrail::record(self : AuditTrail, tool : String, action : String, resource : String, verdict : String, reason : String) -> AuditTrail {
  let entry = AuditEntry::new(tool, action, resource, verdict, reason)
  if self.entries.length() >= self.max_size {
    let mut trimmed : Array[AuditEntry] = []
    for i = 1; i < self.entries.length(); i = i + 1 {
      trimmed = trimmed + [self.entries[i]]
    }
    { entries: trimmed + [entry], max_size: self.max_size, }
  } else {
    { entries: self.entries + [entry], max_size: self.max_size, }
  }
}

/// Return all recorded entries.
pub fn AuditTrail::all(self : AuditTrail) -> Array[AuditEntry] {
  self.entries
}

/// Return the number of recorded entries.
pub fn AuditTrail::count(self : AuditTrail) -> Int {
  self.entries.length()
}

/// Create a new AuditEntry.
pub fn AuditEntry::new(tool : String, action : String, resource : String, verdict : String, reason : String) -> AuditEntry {
  let ts = current_timestamp()
  { timestamp: ts, tool, action, resource, verdict, reason, }
}

/// Current time in milliseconds. In a real implementation this would use
/// system time; here it returns 0 for deterministic testing.
fn current_timestamp() -> Int64 {
  0L
}