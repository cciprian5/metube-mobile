"""The MeTube Ember mark, E3, from one source.

A window whose title bar glows: the bar is an ember, the play sign sits in
the window, and film perforations run down both sides, as on the Lite and
Super icons. On a 256 grid; the geometry is the approved one, unchanged.

Everything Ember draws of its mark comes from here: the Windows icon, the
tray icon, the installer images and the brand files.
"""

import io
import re

import fitz  # PyMuPDF: renders SVG and turns a font's glyphs into paths
from PIL import Image

GRID = 256

ESPRESSO = "#2B211B"
CREAM = "#FBF6EE"
EMBER = "#C25E2E"
# The tile's light edge on a dark taskbar: cream, faint.
EDGE_ALPHA = 0.32

PERFS = (
    "M25.50 51.00H31.50A7.5 7.5 0 0 1 39.00 58.50V76.50A7.5 7.5 0 0 1 31.50 84.00H25.50A7.5 7.5 0 0 1 18.00 76.50V58.50A7.5 7.5 0 0 1 25.50 51.00Z"
    "M25.50 111.50H31.50A7.5 7.5 0 0 1 39.00 119.00V137.00A7.5 7.5 0 0 1 31.50 144.50H25.50A7.5 7.5 0 0 1 18.00 137.00V119.00A7.5 7.5 0 0 1 25.50 111.50Z"
    "M25.50 172.00H31.50A7.5 7.5 0 0 1 39.00 179.50V197.50A7.5 7.5 0 0 1 31.50 205.00H25.50A7.5 7.5 0 0 1 18.00 197.50V179.50A7.5 7.5 0 0 1 25.50 172.00Z"
    "M224.50 51.00H230.50A7.5 7.5 0 0 1 238.00 58.50V76.50A7.5 7.5 0 0 1 230.50 84.00H224.50A7.5 7.5 0 0 1 217.00 76.50V58.50A7.5 7.5 0 0 1 224.50 51.00Z"
    "M224.50 111.50H230.50A7.5 7.5 0 0 1 238.00 119.00V137.00A7.5 7.5 0 0 1 230.50 144.50H224.50A7.5 7.5 0 0 1 217.00 137.00V119.00A7.5 7.5 0 0 1 224.50 111.50Z"
    "M224.50 172.00H230.50A7.5 7.5 0 0 1 238.00 179.50V197.50A7.5 7.5 0 0 1 230.50 205.00H224.50A7.5 7.5 0 0 1 217.00 197.50V179.50A7.5 7.5 0 0 1 224.50 172.00Z"
)
# The window's body, with its screen cut out and the play sign inside.
BODY = "M52 82H204V189A23 23 0 0 1 181 212H75A23 23 0 0 1 52 189Z"
SCREEN = "M75.00 96.00H181.00A9 9 0 0 1 190.00 105.00V189.00A9 9 0 0 1 181.00 198.00H75.00A9 9 0 0 1 66.00 189.00V105.00A9 9 0 0 1 75.00 96.00Z"
PLAY = "M114.83 131.12L114.83 162.88A7 7 0 0 0 125.33 168.94L152.83 153.06A7 7 0 0 0 152.83 140.94L125.33 125.06A7 7 0 0 0 114.83 131.12Z"
# The title bar: the ember.
BAND = "M52 74V67A23 23 0 0 1 75 44H181A23 23 0 0 1 204 67V74Z"

# The whole mark in one colour, for the tray and one-colour print.
SYMBOL = PERFS + BODY + SCREEN + PLAY + BAND

# Below this many pixels the perforations are a smudge and the gap under
# the title bar closes: the small cut drops the perforations and keeps the
# window, its glowing bar and the play sign.
SMALL_BELOW = 24

TILE_RADIUS = 58


def _svg(body, w=GRID, h=GRID, title="MeTube Ember"):
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w:g} {h:g}">'
        f"<title>{title}</title>{body}</svg>"
    )


