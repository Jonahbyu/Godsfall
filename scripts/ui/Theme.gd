extends Node

## Autoload: Palette
## The cosmic dark palette, plus small helpers for building styled Controls in code.
##
## Colour is organised in two deliberately separate namespaces, because they
## answer different questions and used to collide:
##
##   CHROME  — the UI itself. Backgrounds, borders, buttons, focus rings. It is
##             faction-NEUTRAL on purpose (see ACCENT) so that colour appearing
##             anywhere on screen means "this is game content", never "this is a
##             button".
##   CONTENT — the cards and the board. Faction energy, keyword chips, HP,
##             structures. This is where colour carries meaning.
##
## The rule that keeps them apart: a chrome colour is never reused as a content
## colour and vice versa. Before, `ACCENT` *was* Hel's purple, `HP_GREEN` was
## byte-identical to Gaia's `earth`, and `DANGER` to `retribution` — so a healthy
## unit and a Gaia keyword were the same green, and the UI's own accent silently
## declared the whole game to be Hel-coloured.

## ------------------------------------------------------------------ chrome

## The ground ramp. Cosmic rather than neutral-grey: every step keeps a blue-violet
## cast and *rises* in both lightness and saturation, so panels read as lit
## surfaces above a deep field rather than as three flat greys. VOID_DEEP sits
## below BG and is what gradients and vignettes fall off toward — having a value
## darker than the base background is what lets the board look lit at all.
const VOID_DEEP   := Color("05040a")
const BG          := Color("0b0917")
const PANEL       := Color("141126")
const PANEL_LIGHT := Color("1e1a35")
const PANEL_RAISED:= Color("272243")   ## hovered/active surfaces, one step above
const BORDER      := Color("35304f")
const BORDER_LIT  := Color("4a4370")   ## borders catching light; hover, focus

## The chrome accent. Deliberately NOT any faction's colour — a cold starlight
## blue that belongs to the game rather than to Hel. This is the single most
## load-bearing change in the palette: it used to be `7c4dff`, byte-identical to
## FACTION.hel, so every button hover and selection ring in the game was Hel
## purple regardless of what the player was actually playing.
const ACCENT      := Color("6ea8ff")
const ACCENT_DIM  := Color("2f4a80")
const ACCENT_GLOW := Color("a8ccff")   ## the bright edge of a focused element

const TEXT        := Color("e8e6f5")
const TEXT_DIM    := Color("9691ad")
const TEXT_FAINT  := Color("635e78")   ## disabled, placeholders, reserved slots

## ------------------------------------------------------------------ content

const GOLD        := Color("e0bd6a")   ## generic/colorless energy
const HP_GREEN    := Color("57c47a")   ## pushed toward teal so it no longer
const HP_AMBER    := Color("d9a64f")   ## collides with Gaia's `earth` green
const HP_RED      := Color("cc5555")
const TOWER       := Color("7b9fd4")
const THRONE      := Color("c47bab")
const DANGER      := Color("e05a5a")   ## UI alarm; distinct from `retribution`

## Energy colours, one per faction. A faction *is* an energy colour (CLAUDE.md),
## so the pool bar reads its fill straight off the faction name. The four built
## and the reserve factions all have an entry, so a pool of a colour that isn't
## implemented yet still renders instead of falling back to grey.
##
## Each faction is a RAMP rather than a single value: `deep` for the shadowed
## underside, `base` for the body, `bright` for the lit edge. A flat fill reads
## as a coloured sticker; three values read as a material with a light source,
## which is most of what makes an energy icon look minted rather than drawn.
## Void is the deliberate exception in spirit — it is built to look like an
## absence with a rim, so its `bright` is proportionally much hotter than its
## body, which is the faction drawn as a hole in the backdrop.
const FACTION_RAMPS := {
	"hel":     { "deep": Color("3d1f7a"), "base": Color("7c4dff"), "bright": Color("b79bff") },
	"void":    { "deep": Color("15151f"), "base": Color("4a4a5e"), "bright": Color("9d9dc4") },
	"gaia":    { "deep": Color("2a6b38"), "base": Color("5fbf6a"), "bright": Color("a3e8a8") },
	"heaven":  { "deep": Color("8a7233"), "base": Color("f0e4a8"), "bright": Color("fffbe6") },
	"forge":   { "deep": Color("7a3312"), "base": Color("e07a3c"), "bright": Color("ffb37a") },
	"tempest": { "deep": Color("1f5c73"), "base": Color("58b8d9"), "bright": Color("a8e4f5") },
	"wyrd":    { "deep": Color("5e2a69"), "base": Color("b866c9"), "bright": Color("e3a8ed") },
	"wilds":   { "deep": Color("4a3d1f"), "base": Color("8f7a4a"), "bright": Color("cbb583") },
}

