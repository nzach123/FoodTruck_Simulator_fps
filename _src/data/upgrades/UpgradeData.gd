## UpgradeData.gd
## Resource describing a single purchasable upgrade in the end-of-day shop.
##
## Each upgrade is stored as a separate .tres file under _src/data/upgrades/.
## UpgradeShop.gd reads all .tres files in that directory at runtime.
##
## The modifier dictionary is interpreted by the relevant system:
##   - "mash_fill_bonus" → read by InteractionStateMachine._tick_mash()
##   - "sauce_zone_expand" → read by SauceStation.on_interaction_tick()
##
## Path: res://_src/data/upgrades/UpgradeData.gd

class_name UpgradeData
extends Resource

## Unique string ID. Referenced in EventBus.upgrade_purchased and save data.
## Use snake_case. Example: "sharper_knife", "better_sauce_bottle"
@export var upgrade_id: String = ""

## Human-readable name shown in the upgrade shop UI.
@export var display_name: String = ""

## Cost in dollars to purchase. Greyed out if EconomyManager.balance < cost.
@export var cost: float = 25.0

## Short description shown in the shop tooltip / card body.
@export var description: String = ""

## Modifier dictionary interpreted by the relevant gameplay system.
## Keys are system-specific; see SYSTEMS.md for the full modifier registry.
## Example for Sharper Knife: { "mash_fill_bonus": 0.15 }
@export var modifier: Dictionary = {}

## If true, this upgrade can only be purchased once per run.
## The shop greys it out permanently after purchase.
@export var is_one_time_purchase: bool = true
