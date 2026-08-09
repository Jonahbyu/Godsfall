extends SceneTree
func _init():
	var n = null
	print("about to fault")
	print(n.some_missing_property)
	quit()
