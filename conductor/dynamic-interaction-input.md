# Dynamic Interaction Input Plan

## Objective
Update the `InteractionStateMachine` to dynamically use the appropriate input action defined by the currently focused `TruckStation`, instead of hardcoding a single action for all interactions.

## Senior Developer Review Notes incorporated:
- **StringName over String**: We will use `StringName` for `interact_action` as it's the standard for input mapping checks in Godot 4, offering slight performance benefits and better type safety.
- **Unified Action for MASH**: Currently, Trompo might start with "E" but mash with "mm_mash" (Left Click/F). We will unify this so the MASH state also listens to the station's `interact_action` (e.g., repeatedly pressing "E").

## Key Files & Context
- **`_src/interactables/base/TruckStation.gd`**: The base class for all stations. Needs a new exported property to define the interaction input map action.
- **`_src/player/InteractionStateMachine.gd`**: The state machine handling input. Needs to dynamically check the `active_station`'s defined input action.
- **Station Scene Files (`*.tscn`)**: Need to configure both the new `interact_action` property on the root node and the `input_map_action` on their COGITO `BasicInteraction` component to ensure the HUD prompt matches the required input.

## Implementation Steps

1.  **Update Base Class (`TruckStation.gd`)**:
    *   Add a new exported variable: `@export var interact_action: StringName = &"interact"`
    *   This provides a default (F key) and allows each station instance/subclass to override it in the inspector.

2.  **Update State Machine (`InteractionStateMachine.gd`)**:
    *   Modify the `_input(event: InputEvent)` function.
    *   Retrieve the action from `active_station` to use dynamically:
        ```gdscript
        var action: StringName = active_station.interact_action if active_station != null else &""
        ```
    *   Update the state checks to use this dynamic `action` instead of hardcoded strings:
        *   **HOVER**: `if event.is_action_pressed(action):`
        *   **MASH**: `if event.is_action_pressed(action):` (replaces `"mm_mash"`)
        *   **HOLD**: `if event.is_action_released(action):`
        *   **TIMING**: `if event.is_action_pressed(action):`

3.  **Configure Station Scenes (`.tscn` files)**:
    *   Update the root `TruckStation` node to set the new `interact_action` property if it differs from the default `&"interact"`.
    *   Ensure the `input_map_action` property on the `BasicInteraction` child node matches the root's `interact_action` (as a String) so the UI prompt displays the correct key binding.

    **Specific Station Configurations**:
    *   **ToppingStation**: Left Click (`&"mm_interact"`)
    *   **SauceStation**: F (`&"interact"`) - *Note: This will revert the recent incorrect change.*
    *   **TortillaStation**: E (`&"interact2"`)
    *   **TrompoStation**: E (`&"interact2"`)
    *   **BellStation**: F (`&"interact"`)

## Verification & Testing
1.  Play the game and approach the **Sauce Station**. Verify the HUD prompts "F" and pressing "F" starts the hold interaction.
2.  Approach the **Topping Station**. Verify the HUD prompts Left Click and clicking starts the timing circle interaction.
3.  Approach the **Tortilla Station**. Verify the HUD prompts "E" and pressing "E" gives a tortilla.
4.  Approach the **Trompo Station**. Verify the HUD prompts "E" and pressing "E" starts the mash interaction, and pressing "E" repeatedly fills the bar.
5.  Verify WASD movement is not affected while interacting.
