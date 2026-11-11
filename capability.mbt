/// A single capability describing one permitted operation.
#derive(Eq, Debug)
pub struct Capability {
  tool : String
  action : String
  resource : String
}

// Keep derived trait methods explicit for the current MoonBit toolchain.
pub extend Capability with Eq::{not_equal, equal}

pub extend Capability with @moonbitlang/core/debug.Debug::{to_repr}

/// Create a new Capability with the given tool, action, and resource pattern.
pub fn new(tool : String, action : String, resource : String) -> Capability {
  { tool, action, resource }
}

/// Return a human-readable representation of this capability.
pub fn Capability::to_string(self : Capability) -> String {
  let tool = self.tool
  let action = self.action
  let resource = self.resource
  "Capability{tool=" + tool + ", action=" + action + ", resource=" + resource + "}"
}