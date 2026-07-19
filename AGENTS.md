# Game Development Agents — Farm Horror Demo

This project uses **Claude-Code-Game-Studios** principles with specialized agents for game development.

## Available Agents

### Godot Specialist Agents

| Agent | Role | When to Use |
|-------|------|-------------|
| `godot-specialist` | Godot engine expert | Architecture, APIs, optimization, export |
| `godot-gdscript-specialist` | GDScript patterns | Code quality, GDScript best practices |
| `game-designer` | Systems & mechanics | Design decisions, balance, progression |
| `narrative-director` | Story & lore | Narrative consistency, dialogue |
| `creative-director` | Vision guardian | Design pillars, project direction |

### Code Quality Agents

| Agent | Purpose | When to Use |
|-------|---------|-------------|
| `code-reviewer` | Code quality review | After writing/modifying code |
| `tdd-guide` | Test-driven development | New features, bug fixes |
| `security-reviewer` | Vulnerability detection | Before commits, sensitive code |
| `planner` | Implementation planning | Complex features, refactoring |
| `architect` | System design | Architectural decisions |

## Agent Definitions

See `.cursor/agents/` for full agent configurations:
- `godot-specialist.md` — Godot Engine Specialist
- `game-designer.md` — Game Designer
- `godot-gdscript-specialist.md` — GDScript Specialist
- `narrative-director.md` — Narrative Director
- `creative-director.md` — Creative Director

## Using Agents

**Example workflow:**
1. Complex feature → Use `planner` agent first
2. Design decision → Use `game-designer` or `creative-director`
3. Godot-specific question → Use `godot-specialist`
4. After coding → Use `code-reviewer`
5. New feature → Use `tdd-guide`

## Collaboration Protocol

**User-driven collaboration, not autonomous execution.**
Every task follows: **Question → Options → Decision → Draft → Approval**

- Agents MUST ask before using Write/Edit tools
- Agents MUST show drafts or summaries before requesting approval
- Multi-file changes require explicit approval
- No commits without user instruction

---

*Additional general agents available: planner, architect, tdd-guide, code-reviewer, security-reviewer, build-error-resolver, and more.*
