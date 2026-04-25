# Implementation Plan: Topping Station Shrinking Circle (Simplified)

## Objective
Finalise the core logic for the "Place Toppings — Shrinking Circle" interaction according to the GDD, using temporary `print` statements for hit/miss outcomes as requested by the user. Complex feedback (physics props, UI updates, and sounds) is deferred.

## Key Files & Context
- `_src/player/InteractionStateMachine.gd`: Controls the shrinking logic, hit/miss detection, and state flow.
- `_src/ui/ShrinkingCircle.gd`: Visualises the shrinking ring and the static target band.
- `_src/interactables/ToppingStation.gd`: The station data object.

## Implementation Steps

### 1. Integrate Core Feedback (Hit & Miss)
Update `InteractionStateMachine.gd` to log outcomes clearly, and add visual feedback for success:
- **Hit**: In `_evaluate_timing()`, add `print("Hit: Topping placed in taco.")` when the radius falls within `TIMING_TARGET_MIN` and `TIMING_TARGET_MAX`. *Additionally*, emit a signal or call a method to trigger a green flash on the `ShrinkingCircle` UI or a HUD element. 
- **Miss**: In `_on_timing_miss()`, add `print("Miss: Topping drops on floor. -$0.05 deducted.")`. The existing `EconomyManager.debit` logic should remain intact.

### 2. Implement Visual Green Feedback (Hit)
Update `ShrinkingCircle.gd` (or create a dedicated HUD node if preferred) to flash green upon a successful hit before resetting. This provides immediate satisfying visual confirmation to the player.

### 3. Verify Web-Safe Constraints
- Ensure `timing_radius` is only modified inside `_tick_timing(delta)` which is called via `_physics_process`.
- Keep `TIMING_SHRINK_SPEED` at `220.0` (30% slower than native).
- Keep target band between `80.0` and `130.0` (30% wider than native).

### 4. Verify Target Band Visibility
- Ensure `ShrinkingCircle.gd` uses `draw_arc` parameters that match the 80–130 pixel band. (Currently, it draws an arc at radius 105 with a width of 50, which perfectly covers 80 to 130). It is visible from frame 1 as specified.

## Deferred Requirements
*As requested, the following GDD features are excluded from this pass and deferred for later implementation:*
- Dropped topping physics prop (`RigidBody3D`, `NodePool`, 10s recycling).
- Spatial audio for Hit/Miss.
- -$0.05 UI ticker on screen.

## Verification & Testing
1. Interact with a Topping Station (Cilantro, Tomato, or Onion) and watch the shrinking circle.
2. **Test Hit**: Click while the ring is inside the translucent band. Verify `Hit: Topping placed in taco.` prints to the console AND observe the visual green feedback.
3. **Test Miss**: Click while the ring is outside the band (or let it shrink to 0). Verify `Miss: Topping drops on floor. -$0.05 deducted.` prints to the console.
4. **Test Retry**: After a miss, verify the station returns to the `HOVER` state and allows an immediate retry.
