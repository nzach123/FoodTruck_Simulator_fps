# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Food-Truck-Sim-FPS is a Godot 4.6 project built on the **COGITO Framework** (v1.1), a first-person immersive sim template. The game uses Forward Plus rendering with Jolt Physics.

## Development Commands

```bash
# Run the project (from Godot editor or command line)
godot --path . --editor          # Open in editor
godot --path .                   # Run main scene

# Run GUT tests (from Godot editor)
# Use the GUT panel in the editor, or:
godot --path . -s addons/gut/gut_cmdln.gd

# Linting
# GDScript linter is available as an editor plugin
```

## Architecture

### Core Framework: COGITO

All game logic extends the COGITO framework located in `addons/cogito/`. Key subsystems:

- **Player System** (`addons/cogito/CogitoObjects/cogito_player.gd`) - FPS controller with sprinting, crouching, sliding, ladders, fall damage, footsteps
- **Interaction System** (`addons/cogito/Components/Interactions/`) - Component-based interactions (pickup, carry, hold, lock, readable, etc.)
- **Inventory System** (`addons/cogito/InventoryPD/`) - Grid-based RE4-style inventory with quick slots
- **Attribute System** (`addons/cogito/Components/Attributes/`) - Health, Stamina, Visibility (stealth), Sanity, custom attributes
- **Wieldables** (`addons/cogito/Wieldables/`) - Weapons, flashlights, throwables, consumables
- **NPC System** (`addons/cogito/CogitoNPC/`) - NavigationAgent-based enemies with state machine
- **Quest System** (`addons/cogito/QuestSystem/`) - Quest resources and tracking
- **Scene Management** (`addons/cogito/SceneManagement/`) - Transitions, persistence, state management

### Autoloads (Global Singletons)

- `Audio` - Audio management
- `InputHelper` - Input processing
- `CogitoGlobals` - Game state
- `CogitoSceneManager` - Scene loading/transitions
- `CogitoQuestManager` - Quest tracking
- `MenuTemplateManager` - Menu UI
- `PhantomCameraManager` - Camera system

### Plugin Dependencies

Located in `addons/`:
- `cogito` - Core framework
- `gut` - Unit testing
- `gdscript-linter` - Code analysis
- `input_helper` - Input abstraction
- `phantom_camera` - Camera system
- `quick_audio` - Audio utilities
- `shader_library` - Shader organization

### Physics Layers

1. Environment
2. Interactables

## Key Patterns

- **Component-Based**: Objects use interaction/attribute components rather than inheritance
- **Signal-Driven**: Loose coupling via Godot signals
- **Resource-Based**: Game data stored as `.tres` files (items, quests, inventories)
- **Export Variables**: Extensive `@export` usage for editor configuration
- **Group Filtering**: Objects categorized via Godot groups

## Demo Scenes

Entry point: `addons/cogito/DemoScenes/COGITO_0_MainMenu.tscn`

Demo levels showcase framework features:
- `COGITO_3_Lobby.tscn` - Tutorial lobby
- `COGITO_4_Laboratory.tscn` - Advanced mechanics

Prefabs available in `addons/cogito/PackedScenes/` for doors, containers, interactables.

## Resources

- [COGITO Online Documentation](https://cogito.readthedocs.io/)
- [Video Tutorials](https://cogito.readthedocs.io/en/latest/tutorials.html)
- Local docs in `docs/` folder (Sphinx RST format)
