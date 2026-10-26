"""Builds MeTube Ember's mark kit from tool/icons/ember_mark.py.

- The Windows icon (windows/runner/resources/app_icon.ico), with the light
  edge that keeps the dark tile from melting into a dark taskbar, and the
  small cut below 24 px.
- The tray icons, one colour: ink for a light taskbar, cream for a dark one.
- The installer's two images, for Inno Setup.
- The brand files (apps/metube_desktop/brand/): the mark in colour and in
  one colour, the name beside it and under it, and their usage guide.

Run from the repository root: python tool/make_icons.py --windows
"""

import os

from PIL import Image

import ember_mark as m

APP = "apps/metube_desktop"
BRAND = f"{APP}/brand"
FONT = "packages/mt_ui/assets/fonts/Tajawal-Bold.ttf"

INK = m.ESPRESSO

# Sizes Windows asks an app icon for, from 100 to 400 percent scaling.
ICON_SIZES = [16, 20, 24, 32, 40, 48, 64, 256]
TRAY_SIZES = [16, 20, 24, 32, 40, 48]


def _ico(images, path):
    # The largest first: Pillow leaves out every size above the image it
    # saves from, and an icon of 16 alone is stretched by the taskbar.
    largest, *rest = sorted(images, key=lambda i: -i.width)
    largest.save(path, format="ICO", sizes=[(i.width, i.height) for i in images],
                 append_images=rest)


def app_icon():
    images = [m.render(m.tile_svg(edge=True, small=s < m.SMALL_BELOW), s)
              for s in ICON_SIZES]
    _ico(images, f"{APP}/windows/runner/resources/app_icon.ico")


def tray_icons():
    for theme, colour in [("light", INK), ("dark", m.CREAM)]:
        images = [m.render(m.mono_svg(colour, small=s < m.SMALL_BELOW), s)
                  for s in TRAY_SIZES]
        _ico(images, f"{APP}/assets/tray/tray_{theme}.ico")


# --- the name beside the mark, and under it --------------------------------

def _lockup(kind, edge, word_colour, mono=None):
    """The mark with the name: [kind] horizontal or stacked; in colour on
    its tile, or the bare mark in [mono]."""
    if kind == "horizontal":
        size, gap = 162, 64
        word, width = m.wordmark("MeTube Ember", FONT, size)
        cap = size * 0.633
        w, h = m.GRID + gap + width, m.GRID
        mark_at, word_at = (0, 0), (m.GRID + gap, m.GRID / 2 + cap / 2)
    else:
        size, gap = 122, 52
        word, width = m.wordmark("MeTube Ember", FONT, size)
        cap = size * 0.633
        w = max(m.GRID, width)
        h = m.GRID + gap + cap
        mark_at, word_at = ((w - m.GRID) / 2, 0), ((w - width) / 2, m.GRID + gap + cap)
    if mono:
        mark = f'<path fill="{mono}" fill-rule="evenodd" d="{m.SYMBOL}"/>'
    else:
        mark = m.tile_art(edge=edge)
    body = (
        f'<g transform="translate({mark_at[0]:.2f} {mark_at[1]:.2f})">{mark}</g>'
        f'<path transform="translate({word_at[0]:.2f} {word_at[1]:.2f})" '
        f'fill="{word_colour}" d="{word}"/>'
    )
    return m._svg(body, w=round(w + 2, 2), h=round(h + 2, 2))


def brand_files():
    os.makedirs(BRAND, exist_ok=True)
    files = {
        "ember-symbol.svg": m.tile_svg(),
        "ember-symbol-dark.svg": m.tile_svg(edge=True),
        "ember-symbol-small.svg": m.tile_svg(edge=True, small=True),
        "ember-mark-ink.svg": m.mono_svg(INK),
        "ember-mark-cream.svg": m.mono_svg(m.CREAM),
        "ember-horizontal.svg": _lockup("horizontal", False, INK),
        "ember-horizontal-dark.svg": _lockup("horizontal", True, m.CREAM),
        "ember-horizontal-ink.svg": _lockup("horizontal", False, INK, mono=INK),
        "ember-horizontal-cream.svg": _lockup("horizontal", False, m.CREAM, mono=m.CREAM),
        "ember-stacked.svg": _lockup("stacked", False, INK),
        "ember-stacked-dark.svg": _lockup("stacked", True, m.CREAM),
    }
    for name, svg in files.items():
        with open(f"{BRAND}/{name}", "w", encoding="utf-8", newline="\n") as f:
            f.write(svg)
    m.render(m.tile_svg(), 1024).save(f"{BRAND}/ember-symbol-1024.png")
    return files