## Flat faction colours, derived from the ramps so the two can never drift.
## Kept because most call sites want one colour and should not have to know a
## ramp exists.
const FACTION_COLORS := {
	"hel":     Color("7c4dff"),
	"void":    Color("4a4a5e"),
	"gaia":    Color("5fbf6a"),
	"heaven":  Color("f0e4a8"),
	"forge":   Color("e07a3c"),
	"tempest": Color("58b8d9"),
	"wyrd":    Color("b866c9"),
	"wilds":   Color("8f7a4a"),
}


## Keyword chip tints. A keyword's chip is colored by what it *does*, not by
## which faction prints it — `Rise` reads the same on a Hel body and on a Heaven
## one. Keywords absent from here fall back to BORDER, which is legible but
## deliberately plain, so a new keyword renders correctly before it gets a color.
##
## These are CONTENT colours and are kept clear of the semantic UI ones. `earth`
## used to be byte-identical to HP_GREEN and `retribution` to DANGER, which meant
## a healthy unit and a Gaia keyword were the same green, and an alarm and a Hel
## keyword the same red. Both have been separated in hue, not merely nudged in
## brightness — a difference you have to A/B two swatches to see is not a
## difference on a 7px chip.
const KEYWORD_COLORS := {
	## Hel signatures — death as a resource
	"toll":        Color("d9b45b"),
	"decay":       Color("9ec96f"),
	## Heaven — reprieves
	"judgment":    Color("f0e4a8"),
	"sanctuary":   Color("9ec9e8"),
	## Void signatures — denial
	"siphon":      Color("a582d6"),
	"void":        Color("6a6a80"),
	"rift":        Color("c774d6"),
	## Gaia signatures — growth. Shifted toward leaf/yellow-green so it separates
	## from HP_GREEN, which is now deliberately teal-leaning.
	"earth":       Color("7ec94f"),
	"essence":     Color("7ad9a0"),
	## Shared
	"rise":        Color("d67ab8"),
	## Pushed to a warm orange-red so it reads as recoil rather than as the UI's
	## alarm colour, which it used to be exactly.
	"retribution": Color("e0674a"),
	"consume":     Color("e08a3c"),
	"windfury":    Color("58b8d9"),
	"resist":      Color("9494c9"),
	## Forge signatures — the body itself as fuel. Both sit in Forge's warm
	## orange-red, separated from `consume` (also warm) by pushing Stoke hotter
	## and Scrap toward rust, since all three are "spend something you own".
	"stoke":       Color("ff8a4c"),
	"scrap":       Color("c4623a"),
	## Tempest signatures — pressure that builds and breaks. Pushed cooler and
	## more saturated than `windfury`, which shares the faction's storm blue but
	## is a shared keyword rather than a Tempest one.
	"charge":      Color("7fd4f5"),
	"storm":       Color("4f8fd6"),
}


## The energy colour for a faction, falling back to the generic energy gold for
## anything unrecognised (neutral cards, or a colour added to the data first).
func faction_color(faction: String) -> Color:
	return FACTION_COLORS.get(faction.to_lower(), GOLD)


