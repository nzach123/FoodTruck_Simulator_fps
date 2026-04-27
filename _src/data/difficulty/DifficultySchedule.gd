## DifficultySchedule.gd
## Resource that holds all per-day difficulty configurations for Midnight Munch.
##
## An ordered Array[DayConfig] where index == day number (index 0 = Day 0 / tutorial).
## Stored as DifficultySchedule.tres and loaded by GameManager at boot.
##
## Usage in GameManager._load_difficulty_schedule():
##   var schedule = ResourceLoader.load("res://_src/data/difficulty/DifficultySchedule.tres")
##   _difficulty_schedule = schedule.days
##
## Path: res://_src/data/difficulty/DifficultySchedule.gd

class_name DifficultySchedule
extends Resource

## Ordered list of DayConfig resources. Index matches the day number.
## Day 0 = tutorial; Day 1+ = live service days.
@export var days: Array[DayConfig] = []
