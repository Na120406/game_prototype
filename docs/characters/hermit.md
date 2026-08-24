# Character: Old Hanz (The Hermit)

> Template: [docs/templates/character-sheet-template.md](../templates/character-sheet-template.md)
> GDD reference: [design/gdd/game-demo-gdd-v3.md](../../design/gdd/game-demo-gdd-v3.md)

## Quick Reference

- **Full Name**: Old Hanz (a.k.a. "The Hermit")
- **Role in Story**: Mysterious recluse, possible lore keeper
- **Role in Gameplay**: NPC, sparse dialogue, location-based encounter
- **First Appearance**: When player finds his home in the forest edge area
- **Status**: Provisional (least-developed of the three covered NPCs)

## Concept

Old Hanz is the only registered member of the `hermit_family`. He lives alone
at the edge of the forest, away from town. He takes a Wednesday forest walk
that — unlike Old Voss's mountain trip — currently has no event chain attached.

Hermit is intentionally under-defined in the current codebase. His home
location (`Vector2(600, 400)`) places him outside the main town and farm
cluster, suggesting isolation. His dialogue ID is `hermit_normal`. The
personality trait is `old` — which is personality-trait-data rather than a
proper behavioral profile.

He is the lightest of the three NPC sheets because there is very little
in-game content for him right now. This sheet exists to track what's been
promised and what still needs to be designed.

## Appearance

- **Build**: Elderly, weathered. Lean from years of outdoor living.
- **Distinguishing Features**: Long beard, worn clothes, possibly carries a walking stick.
- **Color Palette**: Muted greens and grays — blending with forest surroundings.
- **Costume/Armor**: Layered, patched clothing. Practical, not formal.

> Visual assets not yet implemented — placeholder TBD.

## Personality

### Core Traits

- Reserved — speaks only when addressed.
- Perceptive — observes more than he says.
- Self-sufficient — does not rely on town.
- Old (personality tag in `FamilyRegistry`) — may affect risk calculations.

### Voice Profile

- **Speech Pattern**: Sparse, slow. Long pauses implied between sentences.
- **Vocabulary Level**: Simple but with occasional archaic or poetic phrasing.
- **Verbal Tics**: Avoids direct pronouns. Often answers questions with observations rather than yes/no.
- **Tone Reference**: A forest sage, but not mystical — grounded and practical.

### Emotional Range

| Emotion       | Trigger                              | Expression              |
|---------------|--------------------------------------|-------------------------|
| Quiet         | Most interactions                    | Calm, observing         |
| Discomfort    | Asked about the past or the area's history | Pauses, changes subject |
| Warmth        | Player shows respect or brings gift  | Brief smile, slight nod  |

## Motivation and Arc

### Primary Motivation

Unknown / Undefined. The current codebase does not specify what Hanz wants.

This is a deliberate gap — Hermit is positioned to be a **lore dump** for
future content, but his narrative role has not been written yet.

### Character Arc

| Phase          | State                                                              | Turning Point                                          |
|----------------|--------------------------------------------------------------------|--------------------------------------------------------|
| Introduction   | Found at home. Limited dialogue.                                   | Player finds his location.                             |
| Development    | TBD — depends on event chain design.                               | TBD.                                                   |
| Resolution     | TBD.                                                               | TBD.                                                   |

### Internal Conflict

TBD. Hermit may know something about the area's deeper history (the same
history Marcus hints at) but has chosen silence. Whether this is guilt, fear,
or wisdom is undecided.

## Relationships

| Character            | Relationship        | Dynamic                                | Player Can Affect? |
|----------------------|---------------------|----------------------------------------|--------------------|
| Player               | Distant acquaintance | Minimal interaction.                  | Yes (visit, give items). |
| Marcus               | Town-area resident | Both live on the edges, may have crossed paths. | No.        |
| Shopkeeper family    | Town resident       | Hanz is the outsider.                  | No.                |
| Miller family        | Same hermit_family registry group | Not related.                    | N/A.               |

> **Note**: Hanz is registered in `hermit_family`, which is intentionally a
> single-member "family" (no surname, no business). This is a design choice —
> he's structurally isolated even within the family system.

## Gameplay Function

### What This Character Provides to the Player

- **Services**: None currently.
- **Information**: 
  - Possible lore drop (TBD).
  - Hint NPC for harder-to-find content.
- **Mechanical interactions**: 
  - `NPCSchedules.forest_walk` on Wednesday (day_of_week=3, departure 6:00, return 17:00, risk_activity=`forest_walk`).
  - No event chain currently wired for this activity.

### Encounter Design Notes

#### Wednesday Forest Walk (TBD chain)

| Property | Value |
|----------|-------|
| Schedule | `day_of_week=3` (Wednesday), departure 6:00, return 17:00 |
| Risk activity | `forest_walk` |
| Chain ID | Empty string — no chain definition exists yet |
| Personality | `old` (may modify risk via `RiskCalculator`) |

> **Open design question**: should Hanz's Wednesday walks be dangerous? Or
> should they be a narrative device (he meets someone in the forest, learns
> something, returns with cryptic information)? The current risk_activity tag
> suggests danger, but no chain defines outcomes.

Movement currently uses stubbed pathfinding (`npc.gd`) — Phase 3 of GDD roadmap.

## Dialogue Notes

### Topics This Character Can Discuss

- The forest itself (animals, paths, seasons).
- Weather and seasonal patterns.
- Gardening basics (he's old enough to have farming wisdom).

### Topics This Character Avoids or Lies About

- His past.
- Why he lives alone.
- The area's hidden history.

### Dialogue State Dependencies

| Game State            | Dialogue Change                              |
|-----------------------|----------------------------------------------|
| Default               | `hermit_normal` dialogue                     |
| Family status changed | (TBD — single-member family, no succession) |

## Lore Connections

- Hermit is positioned as the **lore NPC** — the character who would explain
  the deeper history if the player earns his trust.
- His home location (`Vector2(600, 400)`) is far from the main farm and town,
  implying either deliberate isolation or a reason to avoid the town.
- The `old` personality tag may interact with `RiskCalculator` to give him
  lower base risk but higher consequences when something does go wrong.

## Cross-References

- **Design Doc**: [GDD v3, §2.4 NPC & Family](../../design/gdd/game-demo-gdd-v3.md#24-npc--family)
- **Source Code**:
  - [scripts/autoload/family_registry.gd](../../scripts/autoload/family_registry.gd) (hermit_family definition)
  - [scripts/autoload/npc_schedules.gd](../../scripts/autoload/npc_schedules.gd) (forest_walk entry)
- **Scene**: `scenes/npc/hermit.tscn` (referenced in FamilyRegistry but file does not exist yet — TODO.md)
- **Dialogue**: `resources/dialogue/hermit.json` (referenced via `hermit_normal` dialogue_id — verify existence)

## What's Missing (for future iteration)

- [ ] Hermit's actual dialogue JSON content.
- [ ] An event chain for `forest_walk` (or a narrative justification for no chain).
- [ ] His motivation and arc.
- [ ] His relationship to the area's hidden history (if any).
- [ ] Scene file `scenes/npc/hermit.tscn`.
- [ ] Whether he has any quest-giver role.
