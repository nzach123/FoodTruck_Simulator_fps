# Midnight Munch — Technical Implementation Plan (Part 2)

*Continuation of Part 1. Phases 2–4, signal connection map, and full QA checklist.*

---

## 5. Step-by-Step Execution Plan (continued)

### PHASE 2 — Game Loop, Order System & Serving (Week 2)

**Task 2.1 — NodePool Implementation**
- [ ] Implement `NodePool._prewarm()`: instantiate `count` nodes from packed scene, call `hide()`, parent to `NodePoolContainer`
- [ ] Implement `NodePool.checkout()`: find first hidden node in pool, call `show()`, return it. Assert if pool is empty (signals over-pooling; never crash — fallback instantiate with warning)
- [ ] Implement `NodePool.ret()`: call `hide()`, reset all state variables on node, re-parent to `NodePoolContainer`
- [ ] Add pool return calls at: order complete (food items), order rejected (food items), customer leave (NPC), 10s timer (dropped toppings)

**Task 2.2 — OrderManager & Recipe Generation**
- [ ] Implement `OrderManager._generate_recipe()`: load `RecipeData.tres`, always include tortilla+meat, then random subset of optionals (0–5)
- [ ] Implement `OrderManager.accept_order(customer)`: set `current_order`, populate `ingredient_states` dict with all required ingredients → `PENDING`
- [ ] Implement `OrderManager.complete_step(id, quality)`: update `ingredient_states[id]`, count sloppy flags, emit `EventBus.order_step_completed`
- [ ] Guard: if `current_order != null`, block accepting a second order (player must serve first)

**Task 2.3 — Order HUD Panel**
- [ ] Create `OrderPanel.tscn`: `VBoxContainer` of `IngredientPill` scenes (one per possible ingredient)
- [ ] `IngredientPill.tscn`: `HBoxContainer` with icon + label + state indicator `ColorRect`
- [ ] Connect `EventBus.order_step_completed` → `OrderPanel.update_pill(id, state)`
- [ ] Pill visual states:
  - `PENDING` → grey outline, no icon
  - `ACTIVE` → pulsing white (shader or `AnimationPlayer` alpha ping-pong)
  - `PERFECT` → green background + ✓
  - `SLOPPY` → orange background + ~
  - `MISSING` → red background + ✗ (set on bell ring with missing items)
- [ ] Panel visible only when `current_order != null`. Clears on serve.

**Task 2.4 — Customer Queue & Patience System**
- [ ] Implement `QueueManager.gd` on `CustomerQueue` node
- [ ] Position 3 spawn slots in world-space (visible through serving window)
- [ ] On `GameManager.day_started`: begin spawn timer based on `DayConfig.spawn_interval`
- [ ] `Customer.gd` patience drain runs in `_physics_process`. Arc bar updated via `Label3D` or `SubViewport`
- [ ] Patience arc turns red when `patience_current < 10.0`
- [ ] Speech bubble: `Sprite3D` or `SubViewport` showing ingredient icons from `OrderData`
- [ ] On customer click (raycast hit, layer 3): `OrderManager.accept_order(customer)` if no active order. Else: no-op.
- [ ] On `Customer.patience_expired`: `EconomyManager.debit(config.penalty_patience)`, customer leave animation, pool return, queue shift

**Task 2.5 — Topping Stations (TIMING interaction) — Wire to full loop**
- [ ] Connect shrinking circle (from Task 1.4 spike) to `ToppingStation.on_interaction_complete(result)`
- [ ] HIT result: emit `order_step_completed(topping_id, PERFECT)` if first attempt. `SLOPPY` if this is a retry.
- [ ] MISS result: checkout `ToppingItem` from pool, apply impulse downward (Jolt physics), `EconomyManager.debit(0.05)`, show `PenaltyTicker` ("-$0.05" floats up over 1 sec via `Tween`)
- [ ] Dropped topping: `RigidBody3D.freeze = true` on first physics collision (`body_entered` signal from floor `Area3D`). Start 10-second `Timer`; on timeout: `NodePool.ret(topping)`.
- [ ] Track first-attempt flag per topping per order in `OrderManager`

**Task 2.6 — Bell Station & Order Validation**
- [ ] `BellStation.tscn`: `interaction_type = INSTANT`
- [ ] `BellStation.on_interaction_complete()`: calls `OrderManager.validate_order()`
- [ ] `validate_order()` returns `true` if all `ingredient_states` are PERFECT or SLOPPY (none PENDING)
- [ ] If complete: `EconomyManager.process_payment(sloppy_flag_count)` → `EventBus.order_completed`
- [ ] If incomplete: show `BellConfirmationPopup` (modal; disable all other input via state machine → MODAL state)
  - YES: mark remaining PENDING items as MISSING in HUD, call `EconomyManager.deduct_food_cost(ingredients)`, `EventBus.order_rejected`
  - NO: hide popup, restore state machine to HOVER/IDLE

