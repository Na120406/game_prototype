# Character: The Voss Family (Shopkeeper)

> Template: [docs/templates/character-sheet-template.md](../templates/character-sheet-template.md)
> GDD reference: [design/gdd/game-demo-gdd-v3.md](../../design/gdd/game-demo-gdd-v3.md)
>
> This sheet covers the entire Voss family (currently two members), since the
> gameplay unit is the family business rather than either individual alone.

## Quick Reference

| Member           | Full Name  | Role in Story         | Role in Gameplay    | First Appearance | Status      |
|------------------|------------|-----------------------|---------------------|------------------|-------------|
| Old Voss         | Old Voss   | Patriarch, shopkeeper | NPC, Merchant       | Game start       | Provisional |
| Young Voss       | Young Voss | Son, successor        | NPC, Merchant (alt) | If Old Voss dies | Provisional |

- **Family ID**: `shopkeeper_family`
- **Surname**: Voss
- **Business**: Voss General Store (town shop)
- **Home location**: `Vector2(240, 320)` in town area

## Concept

The Voss family runs the only general store in town. They're the player's main
point of commerce — buying seeds, tools, consumables, and selling farm produce.
Old Voss (the father) is the cautious, gruff face of the business. Young Voss
(the son) is reckless in a way his father disapproves of, but he's also the
designated successor.

The family's most dramatic gameplay hook is **Old Voss's Saturday mountain
trip** — every Saturday morning he leaves on a scheduled risk activity that
can result in `SAFE`, `INJURED`, `DEAD`, `MISSED`, or `DELAYED` outcomes. If he
dies, Young Voss inherits and the shop continues under new management. If he's
just injured, the shop closes for a few days.

## Appearance

### Old Voss (father)

- **Build**: Stocky middle-aged man.
- **Distinguishing Features**: Apron, eyeglasses (or squinting expression), behind-the-counter posture.
- **Color Palette**: Muted earth tones (brown, gray).
- **Costume/Armor**: Shopkeeper apron, plain shirt and trousers.

### Young Voss (son)

- **Build**: Younger, leaner, similar height to father.
- **Distinguishing Features**: Hasty demeanor, possibly wears a different apron.
- **Color Palette**: Slightly brighter than father — same brown family but lighter.
- **Costume/Armor**: Same shopkeeper apron style, possibly with rolled sleeves.

> Both members' visual assets are pending — `scenes/npc/shopkeeper_father.tscn` and
> `scenes/npc/shopkeeper_son.tscn` are referenced in `FamilyRegistry` but the
> scene files are not yet created (TODO.md).

## Personality

### Old Voss — Core Traits

- Cautious (personality: `cautious`).
- Business-minded — prioritizes shop profit over risk-taking.
- Disapproves of his son's recklessness.
- Gruff with outsiders but not unkind.

### Young Voss — Core Traits

- Reckless (personality: `reckless`).
- Impatient — wants to prove himself.
- Doesn't fear the same things his father fears.
- Has a Thursday night walk schedule (NPCSchedules, day_of_week=4, departure 21:00).

### Voice Profile (both)

- **Speech Pattern**: Town vernacular. More formal than Marcus's neighborly tone.
- **Vocabulary Level**: Everyday Vietnamese, with occasional commerce jargon.
- **Verbal Tics**: Old Voss uses "ông" (formal self-reference); Young Voss is more casual.
- **Tone Reference**: Small-town shopkeeper, generational gap.

### Emotional Range — Old Voss

| Emotion       | Trigger                              | Expression              |
|---------------|--------------------------------------|-------------------------|
| Grumpy        | Player tries to haggle               | Stern but not hostile   |
| Practical     | Discussing seed prices               | Matter-of-fact          |
| Anxious       | Approaching his Saturday mountain trip | Quiet concern         |
| Grieving      | Family status REDUCED                | Uses `_grief` dialogue suffix |

### Emotional Range — Young Voss

| Emotion       | Trigger                              | Expression              |
|---------------|--------------------------------------|-------------------------|
| Confident     | Talking about taking over the shop   | Brash, sure of himself  |
| Impatient     | Any delay or waiting                 | Fidgety, direct         |
| Defiant       | Father's caution                     | Dismissive              |

## Motivation and Arc

### Primary Motivation

**Old Voss:** Keep the shop running. Provide for the family. Survive the mountain.

**Young Voss:** Prove he can run the shop. Establish independence.

### Joint Family Arc

| Phase           | State                                                              | Turning Point                                       |
|-----------------|--------------------------------------------------------------------|-----------------------------------------------------|
| Introduction    | Old Voss at the counter, normal shop hours.                       | Game start.                                         |
| Development     | Saturday mountain trips define the rhythm of danger.               | First Saturday (event chain trigger).               |
| Resolution      | TBD — depends on player intervention and rolls.                    | Outcome of `shopkeeper_mountain` chain.             |

### Internal Conflict

Old Voss knows the mountain is dangerous (chain has 5% base dead weight, 15% injured).
He goes anyway — out of obligation, ritual, or something he hasn't told his son.
Young Voss's Thursday night walks hint at a separate, parallel recklessness.

## Relationships

