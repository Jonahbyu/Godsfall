from PIL import Image, ImageDraw

BG     = (13, 11, 18)
PANEL  = (34, 29, 46)
ACCENT = (124, 77, 255)
GOLD   = (217, 180, 91)
BORDER = (58, 51, 72)

S = 1024  # supersample, downscaled at the end for smooth edges
img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(img)

# Rounded dark plate
d.rounded_rectangle([16, 16, S - 16, S - 16], radius=150, fill=BG,
                    outline=BORDER, width=18)

# Purple glow behind the throne
d.ellipse([S * 0.20, S * 0.24, S * 0.80, S * 0.86], fill=PANEL)

cx = S / 2

# --- Throne ---
# Backrest
back_l, back_r = cx - 190, cx + 190
back_top, back_bot = S * 0.28, S * 0.66
d.rounded_rectangle([back_l, back_top, back_r, back_bot], radius=40, fill=GOLD)

# Three crown spikes on the backrest
for off, h in ((-130, 0.16), (0, 0.11), (130, 0.16)):
    x = cx + off
    d.polygon([(x - 62, back_top + 20), (x, S * h), (x + 62, back_top + 20)], fill=GOLD)

# Purple inset panel on the backrest
d.rounded_rectangle([back_l + 55, back_top + 60, back_r - 55, back_bot - 70],
                    radius=26, fill=ACCENT)

# Seat
d.rounded_rectangle([cx - 250, S * 0.63, cx + 250, S * 0.72], radius=26, fill=GOLD)

# Armrests
d.rounded_rectangle([cx - 250, S * 0.55, cx - 200, S * 0.66], radius=20, fill=GOLD)
d.rounded_rectangle([cx + 200, S * 0.55, cx + 250, S * 0.66], radius=20, fill=GOLD)

# Base / steps
d.rounded_rectangle([cx - 200, S * 0.72, cx + 200, S * 0.78], radius=16, fill=GOLD)
d.rounded_rectangle([cx - 280, S * 0.78, cx + 280, S * 0.84], radius=16, fill=GOLD)

big = img.resize((256, 256), Image.LANCZOS)

# .ico for the desktop shortcut
ico = r"c:\Users\Jonah\OneDrive\Desktop\Godsfall\tools\Godsfall.ico"
big.save(ico, format="ICO",
         sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
print("wrote", ico)

# .png for the in-game window/taskbar icon (Godot can't load .ico at runtime)
png = r"c:\Users\Jonah\OneDrive\Desktop\Godsfall\icon_window.png"
big.save(png, format="PNG")
print("wrote", png)
