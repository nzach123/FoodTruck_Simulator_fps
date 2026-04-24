# Systems Architecture

Technical implementation tracking for Midnight Munch.

---

## Planned Systems (from GDD)

### EventBus
**Status:** Planned
**Files:** `scripts/autoloads/EventBus.gd`
**Dependencies:** None (foundational)

#### Overview
Global signal bus for cross-system communication.

#### Signals
- `order_accepted` — Player accepts a customer order
- `order_completed` — Order successfully served
- `order_rejected` — Customer rejects incomplete order
- `day_ended` — 5-minute timer expires
- `upgrade_purchased` — Player buys upgrade
- `balance_changed` — Bank balance modified

---

### GameManager
**Status:** Planned
**Files:** `scripts/autoloads/GameManager.gd`
**Dependencies:** EventBus

#### Overview
Day state machine controlling game phases.

#### States
- `TUTORIAL` — Day 0, scripted sequence
- `PLAYING` — Active gameplay, timer running
- `END_OF_DAY` — Results screen, upgrade shop

---

### EconomyManager
**Status:** Planned
**Files:** `scripts/autoloads/EconomyManager.gd`
**Dependencies:** EventBus

#### Overview
Handles all monetary transactions.

#### Key Features
- Bank balance tracking
- $0 floor enforcement
- Tip calculation (0/1/2+ sloppy flags)
- Food cost deduction on rejection

---

### NodePool
**Status:** Planned
**Files:** `scripts/autoloads/NodePool.gd`
**Dependencies:** None

#### Overview
Object pooling for all recyclable game objects.

#### Pool Sizes (per GDD)
- Tortilla nodes: 10
- Shaved meat portions: 20
- Sauce stream particles: 50
- Topping items (per type): 15
- Customer NPC nodes: 5

---

### Input State Machine
**Status:** Planned
**Files:** `scripts/input/InputStateMachine.gd`
**Dependencies:** Station components

#### Overview
Central input handler with context-aware state.

#### States
```
IDLE → HOVER → ACTIVE → [MASH|HOLD|TIMING|INSTANT]_INTERACTION
```

---

## Implemented Systems

*No systems implemented yet. Development begins with TASK-001.*
