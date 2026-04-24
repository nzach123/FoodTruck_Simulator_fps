## EventBus.gd
## Global signal router for all cross-system communication in Midnight Munch.
##
## ARCHITECTURE RULE: "Signal Up, Call Down"
##   - Systems EMIT signals here to announce events.
##   - Listeners CONNECT to these signals to react.
##   - No direct sibling-to-sibling connections. All cross-system
##     messages flow through this single bus.
##
## USAGE:
##   Emit:   EventBus.order_completed.emit(payment, tip)
##   Listen: EventBus.order_completed.connect(_on_order_completed)
##
## Registered in: Project Settings > Autoloads > EventBus
## Path: res://_src/autoloads/EventBus.gd

extends Node

# ─────────────────────────────────────────────────────────────────────────────
# ORDER LIFECYCLE SIGNALS
# ─────────────────────────────────────────────────────────────────────────────

## Emitted by OrderManager when the player clicks on a waiting customer.
## Listeners: OrderPanel (build pills), Customer (show waiting indicator)
signal order_accepted(customer: Node)

## Emitted by OrderManager each time a cooking step is finished.
## quality: IngredientState enum value (PERFECT = 2, SLOPPY = 3)
## Listeners: OrderPanel (update pill colour/icon)
signal order_step_completed(ingredient_id: String, quality: int)

## Emitted by EconomyManager after a successful bell-ring and payment.
## Listeners: OrderPanel (clear), QueueManager (shift queue), NodePool (return food)
signal order_completed(payment: float, tip: float)

## Emitted by EconomyManager when the player force-serves an incomplete order.
## food_cost is the ingredient cost already deducted from the balance.
## Listeners: Customer (leave_rejected animation), OrderPanel (clear)
signal order_rejected(food_cost: float)

# ─────────────────────────────────────────────────────────────────────────────
# CUSTOMER SIGNALS
# ─────────────────────────────────────────────────────────────────────────────

## Emitted by QueueManager when a customer's patience runs out and they leave.
## penalty is the amount already debited from EconomyManager.
## Listeners: PenaltyTicker (show "-$X.XX" float text), HUD
signal customer_left(penalty: float)

# ─────────────────────────────────────────────────────────────────────────────
# ECONOMY SIGNALS
# ─────────────────────────────────────────────────────────────────────────────

## Emitted by EconomyManager on every credit or debit operation.
## delta > 0 = credit (flash green), delta < 0 = debit (flash red).
## Listeners: BankBalanceLabel (update + colour flash)
signal balance_changed(new_balance: float, delta: float)

# ─────────────────────────────────────────────────────────────────────────────
# DAY / GAME STATE SIGNALS
# ─────────────────────────────────────────────────────────────────────────────

## Emitted by GameManager at the start of each in-game day (including Day 0 tutorial).
## Listeners: QueueManager (configure), GameHUD (show timer), TutorialManager
signal day_started(day_number: int)

## Emitted by GameManager when the 5-minute countdown reaches zero.
## Triggers auto-save before EndOfDayScreen is shown.
## Listeners: EndOfDayScreen (show tally), QueueManager (stop spawning)
signal day_ended(day_number: int)

# ─────────────────────────────────────────────────────────────────────────────
# PROGRESSION SIGNALS
# ─────────────────────────────────────────────────────────────────────────────

## Emitted by UpgradeShop when the player successfully buys an upgrade.
## Listeners: InteractionStateMachine / stations (apply modifier)
signal upgrade_purchased(upgrade_id: String)

# ─────────────────────────────────────────────────────────────────────────────
# TUTORIAL SIGNALS
# ─────────────────────────────────────────────────────────────────────────────

## Emitted by TutorialManager when the player completes a scripted tutorial step.
## Listeners: TutorialManager (show next prompt/arrow), HUD
signal tutorial_step_advanced(step_index: int)