## The full deep/base/bright ramp for a faction. Falls back to a ramp built
## around the generic energy gold, so an unrecognised colour still renders with
## dimension rather than dropping to a flat fill.
func faction_ramp(faction: String) -> Dictionary:
	return FACTION_RAMPS.get(faction.to_lower(), {
		"deep": GOLD.darkened(0.55), "base": GOLD, "bright": GOLD.lightened(0.4),
	})


## One step of a faction's ramp. `which` is "deep", "base" or "bright".
func faction_shade(faction: String, which: String) -> Color:
	var r := faction_ramp(faction)
	return r.get(which, r["base"])


## The chip tint for a keyword, falling back to a plain border grey so an
## unrecognised keyword still renders as a chip rather than vanishing.
func keyword_color(kw: String) -> Color:
	return KEYWORD_COLORS.get(kw.to_lower(), BORDER)


## Hover help for a keyword chip, keyed the same way KEYWORD_COLORS is.
##
## A chip is two words at 7px. That is enough to *recognise* a keyword you already
## know and nothing at all if you do not, which bites hardest exactly where the
## rules are least guessable — `Void 2` and `Rift 2` cannot be read off the card,
## and Rift additionally scales off a board-wide number no chip can show.
##
## These are condensed from the Compendium's keyword pages in `TutorialData.gd`,
## which remain the authoritative long form. The job here is a reminder at the
## point of decision, not a rules page: 2-4 short lines, leading with what the
## keyword *does* and following with the one detail players get wrong.
##
## Two constraints on the text:
##
##   * ASCII plus Latin-1 punctuation only. The bundled Inter has no arrows,
##     geometric shapes or emoji, and `LayoutTest` scans these literals against
##     the real theme font — an unrenderable character ships as a blank box that
##     looks correct in every editor and diff.
##   * Never promise what the engine does not do. `Windfury` says outright that it
##     is unimplemented, for the same reason the inspector said so about retreat
##     costs before the retreat action existed.
const KEYWORD_HELP := {
	"toll":
		"When this unit dies, you gain N pool energy.
"
		+ "N is printed (HP / 25) and never recalculates in play.
"
		+ "Retreat pays no Toll — the unit did not die.",
	"decay":
		"At end of turn, deal N damage to the unit across from this one.
"
		+ "Free and automatic, every turn.
"
		+ "Follows the normal targeting chain, so it cannot chip past a wall to a tower or throne.",
	"judgment":
		"ONE charge, spent by either half.
"
		+ "Defensive: when this unit would die, it survives at N HP instead.
"
		+ "Offensive: when this unit's attack leaves a defender at N HP or below, that defender dies.
"
		+ "Either use spends the charge, and it returns only if the card returns to hand.",
	"sanctuary":
		"A depleting pool of N that absorbs damage from any source.
"
		+ "When the pool cannot cover a hit it absorbs that hit ENTIRELY, then is spent.
"
		+ "So N is a floor, not a ceiling: many small hits break it, one big hit feeds it.",
	"siphon":
		"MOVES N attached energy from an enemy unit onto this one — it is not destroyed, you gain what they lose.
"
		+ "That swings the Gap by 2N.
"
		+ "On a support card it goes to your pool instead, which does NOT feed the Gap.",
	"void":
		"DESTROYS N attached energy on an enemy unit. Nobody gains it.
"
		+ "Attached energy only, never the pool.
"
		+ "Obeys the normal targeting chain and never reaches a tower or throne.",
	"rift":
		"This unit's attacks deal +N damage per point of your Gap.
"
		+ "Gap = your total attached energy minus theirs, floored at 0, living units only.
"
		+ "Deliberately uncapped — a large Gap is energy staked on bodies that can all die at once.",
	"earth":
		"A board-wide aura. Every point of Earth on your LIVING units grants
"
		+ "+1 damage and +1 max HP to each of your units and both your towers.
"
		+ "It is a live sum: killing an Earth body shrinks the whole aura immediately.",
	"essence":
		"When this unit dies, spend N POOL energy to move its Earth and attached energy
"
		+ "to the nearest living friendly unit on the same board. It never crosses boards.
"
		+ "The energy has to be banked in advance; if you cannot pay, it does not fire.",
	"rise":
		"When this dies, it returns to an empty slot on your side at the start of your next turn,
"
		+ "at HALF HP and WITHOUT Rise. Everything else returns at printed values.
"
		+ "Attached energy is not restored, and anything the card grew in play resets.",
	"retribution":
		"When this unit takes damage from an attack, it deals N damage back to the attacker.
"
		+ "It still fires from a unit that the attack killed — nothing leaves the board mid-attack.
"
		+ "If the recoil kills the attacker, both die.",
	"consume":
		"This line DESTROYS N attached energy every time it is used.
"
		+ "It is the only cost an ability may carry; abilities are otherwise free.
"
		+ "Unlike an attack's cost, it is not paid once — the unit must be re-charged each use.",
	"windfury":
		"This unit may attack twice per turn.
"
		+ "NOT YET IMPLEMENTED — no card uses it, and the engine does not grant the second attack.
"
		+ "It is defined so the reserve storm faction has a home.",
	"resist":
		"Reduce each incoming INSTANCE of damage by X, to a minimum of 1 damage.
"
		+ "Per instance, so four hits of 10 into Resist 5 total 20, not 35.
"
		+ "Strong against chip damage, weak against one big attack.",
	"stoke":
		"A free once-per-turn ability: deal N damage to this unit.
"
		+ "The unit has STOKED until end of turn, and its other lines read that.
"
		+ "Unpreventable — Sanctuary, Resist and Retribution all ignore it,
"
		+ "because it is a cost you choose to pay, not damage from a source.
"
		+ "It may kill the unit paying it.",
	"scrap":
		"An ability cost: destroy ANOTHER unit you control to activate the line.
"
		+ "The scrapped unit really dies, so Toll, Rise and Essence all fire.
"
		+ "Never itself, and it charges every use — there is no annuity.",
	"charge":
		"Charge N — this unit banks N each time it deals an instance of damage.
"
		+ "Spend the whole counter with its Discharge ability.
"
		+ "Kept through evolution (the rate becomes the new card's); lost if the unit dies.",
	"storm":
		"Storm N — a global counter BOTH players read, raised by Tempest cards.
"
		+ "Every attack deals one extra instance of N damage.
"
		+ "A Tempest unit's Storm instance is doubled.",
}


