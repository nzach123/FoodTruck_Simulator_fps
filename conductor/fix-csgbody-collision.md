# Fix CSGBody Raycast Blocking

## Objective
Fix an issue where the invisible `CSGBody` geometry in `TruckInterior.tscn` is blocking the player's `InteractionRaycast`, preventing them from interacting with the `TortillaStation` (and future back stations).

## Changes
1. **File to Modify:** `res://_src/levels/TruckInterior.tscn`
2. **Action:** Locate the `CSGBody` node (a `CSGCombiner3D` inside `CSGGeo`).
3. **Change:** Change `use_collision = true` to `use_collision = false`. 
   *This node is currently `visible = false` and `operation = 2` (subtraction), likely an old placeholder or boolean shape for the truck shell. Disabling its collision will allow the raycast to pass through its invisible faces and hit the `StaticBody3D` hitboxes of the stations behind it.*

## Verification
- Run `TruckInterior.tscn`.
- Walk to the Tortilla Station.
- Confirm the crosshair changes to the active state when hovering over the Tortilla Station's hitbox, and the console logs `ISM: Raycast hitting: Hitbox` instead of `CSGBody`.