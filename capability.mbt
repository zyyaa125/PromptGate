// Capability data model for PromptGate.
//
// A Capability is a triple of (tool, action, resource) that describes
// what a specific agent operation is allowed to do. It mirrors the OS
// concept of a capability token: holding the token grants the right to
// perform the operation.
//
// - tool: the name of the tool (e.g. "read_file", "run_shell")
// - action: the operation within that tool (e.g. "read", "write", "execute")
// - resource: a pattern string that may contain wildcards (*, **)

/// A single capability describing one permitted operation.
pub struct Capability {
  pub tool : String
  pub action : String
  pub resource : String
} derive(Eq, Debug)

/// Create a new Capability with the given tool, action, and resource pattern.
pub fn new(tool : String, action : String, resource : String) -> Capability {
  { tool, action, resource }
}

/// Return a human-readable representation of this capability.
pub fn to_string(self : Capability) -> String {
  "Capability{"
  + "tool=" + self.tool + ", "
  + "action=" + self.action + ", "
  + "resource=" + self.resource
  + "}"
}