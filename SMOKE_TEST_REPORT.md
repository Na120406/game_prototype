# GameDemo - Báo cáo Smoke Test & Playtest
**Ngày thực hiện:** 2026-08-27  
**Build:** Development (Godot 4.5 stable)  
**Người test:** AI Agent + Automated Scripts

---

## 1. TÓM TẮT KẾT QUẢ

### ✅ PASSED: Game khởi động thành công
- ✅ Tất cả 30 autoloads load thành công
- ✅ Main scene (inside_house_map.tscn) load thành công
- ✅ Player spawn đúng vị trí
- ✅ GameState khởi tạo: Day 1, 6:00, Gold OK
- ✅ EnergyManager, TimeManager, QuestSystem, NPCManager ready
- ✅ 21 items loaded từ ItemDB
- ✅ 2 NPCs registered (neighbor, shopkeeper)
- ✅ 4 quests available
- ✅ UI systems spawned: ShopUI, Hotbar, InventoryUI

### ⚠️ WARNINGS (không blocking nhưng cần chú ý)
- ⚠️ ConfigManager: Unknown root paths (scene.transition_duration, scenes.town, scenes.player_farm, scenes.inside_house)
- ⚠️ 6 scene files missing (đã xác nhận trong TODO.md):
  - `res://scenes/world/shop.tscn`
  - `res://scenes/npc/shopkeeper_father.tscn`
  - `res://scenes/npc/shopkeeper_son.tscn`
  - `res://scenes/npc/farmer_mother.tscn`
  - `res://scenes/npc/farmer_daughter.tscn`
  - `res://scenes/npc/hermit.tscn`

### ❌ KHÔNG THỂ KIỂM TRA (do limitation của headless mode)
- Player WASD movement
- Collision detection
- UI input (Tab, 1-5, E, X)
- Scene transition via portals
- Farming interaction (left-click plots)
- Dialogue interaction
- Shop interaction
- Quest Board interaction
- Visual feedback

---

## 2. CHI TIẾT SMOKE TEST TỰ ĐỘNG

### Test 1: Autoload Availability
```
✅ GameState
✅ TimeManager
✅ EnergyManager
✅ ItemManager
✅ QuestSystem
✅ NPCManager
✅ DialogueManager
✅ SceneManager
```
**Kết quả:** 8/8 PASS

### Test 2: Critical Scenes
```
✅ res://scenes/maps/inside_house_map.tscn
✅ res://scenes/maps/farm_map_v2.tscn
✅ res://scenes/maps/town_map.tscn
✅ res://scenes/Player.tscn
✅ res://scenes/npc/neighbor.tscn
✅ res://scenes/npc/shopkeeper.tscn
```
**Kết quả:** 6/6 PASS

### Test 3: Known Missing Scenes
```
⚠️ res://scenes/world/shop.tscn - MISSING (expected)
⚠️ res://scenes/npc/shopkeeper_father.tscn - MISSING (expected)
⚠️ res://scenes/npc/shopkeeper_son.tscn - MISSING (expected)
⚠️ res://scenes/npc/farmer_mother.tscn - MISSING (expected)
⚠️ res://scenes/npc/farmer_daughter.tscn - MISSING (expected)
⚠️ res://scenes/npc/hermit.tscn - MISSING (expected)
```
**Kết quả:** 6/6 confirmed as known issues

---

## 3. RUNTIME LOG ANALYSIS

### Startup Sequence (5 giây headless run)
```
[ConfigManager] Loaded all configs ✓
[GameState] Initialized — Day 1, 6:00 ✓
[AudioManager] Ready ✓
[TimeManager] Ready ✓
[WeatherSystem] Ready. Season: spring, Weather: clear ✓
[FamilyRegistry] Ready — 3 families registered ✓
[NPCSchedules] Ready — 4 schedules loaded ✓
[QuestSystem] Ready — 4 quests available ✓
[NPCManager] Ready — 2 NPCs registered ✓
[ItemDB] Total items loaded: 21 ✓
[Player] Ready at position: (380.0, 160.0) ✓
[WorldUIManager] ShopUI spawned ✓
[Hotbar] _setup_slots ✓
[InventoryUI] _ready ✓
[NPCManager] _sync_one 'neighbor' ✓
```

### Warnings Detected
```
WARNING: [ConfigManager] Unknown root in path: scene.transition_duration
  → Không blocking, SceneManager vẫn load được transition_duration = 0.5
  
WARNING: [ConfigManager] Unknown root in path: scenes.town
WARNING: [ConfigManager] Unknown root in path: scenes.player_farm
WARNING: [ConfigManager] Unknown root in path: scenes.inside_house
  → Neighbor NPC config references scene paths không tồn tại trong config
  → Không blocking vì game sử dụng fallback
```

---

## 4. ĐÁNH GIÁ MỨC ĐỘ SẴN SÀNG

### Có thể chạy được không?
**✅ CÓ** - Game khởi động, load scene, spawn player, khởi tạo tất cả systems thành công.

