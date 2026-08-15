class_name DragScroll
extends ScrollContainer

## A ScrollContainer you can also scroll by dragging across its contents.
##
## ## Why this is not just `ScrollContainer` with touch dragging on
##
## Godot's built-in `ScrollContainer` does have a touch-drag mode, but it is
## unusable here: the hand's cards are themselves draggable — dragging one onto
## the board is how you deploy, evolve and charge — and a card claims the press
## first. Turning on the engine's pan would mean every attempt to swipe the hand
## picked up whichever card the finger landed on.
##
## ## How the conflict is resolved: by direction, not by timing
##
## The two gestures are physically different, so the axis distinguishes them
## cleanly:
##
##     horizontal movement  ->  scroll the hand
##     vertical movement    ->  the card is being pulled out to play
##
## That mapping is not arbitrary. The hand is a horizontal strip, so sideways is
## the only direction it *can* scroll; and every card destination — a board slot,
## a unit to charge — is above the hand, so playing a card is always an upward
## pull. Neither gesture wants the other's axis.
##
## The alternative — a hold-then-drag delay — was rejected because it taxes the
## common case: it makes every card drag wait, and a scroll that only starts
## after a pause feels broken rather than deliberate.
##
## ## Why input is intercepted here rather than on the cards
##
## `_gui_input` on this node runs before the children see the event only if this
## node stops it, which it must not do unconditionally — a plain tap has to reach
## the card underneath or nothing would be clickable. So the decision is made on
## motion: the press is watched, and the drag is only claimed once the pointer
## has moved far enough horizontally to prove intent. Until then the event is
## left alone and the card behaves exactly as before.

## How far the pointer must travel before a press counts as a scroll rather than
## a tap. Below Godot's own drag threshold, so the scroll is claimed before a
## card drag would start — otherwise the card wins every time and this does
## nothing.
const CLAIM_DISTANCE := 8.0

## How much more horizontal than vertical the movement must be to read as a
## scroll. 1.0 would make a 45-degree drag ambiguous and flip on noise; requiring
## a clear majority means a diagonal pull toward the board still plays the card.
const AXIS_RATIO := 1.4

var _pressed := false
var _claimed := false
var _start := Vector2.ZERO
var _start_scroll := 0


func _init() -> void:
	## The hand is a strip: it scrolls sideways and must never scroll vertically,
	## which would let the cards drift out of their row.
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressed = true
			_claimed = false
			_start = event.position
			_start_scroll = scroll_horizontal
		else:
			## A claimed drag ends here and must not also register as a click on
			## the card underneath, or letting go after a swipe would select it.
			if _claimed:
				accept_event()
			_pressed = false
			_claimed = false

	elif event is InputEventMouseMotion and _pressed:
		var delta: Vector2 = event.position - _start
		if not _claimed:
			## Claim only on a clearly horizontal movement past the threshold.
			## A vertical pull is a card being played and is left entirely alone.
			if absf(delta.x) >= CLAIM_DISTANCE \
					and absf(delta.x) > absf(delta.y) * AXIS_RATIO:
				_claimed = true
		if _claimed:
			scroll_horizontal = _start_scroll - int(delta.x)
			accept_event()