| Character            | Relationship        | Dynamic                                | Player Can Affect? |
|----------------------|---------------------|----------------------------------------|--------------------|
| Player               | Shopkeeper          | Commercial relationship.               | Yes (buy/sell).    |
| Marcus (neighbor)    | Acquaintance        | Marcus mentions the shopkeeper in his Day-1 dialogue. | Indirect. |
| Hermit               | Town resident       | Both live in the area.                 | Indirect.          |
| Family internal      | Father & son        | Old Voss: cautious, disapproving. Young Voss: defiant, eager to inherit. | No (story-fixed). |

## Gameplay Function

### What This Character Provides to the Player

- **Services**: 
  - Buy/sell items via Shop UI (`scripts/ui/shop_ui.gd`).
  - Quests from shopkeeper (static, not yet fully wired in code).
- **Information**: 
  - Pricing, item availability.
  - Lore about the area via dialogue.
- **Mechanical interactions**: 
  - Shop open/closed state controlled by `ConsequenceResolver` via `apply_scene_change("res://scenes/world/shop.tscn", "set_shop_state", "closed")`.
  - Family succession via `FamilyRegistry._promote_successor` or `replace_family_member`.

### Encounter Design Notes

#### Saturday Mountain Trip (`shopkeeper_mountain` chain)

| Property | Value |
|----------|-------|
| Schedule | `day_of_week=5` (Saturday), departure 7:00, return 18:00 |
| Trigger | `EventChainEngine.trigger_chain("shopkeeper_mountain", context)` |
| Outcomes | `safe` (70%), `delayed` (10%), `injured` (15%), `dead` (5%) |
| Branches | `injured_player_escorted` (-8% injured, -3% dead), `injured_bad_weather` (+15% injured), `dead_bad_weather` (+20% injured, +20% dead) |
| Consequences by outcome | |
| — safe | None |
| — delayed | `shop_late_open` |
| — injured | `shopkeeper_injured`, `shop_closed_days` (2-4 days) |
| — dead | `shopkeeper_dead`, `shop_closes`, `funeral_scheduled` (3 days), `son_takes_over` (3 days) |

> **Note**: Schedule exists in `NPCSchedules` and chain definition exists in
> `EventChainEngine`, but no code currently calls `trigger_chain` from the
> schedule. This is a Phase 4 wiring task.

#### Thursday Night Walk (`shopkeeper_son` chain, TBD)

| Property | Value |
|----------|-------|
| Schedule | `day_of_week=4` (Thursday), departure 21:00, return 23:00 |
| Risk activity | `night_walk` |
| Chain | Not yet defined. The chain_id is empty in `NPCSchedules`. |

## Dialogue Notes

### Topics Old Voss Can Discuss

- Shop inventory and prices.
- The town (who lives where, what's normal).
- His mountain trips (briefly, without revealing danger).
- His son (mildly disapproving).

### Topics Old Voss Avoids or Lies About

- Why he keeps going to the mountain despite the danger.
- The deeper history of the area.

### Topics Young Voss Can Discuss

- His ambitions for the shop.
- His father's caution (dismissively).

### Dialogue State Dependencies (Old Voss)

| Game State                                | Dialogue Change                              |
|-------------------------------------------|----------------------------------------------|
| Family status REDUCED                     | Dialogue ID gets `_grief` suffix (per `FamilyRegistry.get_dialogue_for_current_head`). |
| `shop_open == false`                      | Shop scene shows closed state.               |
| `new_shopkeeper == true`                  | Young Voss takes over the shop.              |

## Lore Connections

- Saturday mountain trips hint at a recurring seasonal danger (old tradition, pilgrimage, or something more).
- Young Voss's Thursday night walks parallel his father's risk pattern — suggests an inherited recklessness or a family secret.
- The shop is the only commercial hub — its closure ripples through player economy.

## Cross-References

- **Design Doc**: [GDD v3, §2.4 NPC & Family](../../design/gdd/game-demo-gdd-v3.md#24-npc--family)
- **Risk / Event**: [GDD v3, §2.6](../../design/gdd/game-demo-gdd-v3.md#26-risk-calculator--event-chain)
- **Consequence**: [GDD v3, §2.7](../../design/gdd/game-demo-gdd-v3.md#27-consequence-resolver)
- **Source Code**:
  - [scripts/autoload/family_registry.gd](../../scripts/autoload/family_registry.gd)
  - [scripts/autoload/npc_schedules.gd](../../scripts/autoload/npc_schedules.gd)
  - [scripts/autoload/event_chain_engine.gd](../../scripts/autoload/event_chain_engine.gd)
  - [scripts/autoload/consequence_resolver.gd](../../scripts/autoload/consequence_resolver.gd)
  - [scripts/npc/shopkeeper.gd](../../scripts/npc/shopkeeper.gd)
- **Scene**: `scenes/npc/shopkeeper.tscn` (placeholder — Voss shared scene?), `scenes/maps/inside_shop_map.tscn`, `scenes/maps/town_map.tscn`
- **Missing assets** (TODO): `scenes/npc/shopkeeper_father.tscn`, `scenes/npc/shopkeeper_son.tscn`