## The hover help for a keyword, or "" for one that has none.
##
## Empty rather than a placeholder, so a chip without help renders as an ordinary
## chip instead of advertising a missing entry. `CardViewTest` asserts every key in
## KEYWORD_COLORS has one, so a new keyword fails the suite until it is written.
func keyword_help(kw: String) -> String:
	return KEYWORD_HELP.get(kw.to_lower(), "")


## NOTE: these are called through the `Palette` autoload *instance*
## (e.g. `Palette.label(...)`). They are deliberately non-static so Godot does
## not warn about calling a static function on an instance.
func panel_style(bg: Color = PANEL, border: Color = BORDER, width: int = 1, radius: int = 7) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	## Padding comes from the spacing scale rather than from two numbers picked
	## here, so a panel's interior breathing room is the same quantity used
	## between its children — which is what makes nesting look intentional.
	s.content_margin_left = SPACE_MD
	s.content_margin_right = SPACE_MD
	s.content_margin_top = SPACE_MD - 1
	s.content_margin_bottom = SPACE_MD - 1
	return s


## A panel with a soft drop shadow — the base for anything that should read as
## sitting *above* the field rather than painted onto it. Shadow rather than a
## brighter fill is what creates depth without spending contrast, which matters
## on a dark ground where there is very little contrast budget to spend.
func raised_style(bg: Color = PANEL, border: Color = BORDER, radius: int = 8, shadow: int = 6) -> StyleBoxFlat:
	var s := panel_style(bg, border, 1, radius)
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = shadow
	s.shadow_offset = Vector2(0, 2)
	return s