---

### PHASE 3 — Progression, Economy & Persistence (Week 2–3 overlap)

**Task 3.1 — Day Timer & Phase Transitions**
- [ ] `GameManager._process(delta)`: decrement `day_timer` while `is_timer_running`. Update `DayTimerLabel` (format `MM:SS`)
- [ ] World-space wall clock: drive a `MeshInstance3D` clock-hand rotation from `day_timer` value
- [ ] On `day_timer <= 0`: `GameManager.end_day()` → sets phase to `END_OF_DAY` → emit `EventBus.day_ended`
- [ ] `end_day()`: stop spawn timer, freeze all patience drains, auto-save before any UI shown

**Task 3.2 — EconomyManager Full Implementation**
- [ ] `process_payment(sloppy_count)`:
  - Always credit `EconomyConfig.taco_base_price`
  - Credit tip based on sloppy_count: 0 → tip_perfect, 1 → tip_one_sloppy, 2+ → 0
  - Emit `EventBus.balance_changed`
- [ ] `debit(amount)`: `balance = max(0.0, balance - amount)`, emit `balance_changed`
- [ ] `BankBalanceLabel`: connect `EventBus.balance_changed` → update text + flash green (credit) or red (debit) via `Tween`
- [ ] Bail-out logic: checked in `GameManager.start_day()`. If previous day ended at $0 and current day > 0: spawn RegularCustomer cutscene that hands +$2.00 before clock starts.

**Task 3.3 — End-of-Day Screen**
- [ ] `EndOfDayScreen.tscn`: full-screen `CanvasLayer` with animated count-up labels
- [ ] Connect `EventBus.day_ended` → `EndOfDayScreen.show()`
- [ ] `show()` sequence: money count-up (`Tween`), orders tally, tips tally, then reveal upgrade shop section
- [ ] Upgrade shop items greyed out (`modulate.a = 0.4`) if `EconomyManager.balance < upgrade.cost`
- [ ] `[Next Day]` button: `GameManager.start_day(current_day + 1)`, hide `EndOfDayScreen`, reset day stats
- [ ] `[Save & Exit]`: save then `CogitoSceneManager` transition to `MainMenu.tscn`

**Task 3.4 — Upgrade Shop**
- [ ] `UpgradeShop.gd` reads `UpgradeData.tres` resources from `_src/data/upgrades/`
- [ ] On purchase: debit cost, add upgrade_id to `purchased_upgrades` array, emit `EventBus.upgrade_purchased`
- [ ] `InteractionStateMachine` or stations check `UpgradeManager.has_upgrade("sharper_knife")` to apply modifier
  - Sharper Knife: mash fill rate per press `0.20 → 0.35`
  - Better Sauce Bottle: green zone `[0.45–0.75] → [0.35–0.85]`
- [ ] One-time purchase: grey out and disable button after purchase

**Task 3.5 — Save/Load System**
- [ ] Implement `SaveManager.gd` (autoload or static)
- [ ] Auto-save call in `GameManager.end_day()` before `EndOfDayScreen.show()`
- [ ] `MainMenu.gd`: on `_ready()`, call `SaveManager.load_save()`. If save exists: show `[Continue]`. If not: show `[New Game]`.
- [ ] `[Continue]` loads save, sets `GameManager.current_day` and `EconomyManager.balance`, then transitions to `TruckInterior.tscn`
- [ ] Validate save JSON on load: if malformed, delete and treat as new game (no crash)

---

### PHASE 4 — Tutorial, Audio & Final QA (Week 3)

**Task 4.1 — Day 0 Tutorial**
- [ ] Add `TutorialManager.gd` to `TruckInterior.tscn` (active only when `GameManager.current_day == 0`)
- [ ] Override `QueueManager` in tutorial mode: disable spawn timer, manually push scripted `OrderData` objects
- [ ] Disable patience drain on all tutorial customers (`customer.patience_max = INF`)
- [ ] World-space prompt system: `WorldPrompt.tscn` = `Arrow3D + Label3D` positioned above each station
  - Show the correct prompt based on current tutorial step and required next action
  - Connect `EventBus.order_step_completed` → `TutorialManager.on_step_complete()` → advance + hide prompt
- [ ] On tutorial complete (after order 5): show transition screen (`Label` full-screen, "The truck is ready...") with `[Open for Business]` button → `GameManager.start_day(1)`
- [ ] Tutorial state is saved: if `current_day >= 1` in save file, skip Day 0 entirely

