## DayConfig.gd
## Resource that defines difficulty parameters for a single in-game day.
##
## One DayConfig instance per day. Stored as an array inside
## DifficultySchedule.tres and loaded by GameManager at boot.
##
## Values here are sourced from the GDD difficulty schedule table.
## Path: res://_src/data/difficulty/DayConfig.gd

class_name DayConfig
extends Resource

## Which calendar day this config applies to. Day 0 = tutorial.
@export var day: int = 0

## How long (in seconds) before a customer loses patience and leaves.
## Shorter = harder. GDD range: 30–60 seconds across the schedule.
@export var patience_seconds: float = 60.0

## Time (in seconds) between customer spawn events.
## Shorter = more pressure. GDD range: 20–45 seconds.
@export var spawn_interval: float = 45.0

## Maximum customers that can be visible in the queue simultaneously.
## GDD cap: 3 (engine can handle more; game design limits it).
@export var max_concurrent: int = 2

## Optional: override mash presses required to fill the meat bar.
## 0 = use the default from InteractionStateMachine (5 presses base).
@export var mash_presses_required: int = 0

## Whether this day's orders can include optional toppings.
## Day 1 = false (tortilla + meat only); later days enable toppings.
@export var allow_optional_ingredients: bool = false