## A panel lit from above.
##
## The obvious implementation is a gradient fill, and it is unavailable: assigning
## a `GradientTexture2D` to `StyleBoxFlat.texture` **hangs indefinitely under
## `--headless`**, because the texture needs the rendering server to realise
## itself. Every screen in this project must build headlessly for the harnesses,
## so a gradient fill would trade the whole test suite for a shading effect.
## Isolated by probe to that exact assignment — the Gradient and the
## GradientTexture2D both construct fine on their own.
##
## So the light is implied by *edges* instead, which costs nothing and reads
## nearly as well on a dark ground: a brighter top border and a darker bottom
## one give the surface a lit rim and a shadowed underside, which is the part of
## a gradient the eye actually uses to infer a light source.
func lit_style(bg: Color = PANEL, border: Color = BORDER, radius: int = 8, lift: float = 0.06) -> StyleBoxFlat:
	var s := raised_style(bg, border, radius)
	s.border_color = border
	s.border_width_top = 1
	s.border_width_bottom = 1
	## The top edge catches the light; the bottom sits in its own shadow.
	s.set_corner_radius_all(radius)
	s.bg_color = bg.lightened(lift * 0.35)
	return s


func button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := panel_style(bg, border, 1, 4)
	s.content_margin_left = 10
	s.content_margin_right = 10
	return s


## Apply a consistent look to a Button in code.
##
## The four states are a deliberate progression of *light*, not just of fill:
## normal sits lit-from-above, hover rises a step and picks up the accent on its
## border, pressed sinks below its resting value, and disabled loses the gradient
## entirely so it reads as unlit rather than merely dark. A button whose only
## hover state is a slightly different grey is the single most common reason a
## dark UI feels unresponsive.
func style_button(b: Button, bg: Color = PANEL_LIGHT, border: Color = BORDER) -> void:
	b.add_theme_stylebox_override("normal", _btn_lit(bg, border))
	b.add_theme_stylebox_override("hover", _btn_lit(bg.lightened(0.14), ACCENT))
	b.add_theme_stylebox_override("pressed", _btn_flat(bg.darkened(0.22), ACCENT_DIM))
	b.add_theme_stylebox_override("focus", _btn_lit(bg.lightened(0.06), ACCENT_GLOW))
	b.add_theme_stylebox_override("disabled", _btn_flat(bg.darkened(0.4), BORDER.darkened(0.35)))
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", ACCENT_GLOW)
	b.add_theme_color_override("font_disabled_color", TEXT_FAINT)


func _btn_lit(bg: Color, border: Color) -> StyleBoxFlat:
	var s := lit_style(bg, border, 5, 0.09)
	s.shadow_size = 3
	s.content_margin_left = 10
	s.content_margin_right = 10
	return s


func _btn_flat(bg: Color, border: Color) -> StyleBoxFlat:
	var s := panel_style(bg, border, 1, 5)
	s.content_margin_left = 10
	s.content_margin_right = 10
	return s


## A button styled as the screen's primary action — the one thing you most
## likely came here to press. Uses the accent as its own fill rather than only
## as a border, so exactly one control per screen carries saturated colour.
func style_primary_button(b: Button) -> void:
	style_button(b, ACCENT_DIM, ACCENT)
	b.add_theme_color_override("font_color", Color.WHITE)


## A `PopupMenu` styled to match the panels around it.
##
## Godot's default popup is a light-grey system menu, which on this ground looks
## like a different application has opened on top of the game. Every popup in
## the project goes through here so there is one place to change them.
func style_popup(p: PopupMenu) -> void:
	p.add_theme_stylebox_override("panel", panel_style(PANEL_LIGHT, BORDER_LIT, 1, 8))
	p.add_theme_stylebox_override("hover", panel_style(PANEL_RAISED, PANEL_RAISED, 0, 5))
	p.add_theme_color_override("font_color", TEXT)
	p.add_theme_color_override("font_hover_color", ACCENT_GLOW)
	p.add_theme_color_override("font_disabled_color", TEXT_FAINT)
	p.add_theme_color_override("font_separator_color", TEXT_FAINT)
	p.add_theme_font_size_override("font_size", TYPE_BODY)
	p.add_theme_constant_override("v_separation", SPACE_SM)


