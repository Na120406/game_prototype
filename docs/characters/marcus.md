# Character: Marcus (Neighbor)

> Template: [docs/templates/character-sheet-template.md](../templates/character-sheet-template.md)
> GDD reference: [design/gdd/game-demo-gdd-v3.md](../../design/gdd/game-demo-gdd-v3.md)

## Quick Reference

- **Full Name**: Marcus
- **Role in Story**: Day-1 mentor, hint NPC, neighbor-turned-friend
- **Role in Gameplay**: NPC, Quest Giver (dynamic delivery quests), Tutorial Guide
- **First Appearance**: Day 1 morning, before player leaves home
- **Status**: Provisional

## Concept

Marcus is the player's first real contact with the world outside their farmhouse.
He lives on a neighboring farm (`marcus_farm_map`) and shows up unannounced on
Day 1 morning to introduce himself, give practical advice about farming and the
town shop, and — almost as an afterthought — warn the player not to stay up too
late. He's the kind of character who knows more than he says, but keeps his
concerns quiet for now.

He is not part of any family in `FamilyRegistry` — Marcus is intentionally
solitary, which gives him narrative room to comment on family life without being
bound to it.

## Appearance

- **Build**: Average build, similar height to player.
- **Distinguishing Features**: Simple working clothes, no family crest or insignia.
- **Color Palette**: Earth tones (browns, greens) — fits the "neighbor farmer" archetype.
- **Costume/Armor**: Plain farmer clothes. No armor or formal wear.

> Visual assets not yet implemented — placeholder TBD by art pass.

## Personality

### Core Traits

- Warm and approachable — first impression is reassuring.
- Practical — gives actionable advice, not vague encouragement.
- Knowledgeable but guarded — hints at deeper knowledge of the area, doesn't elaborate.
- Reliable — always at his farm during his schedule.

### Voice Profile

- **Speech Pattern**: Casual, conversational Vietnamese. No formal pronouns.
- **Vocabulary Level**: Everyday language. No technical or archaic terms.
- **Verbal Tics**: Uses "cậu" (informal "you") when addressing the player.
- **Tone Reference**: A friendly older neighbor, not a sage or mentor.

### Emotional Range

| Emotion       | Trigger                              | Expression              | Example Line                                                                |
|---------------|--------------------------------------|-------------------------|-----------------------------------------------------------------------------|
| Friendly      | First meeting / normal chat          | Warm, direct            | "À, cuối cùng cậu cũng dậy! Tôi cứ tưởng cậu ngủ quên cả tuần rồi chứ."   |
| Practical     | Giving advice                        | Matter-of-fact          | "Trang trại hơi bừa bộn, nhưng đất ở đây tốt."                            |
| Warning       | Mentioning the late-night danger     | Slightly serious       | "Có một điều — đừng thức khuya quá nửa đêm. Ở vùng này, ai liều mạng..." |
| Impatient     | Player hasn't delivered quest item  | Slightly exasperated  | (See `neighbor_still_need` dialogue)                                        |
| Pleased       | Player delivers the right item       | Satisfied              | (See `neighbor_delivery` dialogue)                                          |

## Motivation and Arc

### Primary Motivation

Help the player establish themselves on the farm. Beneath that, he has a quiet
investment in the player not repeating whatever happened to previous newcomers
— hinted at by his "đừng thức khuya" warning.

### Character Arc

| Phase          | State                                                              | Turning Point                                          |
|----------------|--------------------------------------------------------------------|--------------------------------------------------------|
| Introduction   | Friendly mentor, gives Day-1 tutorial dialogue.                   | First time player leaves the house on Day 1.           |
| Development    | Becomes the quest giver for delivery tasks. Comments on player progress. | First delivery quest completion.                  |
| Resolution     | TBD — depends on event chains and quest outcomes.                  | TBD.                                                   |

### Internal Conflict

Marcus knows something about this area that he doesn't tell the player
upfront. His advice is practical, but the warning about staying up late carries
a weight he hasn't explained yet. This is a setup for later event chains.

