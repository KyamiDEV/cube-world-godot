# `autoload/`

Global singletons registered in `project.godot [autoload]`.

Rules:
- A singleton here must be a **service**, not a subsystem dump.
- No gameplay rules, no world generation, no networking policy.
- Anything stateful here must be resettable for tests.