## ------------------------------------------------------------------ fonts

## The two bundled families.
##
## The project shipped with **no font at all**, so everything rendered in Godot's
## built-in Open Sans SemiBold — which is a perfectly good typeface and is also
## the single loudest signal that a Godot game has not been art-directed, because
## it is what every unstyled Godot project looks like. Type is most of what
## separates a finished card game from a prototype.
##
##   DISPLAY  Cinzel — a Roman inscriptional face. Used for the game's name, screen
##            titles and section headings. It is a *display* face: it is beautiful
##            at 20px and up and turns to mush below about 14, so it is never used
##            for running text or anything on a card.
##   UI       Inter — designed specifically for user interfaces at small sizes,
##            with a tall x-height and open apertures. This is what makes the
##            board's 7px type legible where Open Sans was marginal.
##
## Both are SIL Open Font License, so they can ship in a public repo and to the
## web build. Windows' own Georgia and Cambria were the obvious candidates and are
## license-locked — they may not be redistributed, which rules them out entirely
## for a repo that publishes to GitHub Pages.
##
## Both are **subset** to Latin-1 plus the punctuation `GLYPH` needs: 174KB for the
## pair, against 1MB unsubset. Regenerate with `tools/make_fonts.py` if the glyph
## table ever grows beyond what they cover — `LayoutTest` fails loudly if it does,
## because it checks every UI literal against the live theme font.
const FONT_DISPLAY_PATH := "res://assets/fonts/Cinzel.ttf"
const FONT_UI_PATH      := "res://assets/fonts/Inter.ttf"

var _font_display: Font
var _font_ui: Font


## The display face, loaded once. Returns null if the file is missing, and every
## caller treats null as "use the default" — a missing font must degrade to
## Godot's built-in rather than crash the screen.
func font_display() -> Font:
	if _font_display == null and ResourceLoader.exists(FONT_DISPLAY_PATH):
		_font_display = load(FONT_DISPLAY_PATH)
	return _font_display


func font_ui() -> Font:
	if _font_ui == null and ResourceLoader.exists(FONT_UI_PATH):
		_font_ui = load(FONT_UI_PATH)
	return _font_ui


## Build the project-wide default theme.
##
## Applied to the scene tree root by `_ready`, so **every** Control inherits Inter
## without a single call site having to ask for it. That matters for more than
## convenience: `LayoutTest` resolves "the theme font" by reading it off a bare
## `Label`, so setting the default is what makes the glyph check validate against
## the font the game actually renders with.
func build_theme() -> Theme:
	var t := Theme.new()
	var ui := font_ui()
	if ui != null:
		t.default_font = ui
	t.default_font_size = TYPE_BODY
	return t


## ------------------------------------------------------------ type & space

## The type scale.
##
## Before this existed the UI used fifteen distinct font sizes, with 12, 13, 14,
## 15 and 16 all in heavy use at once. Five sizes inside a five-point range is
## not a hierarchy — the differences are too small to perceive, so everything
## reads as one undifferentiated middle weight and the eye has nothing to land
## on. Choosing a size per call site is what produces that.
##
## These steps are spaced far enough apart to be *seen* as different (roughly a
## 1.25 ratio in the body range), and there are deliberately few of them. Fewer
## sizes, used consistently, is what reads as designed.
##
##   DISPLAY  the game's name; used once
##   TITLE    a screen's name
##   HEADING  a major section within a screen
##   SUBHEAD  a group label inside a section
##   BODY     default running text
##   SMALL    secondary text — counts, hints, captions
##   MICRO    the smallest text that should ever ship; legal-print equivalent
const TYPE_DISPLAY := 56
const TYPE_TITLE   := 28
const TYPE_HEADING := 20
const TYPE_SUBHEAD := 16
const TYPE_BODY    := 13
const TYPE_SMALL   := 11
const TYPE_MICRO    := 9