**Task 4.2 — Audio Integration**
- [ ] Use existing COGITO `Audio` autoload bus structure
- [ ] SFX triggers (all fire **after** visual state is confirmed):
  - Mash press: `Audio.play_sfx("mash_scrape")`
  - Sauce hold green: looping `Audio.play_sfx("sauce_hiss")`; stop on release
  - Sauce release green: `Audio.play_sfx("sauce_squirt_perfect")`
  - Sauce release red: `Audio.play_sfx("sauce_splatter")`
  - Topping hit: `Audio.play_sfx("topping_thud")`
  - Topping miss: `Audio.play_sfx("topping_drop")`
  - Bell ring: `Audio.play_sfx("bell_ding")`
  - Order complete: `Audio.play_sfx("register_chime")`
  - Order rejected: `Audio.play_sfx("buzzer")`
  - Customer leave: `Audio.play_sfx("door_slam")`
- [ ] Gameplay music: `AudioStreamPlayer` on `TruckInterior` with looping lo-fi track (OGG)
- [ ] Cozy-uncanny effects (low-cost, high ROI):
  - Light flicker: `AnimationPlayer` on `OmniLight3D`; 1-frame dim every 60 seconds
  - Radio reversed speech: `AudioStreamPlayer` on `Environment` node; plays 3-second reversed clip at random interval 120–300 seconds

**Task 4.3 — Asset Swap & Visual Polish**
- [ ] Replace placeholder boxes with Kenney low-poly models where available
- [ ] Remaining placeholders: keep `MeshInstance3D` with `SpatialMaterial` colours matching GDD colour logic:
  - Truck interior: warm amber (`#C8874A`)
  - Counter surface: cream (`#F5E6C8`)
  - Interaction feedback: green `#4CAF50`, orange `#FF9800`, red `#F44336`
- [ ] Set all textures to `Filter: Nearest` (point filtering) in import settings
- [ ] No bloom, no SSAO (verify `Environment` resource has all effects disabled)

**Task 4.4 — Final Web QA Pass**
- [ ] Export web build: `Project > Export > Web`
- [ ] Host locally with Python: `python -m http.server 8080`, open `localhost:8080`
- [ ] **Chrome QA checklist:**
  - [ ] Shrinking circle feels fair 80%+ of the time for a new player
  - [ ] No frame drops below 55 FPS during 3-customer queue peak
  - [ ] Sauce gauge zones clearly visible before interaction begins
  - [ ] Bell confirmation popup dismisses cleanly with NO and YES paths
  - [ ] Save/load round-trip works after tab close and reopen
  - [ ] Balance never goes below $0 under any scenario
  - [ ] End-of-day screen auto-saves before any button is pressed
- [ ] **Firefox QA checklist:**
  - [ ] All above items verified
  - [ ] No audio glitches on sauce hiss loop start/stop
- [ ] Memory leak check: open Chrome DevTools → Memory → Heap snapshot before Day 1 and after Day 3. Total heap growth < 20 MB.
- [ ] Confirm `Thread support: Off` in export settings (required for itch.io / no SharedArrayBuffer)

---

## 6. Full Signal Connection Reference

