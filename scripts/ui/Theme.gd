extends Node

## Autoload: Palette
## Hel-flavoured dark palette + small helpers for building styled Controls in code.

const BG          := Color("0d0b12")
const PANEL       := Color("17141f")
const PANEL_LIGHT := Color("221d2e")
const BORDER      := Color("3a3348")
const ACCENT      := Color("7c4dff")   ## Hel purple
const ACCENT_DIM  := Color("4a2f99")
const TEXT        := Color("e6e1f0")
const TEXT_DIM    := Color("8f88a3")
const GOLD        := Color("d9b45b")   ## energy
const HP_GREEN    := Color("5fbf6a")
const HP_RED      := Color("c04d4d")
const TOWER       := Color("6b8fbf")
const THRONE      := Color("bf6b9e")
const DANGER      := Color("d94f4f")

## Energy colours, one per faction. A faction *is* an energy colour (CLAUDE.md),
## so the pool bar reads its fill straight off the faction name. The four built
## and the reserve factions all have an entry, so a pool of a colour that isn't
## implemented yet still renders instead of falling back to grey.
const FACTION_COLORS := {
	"hel":     Color("7c4dff"),   ## the Hel purple, matching ACCENT
	"void":    Color("4a4a5e"),
	"gaia":    Color("5fbf6a"),
	"heaven":  Color("e8d98a"),
	"forge":   Color("e07a3c"),
	"tempest": Color("58b8d9"),
	"wyrd":    Color("b866c9"),
	"wilds":   Color("8f7a4a"),
}


## Keyword chip tints. A keyword's chip is colored by what it *does*, not by
## which faction prints it — `Rise` reads the same on a Hel body and on a Heaven
## one. Keywords absent from here fall back to BORDER, which is legible but
## deliberately plain, so a new keyword renders correctly before it gets a color.
const KEYWORD_COLORS := {
	## Hel signatures — death as a resource
	"toll":        Color("d9b45b"),
	"decay":       Color("8fbf6a"),
	## Heaven — reprieves
	"judgment":    Color("e8d98a"),
	"sanctuary":   Color("9ec9e8"),
	## Void signatures — denial
	"siphon":      Color("9a7ac9"),
	"void":        Color("6a6a80"),
	"rift":        Color("b866c9"),
	## Gaia signatures — growth
	"earth":       Color("5fbf6a"),
	"essence":     Color("7ad9a0"),
	## Shared
	"rise":        Color("bf6b9e"),
	"retribution": Color("d94f4f"),
	"consume":     Color("e07a3c"),
	"windfury":    Color("58b8d9"),
	"resist":      Color("8f8fbf"),
}


## The energy colour for a faction, falling back to the generic energy gold for
## anything unrecognised (neutral cards, or a colour added to the data first).
func faction_color(faction: String) -> Color:
	return FACTION_COLORS.get(faction.to_lower(), GOLD)


## The chip tint for a keyword, falling back to a plain border grey so an
## unrecognised keyword still renders as a chip rather than vanishing.
func keyword_color(kw: String) -> Color:
	return KEYWORD_COLORS.get(kw.to_lower(), BORDER)


## NOTE: these are called through the `Palette` autoload *instance*
## (e.g. `Palette.label(...)`). They are deliberately non-static so Godot does
## not warn about calling a static function on an instance.
func panel_style(bg: Color = PANEL, border: Color = BORDER, width: int = 1, radius: int = 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s


func button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := panel_style(bg, border, 1, 4)
	s.content_margin_left = 10
	s.content_margin_right = 10
	return s


## Apply a consistent look to a Button in code.
func style_button(b: Button, bg: Color = PANEL_LIGHT, border: Color = BORDER) -> void:
	b.add_theme_stylebox_override("normal", button_style(bg, border))
	b.add_theme_stylebox_override("hover", button_style(bg.lightened(0.12), ACCENT))
	b.add_theme_stylebox_override("pressed", button_style(bg.darkened(0.15), ACCENT))
	b.add_theme_stylebox_override("disabled", button_style(bg.darkened(0.35), BORDER.darkened(0.3)))
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", TEXT_DIM.darkened(0.3))


## ------------------------------------------------------------------ glyphs

## Every non-alphanumeric symbol the UI prints, in one table.
##
## The project bundles no font, so everything renders in Godot's built-in
## **Open Sans SemiBold** — which covers Latin-1 and essentially nothing else.
## Arrows, geometric shapes and emoji are all absent from it and render as
## empty boxes. That is not a web-only problem, but it is worst there, because
## a desktop Godot window can sometimes fall back to a system font and a
## browser canvas cannot fall back to anything.
##
## Verified against `Font.has_char()` rather than by eye: the whole class of bug
## here is a glyph that looks fine in an editor and is a box in the game.
##
## The safe set is narrow — Latin-1 punctuation plus ASCII:
##   OK:      · — × • − < > " " and all of ASCII
##   MISSING: ← → ◆ ⚠ ⬢ ☠ ⚒ ✓ ✕ ▸ ▾ ▶ ★ ● ■ ▲ ▼ 🔒 🔓 🎲
##
## Adding a symbol means checking it first. `Font.has_char()` on the theme font
## is the check; if it fails, pick an ASCII stand-in rather than shipping a box.
## Bundling a symbol font was the alternative and was rejected: it is megabytes
## onto an already 39MB wasm download, to draw about twenty characters.
const GLYPH := {
	## Navigation. ASCII angle brackets rather than real arrows.
	"back":      "<",
	"forward":   ">",

	## Energy — the game's most-printed symbol, on every attack cost, every
	## card's cost row and the pool meter. U+2B22 HEXAGON was a box everywhere.
	## `#` reads as a countable token next to a number and is unambiguous at the
	## 7px the board card renders it at, which a letter would not be.
	"energy":    "#",

	## Status markers.
	"active":    "*",     ## the selected deck in a list
	"warn":      "!",     ## illegal deck, unaffordable action
	"check":     "v",     ## completed tutorial step
	"close":     "x",     ## modal dismiss
	"dead":      "+",     ## dies at end of turn
	"locked":    "[L]",   ## attack lock on
	"unlocked":  "[ ]",   ## attack lock off
	"random":    "?",     ## the Random opponent entry
	"tool":      "=",     ## an attached Tool
	"ability":   "-",     ## an ability line, vs. an attack line
	"queued":    ">",     ## an attack queued this turn

	## Disclosure triangles for the compact battle-log drawer.
	"collapsed": "+",
	"expanded":  "-",

	## These four ARE in Open Sans and are used as-is; they are listed so the
	## table is the single place to look, not so they need translating.
	"dot":       "·",
	"dash":      "—",
	"times":     "×",
	"minus":     "−",
}


## The glyph for a UI symbol. Unknown keys return "" rather than a box or a
## crash, so a typo degrades to a missing decoration instead of a broken label.
func glyph(name: String) -> String:
	return GLYPH.get(name, "")


func make_panel(bg: Color = PANEL, border: Color = BORDER) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_style(bg, border))
	return p


func label(text: String, size: int = 14, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## Colour an HP bar by remaining fraction.
func hp_color(current: int, maximum: int) -> Color:
	if maximum <= 0:
		return HP_RED
	var f := float(current) / float(maximum)
	if f > 0.6:
		return HP_GREEN
	if f > 0.3:
		return GOLD
	return HP_RED