# --- the installer's images --------------------------------------------------

def _flat(image, background):
    """Inno Setup takes 24-bit bitmaps: no transparency."""
    base = Image.new("RGB", image.size, background)
    base.paste(image, mask=image.split()[3])
    return base


def installer_images():
    out = f"{APP}/windows/installer"
    os.makedirs(out, exist_ok=True)
    espresso = tuple(int(m.ESPRESSO[i:i + 2], 16) for i in (1, 3, 5))
    # The welcome page's tall image: the mark large, bare (its tile would
    # vanish into the same espresso), and the name under it.
    bare = m._svg(
        f'<path fill="{m.CREAM}" fill-rule="evenodd" d="{m.PERFS + m.BODY + m.SCREEN + m.PLAY}"/>'
        f'<path fill="{m.EMBER}" d="{m.BAND}"/>'
    )
    word, width = m.wordmark("MeTube Ember", FONT, 100)
    name = m._svg(f'<path transform="translate(1 64)" fill="{m.CREAM}" d="{word}"/>',
                  w=round(width + 2), h=66)
    for scale, (w, h) in [(1, (164, 314)), (2, (328, 628))]:
        mark = m.render(bare, round(w * 0.56))
        title = m.render(name, round(w * 0.76 * 66 / (width + 2)))
        panel = Image.new("RGBA", (w, h), espresso + (255,))
        top = round(h * 0.30)
        panel.alpha_composite(mark, ((w - mark.width) // 2, top))
        panel.alpha_composite(title, ((w - title.width) // 2, top + mark.height + round(h * 0.03)))
        _flat(panel, espresso).save(f"{out}/wizard_large_{scale}x.bmp")
    # The small image at the top right of every other page: the app icon.
    for scale, side in [(1, 55), (2, 110)]:
        _flat(m.render(m.tile_svg(edge=False, small=side < m.SMALL_BELOW), side),
              (255, 255, 255)).save(f"{out}/wizard_small_{scale}x.bmp")


# --- the usage guide -------------------------------------------------------

def _inline(svg, height):
    return svg.replace("<svg ", f'<svg height="{height}" ', 1)


def guide_html(files):
    """One page: the mark, its colours, its versions and how to use them."""
    def figure(name, label, bg, height=96):
        return (f'<figure style="background:{bg}"><div class="art">'
                f'{_inline(files[name], height)}</div><figcaption>{label}'
                f'<code>{name}</code></figcaption></figure>')

    light, dark = m.CREAM, m.ESPRESSO
    swatches = "".join(
        f'<div class="swatch"><span style="background:{hex_}"></span>'
        f'<b>{name}</b><code>{hex_}</code><small>{use}</small></div>'
        for name, hex_, use in [
            ("Espresso", m.ESPRESSO, "the tile; the name on light ground"),
            ("Cream", m.CREAM, "the window and play sign; the name on dark"),
            ("Ember", m.EMBER, "the title bar only, in every theme"),
        ]
    )
    return f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>MeTube Ember mark</title>
<style>
:root {{ --bg:#FBF6EE; --ink:#2B211B; --ink3:#8a7d73; --line:#e6ddd0; --card:#fffdf9; }}
@media (prefers-color-scheme: dark) {{ :root {{ --bg:#1A130F; --ink:#F3EBDF; --ink3:#a8998c; --line:#3a2e26; --card:#241B15; }} }}
* {{ box-sizing:border-box; }}
body {{ margin:0; background:var(--bg); color:var(--ink); font:15px/1.6 system-ui, "Segoe UI", sans-serif; }}
main {{ max-width:980px; margin:0 auto; padding:40px 16px 80px; }}
h1 {{ font-size:28px; margin:0 0 4px; }} h2 {{ font-size:19px; margin:44px 0 6px; padding-bottom:8px; border-bottom:1px solid var(--line); }}
p, li {{ max-width:68ch; }} .ar {{ direction:rtl; color:var(--ink3); }}
.grid {{ display:grid; grid-template-columns:repeat(auto-fill, minmax(220px, 1fr)); gap:16px; }}
figure {{ margin:0; border:1px solid var(--line); border-radius:14px; overflow:hidden; }}
.art {{ display:flex; align-items:center; justify-content:center; min-height:150px; padding:24px; }}
.art svg {{ max-width:100%; }}
figcaption {{ background:var(--card); color:var(--ink); padding:10px 14px; font-size:13px; border-top:1px solid var(--line); }}
figcaption code {{ display:block; color:var(--ink3); font-size:12px; }}
.swatch {{ display:grid; grid-template-columns:56px 1fr; column-gap:14px; align-items:center; padding:10px 0; }}
.swatch span {{ grid-row:span 3; width:56px; height:56px; border-radius:12px; border:1px solid var(--line); }}
.swatch code, .swatch small {{ color:var(--ink3); }}
ul.dont li::marker {{ content:"✕  "; color:#C25E2E; }}
table {{ border-collapse:collapse; }} td, th {{ text-align:start; padding:6px 16px 6px 0; border-bottom:1px solid var(--line); }}
</style></head>
<body><main>
<h1>MeTube Ember: the mark</h1>
<p>A window whose title bar glows. The bar is an ember, the play sign sits inside, and film perforations run down both sides, as on the Lite and Super icons. It is Ember's own title bar, enlarged.</p>
<p class="ar">نافذة يتوهج سقفها: شريط العنوان جمرة، والتشغيل في الداخل، وثقوب الفيلم على الجانبين كما في أيقونتي Lite وSuper.</p>

<h2>Colours · الألوان</h2>
{swatches}
<p>The ember does not follow the light or dark theme: it is the same in both, and nothing else in the mark is ember.</p>

<h2>The mark · الرمز</h2>
<div class="grid">
{figure("ember-symbol.svg", "In colour, on light ground", light, 128)}
{figure("ember-symbol-dark.svg", "With its light edge, on dark ground and dark taskbars", dark, 128)}
{figure("ember-symbol-small.svg", "Small cut, below 24 px: no perforations", light, 64)}
{figure("ember-mark-ink.svg", "One colour, ink", "#ffffff", 128)}
{figure("ember-mark-cream.svg", "One colour, cream, on dark", "#202020", 128)}
</div>

<h2>With the name · مع الاسم</h2>
<div class="grid">
{figure("ember-horizontal.svg", "Horizontal", light, 64)}
{figure("ember-horizontal-dark.svg", "Horizontal, on dark", dark, 64)}
{figure("ember-horizontal-ink.svg", "Horizontal, one colour", "#ffffff", 64)}
{figure("ember-horizontal-cream.svg", "Horizontal, one colour on dark", "#202020", 64)}
{figure("ember-stacked.svg", "Stacked", light, 140)}
{figure("ember-stacked-dark.svg", "Stacked, on dark", dark, 140)}
</div>
<p>The name is Tajawal Bold, drawn as outlines: it needs no font installed. Nothing else is set beside the mark in its place.</p>

<h2>Space and size · المسافة والمقاس</h2>
<p><b>Clear space:</b> keep free around the tile at least the height of its title bar (an eighth of the tile). Between the mark and the name the lockups keep their own gap; do not narrow it.</p>
<table>
<tr><th>Version</th><th>Smallest</th></tr>
<tr><td>The tile</td><td>16 px, in its small cut below 24 px</td></tr>
<tr><td>One colour mark</td><td>16 px (the tray), small cut below 24 px</td></tr>
<tr><td>Horizontal lockup</td><td>120 px wide</td></tr>
<tr><td>Stacked lockup</td><td>72 px wide</td></tr>
</table>

<h2>Do not · لا</h2>
<ul class="dont">
<li>recolour the title bar, or let it follow the theme;</li>
<li>put the tile on espresso or a dark taskbar without its light edge;</li>
<li>drop the perforations above 24 px, or keep them below it;</li>
<li>stretch, rotate, outline, or add shadows, gradients or glow;</li>
<li>set the name in another typeface, or retype it as live text.</li>
</ul>

<h2>Files · الملفات</h2>
<p>All of them, and the Windows icon, tray icons and installer images, come from one source: <code>tool/icons/ember_mark.py</code>. Rebuild with <code>python tool/make_icons.py --windows</code>.</p>
</main></body></html>
"""


def build():
    app_icon()
    tray_icons()
    files = brand_files()
    with open(f"{BRAND}/guide.html", "w", encoding="utf-8", newline="\n") as f:
        f.write(guide_html(files))
    installer_images()
    print("app icon, tray icons, installer images and", len(files), "brand files")