def tile_art(edge=False, small=False):
    """The tile and the mark on it, as SVG elements on the 256 grid."""
    cream = (BODY + SCREEN + PLAY) if small else (PERFS + BODY + SCREEN + PLAY)
    # The small cut draws the window larger in the tile, so what is left
    # still reads at 16 px.
    grow = ' transform="translate(128 128) scale(1.18) translate(-128 -128)"' if small else ""
    rim = (
        f'<rect x="2" y="2" width="{GRID - 4}" height="{GRID - 4}" '
        f'rx="{TILE_RADIUS - 2}" fill="none" stroke="{CREAM}" '
        f'stroke-opacity="{EDGE_ALPHA}" stroke-width="4"/>'
        if edge else ""
    )
    return (
        f'<rect width="{GRID}" height="{GRID}" rx="{TILE_RADIUS}" fill="{ESPRESSO}"/>{rim}'
        f'<g{grow}><path fill="{CREAM}" fill-rule="evenodd" d="{cream}"/>'
        f'<path fill="{EMBER}" d="{BAND}"/></g>'
    )


def tile_svg(edge=False, small=False):
    """The app icon: the mark on its espresso tile."""
    return _svg(tile_art(edge, small))


def mono_svg(colour, small=False):
    """The mark alone in [colour]: the title bar a separate block."""
    d = (BODY + SCREEN + PLAY + BAND) if small else SYMBOL
    move = ' transform="translate(128 128) scale(1.18) translate(-128 -128)"' if small else ""
    return _svg(f'<path{move} fill="{colour}" fill-rule="evenodd" d="{d}"/>')


# --- the name, as paths -------------------------------------------------

_NUM = r"-?(?:\d+\.?\d*|\.\d+)(?:[eE]-?\d+)?"


def _transform_path(d, a, b, c, dd, e, f):
    """Applies an affine transform to an absolute path of M, L, H, V, C, Z."""
    out, x, y = [], 0.0, 0.0
    for cmd, args in re.findall(r"([MLHVCZ])([^MLHVCZ]*)", d):
        nums = [float(n) for n in re.findall(_NUM, args)]
        if cmd == "Z":
            out.append("Z")
            continue
        if cmd == "H":
            pts = [(n, y) for n in nums]
            cmd = "L"
        elif cmd == "V":
            pts = [(x, n) for n in nums]
            cmd = "L"
        else:
            pts = list(zip(nums[0::2], nums[1::2]))
        x, y = pts[-1]
        moved = [(a * px + c * py + e, b * px + dd * py + f) for px, py in pts]
        out.append(cmd + " ".join(f"{px:.2f} {py:.2f}" for px, py in moved))
    return "".join(out)


def wordmark(text, fontfile, size):
    """[text] in [fontfile] at [size] as one path, with its left edge at 0
    and its baseline at 0; returns (d, width)."""
    doc = fitz.open()
    page = doc.new_page(width=size * len(text), height=size * 2)
    page.insert_font(fontname="mark", fontfile=fontfile)
    page.insert_text((0, size * 1.5), text, fontname="mark", fontsize=size)
    svg = page.get_svg_image(text_as_path=True)
    glyphs = dict(re.findall(r'<path id="([^"]+)" d="([^"]*)"', svg))
    parts = []
    for ref, matrix in re.findall(
        r'<use[^>]*xlink:href="#([^"]+)"[^>]*transform="matrix\(([^)]*)\)"', svg
    ):
        a, b, c, d, e, f = (float(v) for v in matrix.split(","))
        parts.append(_transform_path(glyphs[ref], a, b, c, d, e, f - size * 1.5))
    d = "".join(parts)
    xs = [float(v) for v in re.findall(_NUM, d)[0::2]]
    return d, max(xs) - min(xs)


# --- rendering ------------------------------------------------------------

def render(svg, size, supersample=4):
    """[svg] as an RGBA image [size] pixels square (or wide, keeping its
    shape), drawn larger and reduced for clean edges."""
    page = fitz.open(stream=svg.encode(), filetype="svg")[0]
    scale = size * supersample / page.rect.height
    pixmap = page.get_pixmap(matrix=fitz.Matrix(scale, scale), alpha=True)
    image = Image.open(io.BytesIO(pixmap.tobytes("png"))).convert("RGBA")
    w = round(image.width / supersample)
    return image.resize((w, size), Image.LANCZOS)
