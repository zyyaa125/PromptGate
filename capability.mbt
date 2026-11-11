// Capability data model for PromptGate.
//
// A Capability is a triple of (tool, action, resource) that describes
// what a specific agent operation is allowed to do. It mirrors the OS
// concept of a capability token: holding the token grants the right to
// perform the operation.

/// A single capability describing one permitted operation.
#derive(Eq)
pub struct Capability {
  tool : String
  action : String
  resource : String
}

/// Create a new Capability with the given tool, action, and resource pattern.
pub fn new(tool : String, action : String, resource : String) -> Capability {
  { tool, action, resource }
}

pub extend Capability with Eq::{not_equal, equal}

/// Return a human-readable representation of this capability.
pub fn Capability::to_string(self : Capability) -> String {
  let tool = self.tool
  let action = self.action
  let resource = self.resource
  "Capability{tool=" + tool + ", action=" + action + ", resource=" + resource + "}"
}