## Relationships

| Character            | Relationship        | Dynamic                                | Player Can Affect? |
|----------------------|---------------------|----------------------------------------|--------------------|
| Player               | Neighbor / Mentor   | Warm but slightly guarded               | Yes (quest delivery, dialogue) |
| Shopkeeper family    | Acquaintance        | Marcus mentions the shopkeeper in Day-1 dialogue. | No direct interaction yet |
| Hermit               | Distant acquaintance | Both live in the area but rarely interact on-screen. | No |

## Gameplay Function

### What This Character Provides to the Player

- **Services**: None commercial. Acts as a tutorial guide.
- **Information**: How to farm (plant + water daily), where the town shop is, who runs it, the late-night warning.
- **Mechanical interactions**: 
  - Dynamic delivery quest generation via `QuestSystem.generate_delivery_quest_for_neighbor()`.
  - Hotbar-aware dialogue: when player has the correct item selected on hotbar, Marcus accepts the delivery. Otherwise he says "still need it".

### Encounter Design Notes

Marcus has 4 schedules (`scripts/npc/neighbor.gd`):

1. **Waiting at player's house** (Day 1, before meeting): one static step, Marcus stands at `player_house_door_position`.
2. **After-intro to town** (Day 1, meeting before 11:00): Marcus waits at `town_position` until 11:00, then walks to farm, tends garden, etc.
3. **In-farm normal** (Day 1 after 11:00 OR Day 2+): Standard daily schedule from `marcus_farm_map` (wake 6:00, work 8:00, lunch 11:00, work 12:00, home 17:00, chat 20:00, sleep 22:00).
4. **In-town** (rare, not currently triggered by `interact` logic): Full day in town.

Movement currently uses stubbed pathfinding (`npc.gd`) — Phase 3 of GDD roadmap.

## Dialogue Notes

### Topics This Character Can Discuss

- Farming basics (planting, watering, harvest).
- The town shop and the shopkeeper.
- The late-night danger (hinted, not explained).
- His own farm (Marcus does gardening around `marcus_farm_map`).

### Topics This Character Avoids or Lies About

- The specific nature of the late-night danger.
- Why he's watching out for newcomers.
- The history of the area.

### Dialogue State Dependencies

| Game State                                      | Dialogue Change                                  |
|-------------------------------------------------|--------------------------------------------------|
| `current_day == 1` AND no `neighbor_met_day1`  | "neighbor" intro dialogue (auto-cutscene + interact). |
| `current_day == 1` AND met                      | Rebuild schedule to `_schedule_in_farm` or `_schedule_after_intro_to_town`. |
| Active delivery quest AND correct item on hotbar | "neighbor_delivery" (accepts delivery).         |
| Active delivery quest AND wrong/no item selected | "neighbor_still_need" (asks for the right item). |
| `current_day >= 2` AND no active quests         | "neighbor_day2_plus" or "neighbor_idle".         |

## Lore Connections

- Day-1 dialogue references the shopkeeper and the general area, connecting Marcus to the broader NPC social web.
- The "late-night warning" hints at the event chain system and consequences from `RiskCalculator` — Marcus knows someone who didn't listen.

## Cross-References

- **Design Doc**: [GDD v3, §2.4 NPC & Family](../../design/gdd/game-demo-gdd-v3.md#24-npc--family)
- **Quest Doc**: Quest system in [GDD v3, §2.5](../../design/gdd/game-demo-gdd-v3.md#25-quest-system)
- **Source Code**: [scripts/npc/neighbor.gd](../../scripts/npc/neighbor.gd), [resources/dialogue/neighbor.json](../../resources/dialogue/neighbor.json)
- **Scene**: [scenes/npc/neighbor.tscn](../../scenes/npc/neighbor.tscn), [scenes/maps/marcus_farm_map.tscn](../../scenes/maps/marcus_farm_map.tscn), [scenes/maps/marcus_house_map.tscn](../../scenes/maps/marcus_house_map.tscn)
