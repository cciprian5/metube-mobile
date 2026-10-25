"""Draws Ember's small Windows icons, one colour each: ink for a light
taskbar and cream for a dark one.

- the tray icon, from the E3 mark;
- the taskbar preview's buttons, from the Wahaj icons the app draws
  (packages/mt_ui/lib/src/icons/mt_icons.dart), so they match the player;
- the count badge on the taskbar button, ember with a cream figure.

At the sizes Windows asks for: 16 at 100 percent scaling, 24 at 150, 32 at
200.

Run from the repository root: python tool/icons/make_tray_icons.py
"""

import io
import re

import fitz  # PyMuPDF renders the SVG; Pillow writes the .ico
from PIL import Image, ImageDraw, ImageFont

# The E3 symbol on its 256 grid, evenodd (docs: 07-DESKTOP section 2.9).
E3 = "M25.50 51.00H31.50A7.5 7.5 0 0 1 39.00 58.50V76.50A7.5 7.5 0 0 1 31.50 84.00H25.50A7.5 7.5 0 0 1 18.00 76.50V58.50A7.5 7.5 0 0 1 25.50 51.00ZM25.50 111.50H31.50A7.5 7.5 0 0 1 39.00 119.00V137.00A7.5 7.5 0 0 1 31.50 144.50H25.50A7.5 7.5 0 0 1 18.00 137.00V119.00A7.5 7.5 0 0 1 25.50 111.50ZM25.50 172.00H31.50A7.5 7.5 0 0 1 39.00 179.50V197.50A7.5 7.5 0 0 1 31.50 205.00H25.50A7.5 7.5 0 0 1 18.00 197.50V179.50A7.5 7.5 0 0 1 25.50 172.00ZM224.50 51.00H230.50A7.5 7.5 0 0 1 238.00 58.50V76.50A7.5 7.5 0 0 1 230.50 84.00H224.50A7.5 7.5 0 0 1 217.00 76.50V58.50A7.5 7.5 0 0 1 224.50 51.00ZM224.50 111.50H230.50A7.5 7.5 0 0 1 238.00 119.00V137.00A7.5 7.5 0 0 1 230.50 144.50H224.50A7.5 7.5 0 0 1 217.00 137.00V119.00A7.5 7.5 0 0 1 224.50 111.50ZM224.50 172.00H230.50A7.5 7.5 0 0 1 238.00 179.50V197.50A7.5 7.5 0 0 1 230.50 205.00H224.50A7.5 7.5 0 0 1 217.00 197.50V179.50A7.5 7.5 0 0 1 224.50 172.00ZM52 82H204V189A23 23 0 0 1 181 212H75A23 23 0 0 1 52 189ZM75.00 96.00H181.00A9 9 0 0 1 190.00 105.00V189.00A9 9 0 0 1 181.00 198.00H75.00A9 9 0 0 1 66.00 189.00V105.00A9 9 0 0 1 75.00 96.00ZM114.83 131.12L114.83 162.88A7 7 0 0 0 125.33 168.94L152.83 153.06A7 7 0 0 0 152.83 140.94L125.33 125.06A7 7 0 0 0 114.83 131.12ZM52 74V67A23 23 0 0 1 75 44H181A23 23 0 0 1 204 67V74Z"

INK, CREAM = "#2B211B", "#FBF6EE"
THEMES = [("light", INK), ("dark", CREAM)]
SIZES = [(16, 16), (24, 24), (32, 32), (48, 48)]
OUT = "apps/metube_desktop/assets/tray/"
ICONS = "packages/mt_ui/lib/src/icons/mt_icons.dart"


def svg_image(svg, scale):
    page = fitz.open(stream=svg.encode(), filetype="svg")[0]
    pixmap = page.get_pixmap(matrix=fitz.Matrix(scale, scale), alpha=True)
    return Image.open(io.BytesIO(pixmap.tobytes("png"))).convert("RGBA")


def wahaj(key):
    """One icon's SVG from the app's own set, slots unfilled."""
    source = open(ICONS, encoding="utf-8").read()
    quotes = "'" * 3
    pattern = r"MTIconData\(\s*'" + key + r"',\s*r" + quotes + "(.*?)" + quotes
    return re.search(pattern, source, re.S).group(1)


def tray():
    for theme, colour in THEMES:
        svg = (
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256">'
            f'<path fill="{colour}" fill-rule="evenodd" d="{E3}"/></svg>'
        )
        image = svg_image(svg, 4).resize((256, 256), Image.LANCZOS)
        image.save(f"{OUT}tray_{theme}.ico", sizes=SIZES)


def preview_buttons():
    for key in ["prev", "play_fill", "pause", "next"]:
        for theme, colour in THEMES:
            svg = wahaj(key).replace("{ink}", colour).replace("{ember}", colour)
            image = svg_image(svg, 256 / 24).resize((256, 256), Image.LANCZOS)
            image.save(f"{OUT}{key}_{theme}.ico", sizes=SIZES[:3])


def badges():
    """The count on the taskbar button: 1 to 9, then 9+."""
    ember = (194, 94, 46, 255)
    cream = (251, 246, 238, 255)
    font_file = "C:/Windows/Fonts/segoeuib.ttf"
    for count in [str(n) for n in range(1, 10)] + ["9+"]:
        image = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
        draw = ImageDraw.Draw(image)
        draw.ellipse((8, 8, 248, 248), fill=ember)
        font = ImageFont.truetype(font_file, 150 if len(count) == 1 else 110)
        draw.text((128, 132), count, font=font, fill=cream, anchor="mm")
        image.save(f"{OUT}badge_{count.replace('+', 'plus')}.ico", sizes=SIZES[:3])


tray()
preview_buttons()
badges()
print("wrote", OUT)
