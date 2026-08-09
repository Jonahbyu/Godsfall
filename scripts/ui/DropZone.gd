class_name DropZone
extends Button

## A Button that also accepts drag-and-drop, with the accept test and the drop
## action supplied as callables. Combat builds its board fresh on every refresh,
## so wiring drops per widget is simpler than subclassing one per target type.
##
##   var z := DropZone.new()
##   z.can_drop = func(data): return _is_basic_payload(data)
##   z.on_drop  = func(data): _deploy_from_drag(data, bi, si)

## func(data: Variant) -> bool
var can_drop: Callable = Callable()
## func(data: Variant) -> void
var on_drop: Callable = Callable()

## Set while a compatible payload hovers this zone, so the widget can show it.
var hovered: bool = false

signal drop_hover_changed(hovering: bool)


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	var ok: bool = can_drop.is_valid() and bool(can_drop.call(data))
	if ok != hovered:
		hovered = ok
		drop_hover_changed.emit(ok)
		queue_redraw()
	return ok


func _drop_data(_at: Vector2, data: Variant) -> void:
	hovered = false
	if on_drop.is_valid():
		on_drop.call(data)


## Godot gives no "drag left this control" callback, so clear the hover flag
## when the pointer exits or the drag ends elsewhere.
func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT or what == NOTIFICATION_DRAG_END:
		if hovered:
			hovered = false
			drop_hover_changed.emit(false)
			queue_redraw()


## A bright inset ring while a valid card hovers — clearer than a border colour
## swap, since the button already uses its border for playability.
func _draw() -> void:
	if not hovered:
		return
	draw_rect(Rect2(Vector2.ONE * 2, size - Vector2.ONE * 4), Palette.ACCENT, false, 3.0)