```
# Boot flow
GameManager.start_day() ──────────────────────────────→ QueueManager.configure(day_config)
GameManager.start_day() ──────────────────────────────→ EconomyManager.reset_day_stats()
GameManager.day_started (EventBus) ───────────────────→ GameHUD.show_timer()

# Order flow
Customer.clicked (raycast) ───────────────────────────→ OrderManager.accept_order(customer)
OrderManager.accept_order() ──────────────────────────→ EventBus.order_accepted
EventBus.order_accepted ──────────────────────────────→ OrderPanel.build_pills(order)
EventBus.order_accepted ──────────────────────────────→ Customer.show_waiting_indicator()

# Cooking flow
InteractionStateMachine.interaction_complete ─────────→ TruckStation.on_interaction_complete(result)
TruckStation.on_interaction_complete ─────────────────→ OrderManager.complete_step(id, quality)
OrderManager.complete_step() ─────────────────────────→ EventBus.order_step_completed(id, quality)
EventBus.order_step_completed ────────────────────────→ OrderPanel.update_pill(id, state)

# Serve flow
BellStation.on_interaction_complete ──────────────────→ OrderManager.validate_order()
OrderManager (complete) ──────────────────────────────→ EconomyManager.process_payment(sloppy_count)
EconomyManager.process_payment() ─────────────────────→ EventBus.order_completed(payment, tip)
EventBus.order_completed ─────────────────────────────→ OrderPanel.clear()
EventBus.order_completed ─────────────────────────────→ QueueManager.shift_queue()
EventBus.order_completed ─────────────────────────────→ NodePool.ret(all food items)

OrderManager (incomplete) ────────────────────────────→ BellConfirmationPopup.show(missing_ids)
BellConfirmationPopup.confirmed_yes ──────────────────→ EconomyManager.deduct_food_cost(ingredients)
EconomyManager.deduct_food_cost() ────────────────────→ EventBus.order_rejected(food_cost)
EventBus.order_rejected ──────────────────────────────→ Customer.leave_rejected()

# Economy flow
EconomyManager.credit/debit ──────────────────────────→ EventBus.balance_changed(new_balance, delta)
EventBus.balance_changed ─────────────────────────────→ BankBalanceLabel.update_and_flash(delta)

# Day end flow
GameManager.day_timer <= 0 ───────────────────────────→ GameManager.end_day()
GameManager.end_day() ────────────────────────────────→ SaveManager.save(build_save_dict())
GameManager.end_day() ────────────────────────────────→ EventBus.day_ended(day_number)
EventBus.day_ended ───────────────────────────────────→ EndOfDayScreen.show(tally)
EndOfDayScreen.[Next Day] ────────────────────────────→ GameManager.start_day(current_day + 1)

# Patience flow
Customer._physics_process ────────────────────────────→ PatienceArc.update(ratio)
Customer.patience_expired ────────────────────────────→ QueueManager.on_customer_patience_expired()
QueueManager.on_customer_patience_expired() ──────────→ EconomyManager.debit(penalty_patience)
QueueManager.on_customer_patience_expired() ──────────→ EventBus.customer_left(penalty)
QueueManager.on_customer_patience_expired() ──────────→ Customer.leave_angry()
Customer.leave_angry() ───────────────────────────────→ [animation] → NodePool.ret(customer)

# Pool flow
NodePool.checkout() ──────────────────────────────────→ Node.show() + reset state
NodePool.ret() ───────────────────────────────────────→ Node.hide() + reset state
```

---

## 7. COGITO Framework Conflict Avoidance

The following COGITO systems are **explicitly disabled or bypassed** to prevent conflicts:

| COGITO Feature | Action Required |
|---|---|
| `cogito_player.gd` FPS controller | Do NOT use. `TruckPlayer.gd` is a custom `CharacterBody3D`-based FPS controller with WASD movement, unclamped yaw (360°), and pitch-clamped Camera3D. Does not inherit COGITO player. |
| `InventoryPD` grid inventory | Do NOT use. Held item is a simple variable in `InteractionStateMachine`. |
| `CogitoNPC` NavigationAgent enemies | Do NOT use. Customers use custom `Customer.gd` with no NavMesh. |
| `CogitoQuestManager` | Do NOT use. `OrderManager` replaces this entirely. |
| COGITO Main Menu scene | Replace: set `run/main_scene` to `res://_src/levels/MainMenu.tscn` in `project.godot`. |
| COGITO Wieldables | Do NOT use. No held weapons. |
| COGITO Interaction Components | Do NOT use. Custom `TruckStation.gd` base class replaces these. |
| Forward Plus renderer | Already overridden to `gl_compatibility` in project.godot — keep it. |
| COGITO HUD (`Player_HUD.tscn`) | Do NOT instantiate. `GameHUD.tscn` is entirely custom. |

**COGITO systems retained:**
- `Audio` autoload (bus routing)
- `CogitoSceneManager` (scene transitions with fade)
- `MenuTemplateManager` (settings overlay)
- Jolt Physics configuration
- `shader_library` addon (if custom shaders needed post-prototype)

---

## 8. Prototype Completion Definition

The prototype is **shippable** when all of the following are true:

| Criterion | Verification |
|---|---|
| All 4 cooking interactions functional | Play through 5 orders without any interaction breaking |
| Player can reach all stations by walking front/back | Walk to back counter: interact with Tortilla and Trompo. Turn around, walk to front: interact with Sauces, Toppings, and Bell. Verify no station is unreachable. |
| Customer queue spawns and drains correctly | Day 1 runs for 5 minutes with no null reference errors |
| Economy tracks correctly across a full day | End-of-day balance matches manual calculation from order log |
| Bell validation and confirmation popup work | Intentionally serve incomplete order; verify popup and rejection |
| Day 0 tutorial completes all 5 scripted orders | Play tutorial start-to-finish; all prompts show and hide correctly |
| Upgrade shop purchases persist to next day | Buy Sharper Knife; verify mash speed changes next day |
| Save/load round-trip works | Close tab mid-session; reopen; verify correct day and balance load |
| 60 FPS on target hardware | Chrome DevTools Performance panel; no drops below 55 FPS |
| Memory stable across 3 days | Heap snapshot delta < 20 MB from Day 1 start to Day 3 end |
| Web audio functions without blocking | All SFX trigger correctly; no promises rejected in console |