### Có blocking bug không?
**❌ KHÔNG** - Không phát hiện lỗi blocking trong smoke test 5 giây.

### Core loop có hoạt động không?
**⚠️ CHƯA KIỂM TRA ĐẦY ĐỦ** - Cần manual playtest với GUI để xác nhận:
- Farming loop (plow → plant → water → harvest)
- Shop transaction (buy/sell)
- Quest delivery
- NPC interaction
- Scene transition
- Sleep cycle

### Sẵn sàng upload itch.io WebGL?
**⚠️ CHƯA SẴN SÀNG** - Lý do:
1. ❌ Chưa có export preset WebGL
2. ❌ Chưa test WebGL build
3. ❌ Chưa manual playtest core loop end-to-end
4. ❌ Chưa có intro/title screen
5. ⚠️ Missing scene references có thể gây crash runtime

---

## 5. RỦI RO VÀ KHUYẾN NGHỊ

### Rủi ro CẤP ĐỘ CAO nếu upload ngay
1. **Missing shop.tscn** được reference trong:
   - `ConsequenceResolver.apply_consequence_set("shop_closed")`
   - `EventChainEngine` line 510
   - → Nếu event chain trigger, game crash

2. **Missing family NPC scenes** được reference trong:
   - `FamilyRegistry` line 79, 91, 118, 130, 156
   - → Nếu có logic spawn family members, game crash

3. **Input action mojibake** ở project.godot line 95:
   - Action name có ký tự lỗi: `#Chuá»ttrÃ¡iâdÃ¹ng...mouse_left`
   - → Có thể gây lỗi input detection

### Rủi ro CẤP ĐỘ TRUNG BÌNH
1. **Config path warnings** - không blocking nhưng gây noise trong log
2. **Audio missing** - AudioManager ready nhưng chưa có asset files
3. **Chưa có regression test** - sửa bug có thể gây bug mới

### Khuyến nghị TRƯỚC KHI UPLOAD

#### ✅ BẮT BUỘC (P0)
1. **Manual playtest core loop:**
   ```
   House → Farm → Plow/Plant/Water → Town → Shop → Buy/Sell → 
   Quest Board → Accept Quest → Deliver → Sleep → Day 2
   ```
2. **Fix hoặc disable missing scene references:**
   - Comment out shop_closed consequence
   - Comment out family member spawn logic
   - Hoặc tạo placeholder scenes

3. **Fix input action mojibake:**
   - Sửa line 95 project.godot
   - Đổi tên action thành `mouse_left` clean

4. **Test WebGL export:**
   - Tạo export preset
   - Export thử
   - Chạy local HTTP server
   - Test trong Chrome/Edge

#### 🔧 NÊN LÀM (P1)
1. Tạo title screen/intro
2. Add instructions/controls screen
3. Fix ConfigManager path warnings
4. Add placeholder audio hoặc disable AudioManager SFX calls
5. Test save/load cycle

#### 💡 CÓ THỂ DEFER (P2)
1. Hoàn thiện missing family NPC scenes
2. Hoàn thiện shop.tscn
3. Thêm balancing data từ playtest
4. Polish visual/audio

---

## 6. QUY TRÌNH ĐỀ XUẤT

### Tuần 1: Fix Critical Issues
```
Day 1: Manual playtest full core loop
Day 2: Fix blocking bugs phát hiện
Day 3: Disable/stub missing scene references
Day 4: Fix input action name
Day 5: Retest smoke + manual
```

### Tuần 2: WebGL Export
```
Day 1: Tạo export preset
Day 2: Test export local
Day 3: Upload itch.io (private)
Day 4: Test trên itch.io
Day 5: Update portfolio với link
```

---

## 7. KẾT LUẬN

### Câu trả lời cho câu hỏi: "Game đã sẵn sàng upload itch.io chưa?"

**KHÔNG, NHƯNG GẦN SẴN SÀNG.**

**Lý do:**
- ✅ Technical foundation vững: Game khởi động OK, systems work
- ✅ No crash trong 5s runtime headless
- ⚠️ Chưa có bằng chứng core loop hoạt động end-to-end
- ❌ Có missing references gây rủi ro crash runtime
- ❌ Chưa có WebGL build

**Thời gian ước tính để sẵn sàng:** 3-5 ngày work (nếu làm P0 tasks)

**Đánh giá portfolio hiện tại:**
- GDD: 9/10 (rất tốt, đã sửa)
- Smoke test: 7/10 (pass nhưng chưa đủ để confirm playable)
- Playable build: 0/10 (chưa có)

**Khuyến nghị gửi hồ sơ:**
1. Nếu KHÔNG CÓ playable build: Gửi GDD + video captured (quay màn hình khi chạy manual)
2. Nếu CÓ 3-5 ngày: Fix P0, export WebGL, test, rồi gửi GDD + itch.io link

---

**Generated by:** Automated Smoke Test + Runtime Analysis  
**Tool:** Godot 4.5 console + GDScript MainLoop test  
**Status:** ✅ Foundation solid | ⚠️ Core loop unverified | ❌ WebGL not ready