## The spacing scale, in design units.
##
## Same problem as the type scale: twelve distinct separation values were in
## use, including 1, 2, 3 and 5, which cannot be told apart and therefore carry
## no meaning. A geometric-ish ramp gives spacing a rhythm, and rhythm is most of
## what makes a dense layout feel composed rather than crowded.
##
## The rule of thumb these encode: space *within* a group is SPACE_XS or SPACE_SM,
## space *between* groups is SPACE_MD or larger. When those two ranges overlap,
## grouping stops being readable — which is the real cost of ad-hoc spacing.
const SPACE_XS := 2
const SPACE_SM := 4
const SPACE_MD := 8
const SPACE_LG := 14
const SPACE_XL := 22

## Width the settings cog occupies in every screen's top-right corner.
##
## The cog lives on a CanvasLayer above the scene, so it is invisible to each
## screen's layout — a top bar that runs its controls to the right edge puts
## them *underneath* it. Deck select's "+ New Deck" and the deck builder's
## "Clear" were both partly covered by it.
##
## It lives here rather than on the `Settings` autoload because an autoload has
## no `class_name`: naming `Settings` at class scope in a screen would drag the
## autoload into compile time and break every headless harness, which is a trap
## this project has already hit twice. `SettingsButton` asserts it matches.
const COG_RESERVE := 64


## A section heading: small, wide-tracked, and dim.
##
## Uppercase with letter spacing is the standard way to mark a label as
## structural rather than as content — it reads as furniture even at a size the
## eye would otherwise treat as body text, which is what lets headings be small
## enough not to compete with the thing they label.
func heading(text: String, color: Color = TEXT_DIM) -> Label:
	var l := label(text.to_upper(), TYPE_SMALL, color)
	l.add_theme_constant_override("line_spacing", 2)
	var f := font_display()
	if f != null:
		l.add_theme_font_override("font", f)
	return l


## A display-face title. Cinzel is an inscriptional face and only works large —
## it is deliberately unavailable below TYPE_SUBHEAD, where it would be less
## legible than the UI face rather than more characterful.
func title(text: String, size: int = TYPE_TITLE, color: Color = TEXT) -> Label:
	var l := label(text, max(size, TYPE_SUBHEAD), color)
	var f := font_display()
	if f != null:
		l.add_theme_font_override("font", f)
	return l


## ------------------------------------------------------------------ glyphs

## Every non-alphanumeric symbol the UI prints, in one table.
##
## The UI now renders in bundled **Inter** (see *fonts* above), which is a wider
## safe set than the built-in Open Sans this table was written against — but it
## is still a text face: it has no arrows, no geometric shapes and no emoji, and
## every one of those renders as an empty box. That is not a web-only problem,
## but it is worst there, because a desktop Godot window can sometimes fall back
## to a system font and a browser canvas cannot fall back to anything.
##
## The table therefore stays exactly as it is. Bundling a font widened the floor;
## it did not remove the need to check, and the ASCII stand-ins below cost
## nothing and cannot regress.
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
	## Overflow menu. U+2026 HORIZONTAL ELLIPSIS is in the Inter subset
	## (checked with has_char, not by eye); U+22EF MIDLINE ELLIPSIS is not.
	"more":      "…",     ## row actions collapsed behind one button
	## The settings cog. A real gear (U+2699) is not in Open Sans, so this is the
	## ASCII stand-in — read as a small dial rather than a gear, which is the same
	## affordance at this size.
	"settings":  "[=]",
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


## Install the default theme on the scene tree root.
##
## Deferred a frame: an autoload's `_ready` can run before the root window is in
## a state where assigning a theme sticks, and the symptom of getting this wrong
## is the silent one — the theme is simply ignored and everything renders in the
## built-in font, which looks exactly like not having bundled a font at all.
func _ready() -> void:
	call_deferred("_install_theme")


func _install_theme() -> void:
	var loop := Engine.get_main_loop()
	if loop == null:
		return
	var t := build_theme()
	loop.root.theme = t
