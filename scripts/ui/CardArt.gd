extends Node

## Loads and caches the per-card emblem images in assets/art/.
##
## CardView rebuilds itself on nearly every state change — hover, selection,
## damage, queueing — so the art has to come out of a cache rather than off the
## disk. Textures are shared: two copies of the same card in hand point at one
## ImageTexture, which is safe because nothing ever mutates them.
##
## Art is optional by design. A card with no PNG returns null and CardView draws
## its initials placeholder instead, so adding a card to data/cards.json never
## has to wait on someone drawing it. Regenerate everything with:
##   python tools/make_card_art.py

const ART_DIR := "res://assets/art/"

var _cache: Dictionary = {}      ## card_id -> Texture2D, or null when absent


## The emblem for a card, or null if it has none.
func get_art(card_id: String) -> Texture2D:
	if _cache.has(card_id):
		return _cache[card_id]

	var tex: Texture2D = _load(card_id)
	## Misses are cached too — otherwise an art-less card retries the load on
	## every single redraw of every frame it appears in.
	_cache[card_id] = tex
	return tex


func _load(card_id: String) -> Texture2D:
	var path: String = ART_DIR + card_id + ".png"
	if not ResourceLoader.exists(path):
		return null
	var res: Resource = load(path)
	return res as Texture2D


## Drop the cache. Only useful if the art is regenerated while the game is
## running; nothing in normal play calls this.
func clear() -> void:
	_cache.clear()
