# Game Design Skill

Use this skill when you need to design or analyze game mechanics, systems, progression, or player experiences.

## When to Use

- Designing core gameplay loops
- Creating new game systems (combat, crafting, economy)
- Balancing numeric values
- Defining player progression
- Analyzing player motivation and engagement
- Creating game design documents (GDDs)
- Reviewing existing mechanics for improvements

## Design Frameworks

### MDA Framework (Hunicke, LeBlanc, Zubek)
Design from the player's emotional experience backward:
- **Aesthetics** (what the player FEELS): Sensation, Fantasy, Narrative, Challenge, Fellowship, Discovery, Expression
- **Dynamics** (emergent behaviors): patterns that arise from mechanics
- **Mechanics** (the rules): formal systems that generate dynamics

### Self-Determination Theory
Every system should satisfy at least one core need:
- **Autonomy**: meaningful choices where multiple paths are viable
- **Competence**: clear skill growth with readable feedback
- **Relatedness**: connection to characters or the game world

### Flow State Design
Maintain the player in the flow channel:
- Onboarding: first 10 minutes teach through play, not tutorials
- Difficulty curve: follows a sawtooth pattern
- Feedback clarity: consequences within 0.5 seconds
- Failure recovery: cost proportional to frequency

## Design Document Standard

Every mechanic document should contain:

1. **Overview**: One-paragraph summary
2. **Player Fantasy**: What the player should FEEL
3. **Detailed Rules**: Precise, unambiguous rules
4. **Formulas**: Mathematical formulas with variable definitions
5. **Edge Cases**: What happens in unusual situations
6. **Dependencies**: What other systems this interacts with
7. **Tuning Knobs**: What values are adjustable for balancing
8. **Acceptance Criteria**: How do we know this is working?

## Balancing Methodology

### Tuning Knob Categories
1. **Feel knobs**: affect moment-to-moment experience (attack speed, movement)
2. **Curve knobs**: affect progression shape (requirements, scaling)
3. **Gate knobs**: affect pacing (level requirements, thresholds)

### Economy Design
Apply sink/faucet model:
- Map every faucet (source of currency entering)
- Map every sink (destination removing currency)
- Balance over target session length

## Example Questions

- "What core loop would keep players engaged?"
- "How should we balance X vs Y?"
- "What progression system fits our player base?"
- "What edge cases should we handle for this mechanic?"
- "Does this design serve the stated player fantasy?"

## Templates Available

See `docs/templates/` for:
- `gdd-template.md` - Game Design Document template
- `character-sheet-template.md` - NPC/Character design template
- `systems-index-template.md` - Systems tracking template

## Related Skills

- `/godot` - For engine-specific implementation questions
- `/code-review` - For reviewing implementation quality
- `/testing` - For verifying design through playtesting
