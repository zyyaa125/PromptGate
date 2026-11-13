// Policy: JSON-based policy loader for PromptGate.
//
// A policy is a JSON document that describes which tool calls are allowed,
// denied, or require user confirmation. This module parses the JSON,
// validates it, and builds a ready-to-use Gate.

///|
/// One rule entry from the JSON policy file.
#derive(FromJson)
priv struct PolicyRule {
  rule_type : String
  tool : String
  action : String
  resource : String
}

///|
/// Top-level policy structure matching the JSON schema.
#derive(FromJson)
priv struct PolicyFile {
  version : String?
  rules : Array[PolicyRule]
}

///|
/// Error type for policy loading failures.
pub(all) suberror PolicyError {
  InvalidJson(String)
  MissingField(String)
  UnknownVersion(String)
  EmptyRules
}

///|
/// Load a Gate from a JSON policy string.
pub fn load_policy(json_str : String) -> Gate raise PolicyError {
  let file : PolicyFile = try {
    let parsed = @json.parse(json_str)
    @json.from_json(parsed)
  } catch {
    _ => raise PolicyError::InvalidJson("invalid JSON structure or fields")
  }

  match file.version {
    None => raise PolicyError::MissingField("version")
    Some(v) =>
      if v != "1" && v != "1.0" {
        raise PolicyError::UnknownVersion(v)
      }
  }

  if file.rules.length() == 0 {
    raise PolicyError::EmptyRules
  }

  let mut capabilities = CapabilitySet::new()
  let mut ask_rules : Array[Capability] = []

  for i = 0; i < file.rules.length(); i = i + 1 {
    let r = file.rules[i]
    let ri = i.to_string()
    if r.rule_type == "" {
      raise PolicyError::MissingField("rules[" + ri + "].rule_type")
    }
    if r.tool == "" {
      raise PolicyError::MissingField("rules[" + ri + "].tool")
    }
    let cap = new(r.tool, r.action, r.resource)
    match r.rule_type {
      "allow" => capabilities = capabilities.add_allow(cap)
      "deny" => capabilities = capabilities.add_deny(cap)
      "ask" => ask_rules = ask_rules + [cap]
      _ => raise PolicyError::InvalidJson("unknown rule type: " + r.rule_type)
    }
  }

  Gate::new(capabilities, ask_rules)
}
