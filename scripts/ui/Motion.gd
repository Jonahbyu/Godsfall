class_name Motion
extends RefCounted

## Shared motion vocabulary.
##
## One file so that every animation in the game shares a timing language: the
## same durations, the same easing curves, the same idea of what "fast" means.
## Motion assembled ad hoc per call site is the thing that makes an interface
## feel homemade — two panels that fade at 0.15s and 0.4s read as two different
## products, and nobody can say why.
##
## The durations below are deliberately short. This is a turn-based game, so
## nothing here is a cutscene: an animation exists to tell you *that* something
## changed and *where*, then get out of the way. Anything a player waits on
## becomes an annoyance by the fiftieth turn.
##
## ## Why everything is guarded
##
## Every function here no-ops when handed a freed or null node, and every one
## checks it is inside a tree before tweening. The combat screen rebuilds its
## whole board on each state change, so a node being animated can be freed
## mid-tween by an unrelated refresh — that is normal here, not an error, and
## it must never raise.
##
## ## Headless safety
##
## The harnesses build every screen with no rendering server. Tweens are safe
## there (unlike GradientTexture2D — see `Palette.lit_style`), but a tween on a
## node outside the tree throws, so `_ready(n)` gates every entry point.

## Timing, in seconds. Named by intent rather than by number so a call site
## reads as a decision instead of as a magic constant.
const FAST   := 0.09    ## tracking a pointer; must feel instant
const QUICK  := 0.16    ## a state change you should notice but not wait for
const NORMAL := 0.26    ## something arriving or leaving
const SLOW   := 0.42    ## a deliberate, once-per-turn beat

## How far a damage flash pushes toward white, and how far a card scales when it
## pops. Both are small on purpose: the eye catches a 6% scale change reliably,
## and anything past ~12% reads as the layout breaking rather than as emphasis.
const FLASH_STRENGTH := 0.55
const POP_SCALE      := 1.06


## Whether `n` can safely be animated right now.
static func _ready_node(n: Node) -> bool:
	return n != null and is_instance_valid(n) and n.is_inside_tree()


## Fade a node in from nothing. Used for anything that *arrives* — a card dealt,
## a panel opening, a log line appended.
static func fade_in(n: CanvasItem, dur: float = NORMAL) -> void:
	if not _ready_node(n):
		return
	n.modulate.a = 0.0
	var tw := n.create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(n, "modulate:a", 1.0, dur)


## Flash a node toward a colour and back — the workhorse for "this just changed".
##
## Returns to `Color.WHITE` rather than to whatever the modulate was, because a
## flash interrupted by a rebuild would otherwise strand the node tinted. White
## is the identity for `modulate`, so the failure mode is "no tint", never "stuck
## red".
static func flash(n: CanvasItem, col: Color, dur: float = QUICK) -> void:
	if not _ready_node(n):
		return
	var tint := Color.WHITE.lerp(col, FLASH_STRENGTH)
	n.modulate = tint
	var tw := n.create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(n, "modulate", Color.WHITE, dur)


## A short scale pulse, anchored at the node's centre.
##
## `pivot_offset` is set to the node's centre first: scaling a Control from its
## default top-left pivot makes it lunge down-right instead of swelling in
## place, which reads as a glitch rather than as emphasis.
static func pop(n: Control, amount: float = POP_SCALE, dur: float = QUICK) -> void:
	if not _ready_node(n):
		return
	n.pivot_offset = n.size * 0.5
	n.scale = Vector2.ONE * amount
	var tw := n.create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(n, "scale", Vector2.ONE, dur)


## A damage impact: flash red, and shake briefly.
##
## The shake is horizontal only and tiny. Vertical or rotational shake on a card
## in a grid reads as the layout coming apart, because neighbouring cards stay
## put; a horizontal jitter reads as a hit absorbed.
static func hit(n: Control, dur: float = QUICK) -> void:
	if not _ready_node(n):
		return
	flash(n, Color(1.0, 0.35, 0.35), dur)
	var x := n.position.x
	var tw := n.create_tween()
	tw.set_trans(Tween.TRANS_SINE)
	tw.tween_property(n, "position:x", x - 3.0, dur * 0.25)
	tw.tween_property(n, "position:x", x + 3.0, dur * 0.35)
	tw.tween_property(n, "position:x", x, dur * 0.4)


## A heal or a gain: flash green and swell slightly.
static func mend(n: Control, dur: float = QUICK) -> void:
	if not _ready_node(n):
		return
	flash(n, Color(0.45, 1.0, 0.55), dur * 1.4)
	pop(n, 1.04, dur * 1.4)


## A unit dying: desaturate, sink, and fade.
##
## Deliberately the slowest thing in the file. A death changes what every later
## attack in the volley hits, so it is the one board event a player genuinely
## needs a beat to register.
static func perish(n: Control, dur: float = SLOW) -> void:
	if not _ready_node(n):
		return
	var tw := n.create_tween()
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(n, "modulate", Color(0.4, 0.35, 0.4, 0.0), dur)
	tw.tween_property(n, "position:y", n.position.y + 10.0, dur)


## Depress a node under the pointer, and release it.
##
## Scale rather than position, and a very small amount of it: 2% reads clearly as
## "this responded" while leaving the card legible and its neighbours undisturbed.
## Moving the card instead would fight the hand's hover-lift, which already owns
## the vertical axis.
##
## The release is eased with BACK so it overshoots a hair on the way home, which
## is what makes it feel sprung rather than merely animated.
static func press(n: Control, down: bool) -> void:
	if not _ready_node(n):
		return
	n.pivot_offset = n.size * 0.5
	var tw := n.create_tween()
	if down:
		tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(n, "scale", Vector2.ONE * 0.98, FAST)
	else:
		tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(n, "scale", Vector2.ONE, QUICK)


## Slide a node in from an edge. `from` is a pixel offset applied at the start.
static func slide_in(n: Control, from: Vector2, dur: float = NORMAL) -> void:
	if not _ready_node(n):
		return
	var dest := n.position
	n.position = dest + from
	n.modulate.a = 0.0
	var tw := n.create_tween()
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(n, "position", dest, dur)
	tw.tween_property(n, "modulate:a", 1.0, dur * 0.8)


## A slow, looping breath on a node that wants attention without nagging — the
## tutorial's highlighted widget, a lesson's target slot.
##
## Returns the tween so a caller can kill it; a looping tween is the one kind
## that must be stopped explicitly rather than left to finish.
static func pulse(n: CanvasItem, col: Color, period: float = 1.1) -> Tween:
	if not _ready_node(n):
		return null
	var tw := n.create_tween()
	tw.set_loops()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(n, "modulate", Color.WHITE.lerp(col, 0.28), period * 0.5)
	tw.tween_property(n, "modulate", Color.WHITE, period * 0.5)
	return tw
