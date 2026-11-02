"""Generates packages/mt_ui/lib/src/icons/mt_icons.dart from wahaj_icons.py.

    python tool/icons/make_mt_icons.py

Each icon becomes an SVG string with two colour slots, {ink} and {ember},
filled in at draw time from the theme. Strings rather than asset files: a
package's assets ship inside every app that depends on it, while an unused
Dart constant is dropped by the compiler, so the phone apps carry nothing.

flutter_svg ignores the pathLength attribute, so a dash pattern written
against pathLength is converted here to absolute lengths, measured on the
real path. Without this the search lens closes and the heart's gap moves.
"""
import math
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import wahaj_icons as w  # noqa: E402

OUT = HERE.parent.parent / "packages/mt_ui/lib/src/icons/mt_icons.dart"

# Alternatives that were drawn for comparison and not chosen.
SKIP = {"settings_8", "sliders", "knob", "download_line"}


def _arc_points(x1, y1, rx, ry, phi, large, sweep, x2, y2, steps=96):
    """Points along an SVG elliptical arc (endpoint to centre form)."""
    if rx == 0 or ry == 0:
        return [(x2, y2)]
    rx, ry = abs(rx), abs(ry)
    cp, sp = math.cos(math.radians(phi)), math.sin(math.radians(phi))
    dx, dy = (x1 - x2) / 2, (y1 - y2) / 2
    x1p, y1p = cp * dx + sp * dy, -sp * dx + cp * dy
    lam = x1p**2 / rx**2 + y1p**2 / ry**2
    if lam > 1:
        rx, ry = rx * math.sqrt(lam), ry * math.sqrt(lam)
    num = rx**2 * ry**2 - rx**2 * y1p**2 - ry**2 * x1p**2
    den = rx**2 * y1p**2 + ry**2 * x1p**2
    coef = math.sqrt(max(0.0, num / den)) * (-1 if large == sweep else 1)
    cxp, cyp = coef * rx * y1p / ry, -coef * ry * x1p / rx
    cx = cp * cxp - sp * cyp + (x1 + x2) / 2
    cy = sp * cxp + cp * cyp + (y1 + y2) / 2

    def angle(ux, uy, vx, vy):
        a = math.atan2(ux * vy - uy * vx, ux * vx + uy * vy)
        return a

    t1 = angle(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry)
    dt = angle((x1p - cxp) / rx, (y1p - cyp) / ry, (-x1p - cxp) / rx, (-y1p - cyp) / ry)
    if not sweep and dt > 0:
        dt -= 2 * math.pi
    elif sweep and dt < 0:
        dt += 2 * math.pi
    pts = []
    for i in range(1, steps + 1):
        t = t1 + dt * i / steps
        x, y = rx * math.cos(t), ry * math.sin(t)
        pts.append((cp * x - sp * y + cx, sp * x + cp * y + cy))
    return pts


def _cubic_points(p0, p1, p2, p3, steps=96):
    out = []
    for i in range(1, steps + 1):
        t = i / steps
        a = (1 - t) ** 3
        b = 3 * (1 - t) ** 2 * t
        c = 3 * (1 - t) * t**2
        d = t**3
        out.append((a * p0[0] + b * p1[0] + c * p2[0] + d * p3[0],
                    a * p0[1] + b * p1[1] + c * p2[1] + d * p3[1]))
    return out


def path_length(d):
    """The length of an SVG path, by flattening it finely enough for icons."""
    tokens = re.findall(r"[MmLlHhVvCcSsAaZz]|-?\d*\.?\d+(?:e-?\d+)?", d)
    i, cmd = 0, None
    x = y = sx = sy = 0.0
    last_ctrl = None
    total = 0.0

    def num():
        nonlocal i
        v = float(tokens[i])
        i += 1
        return v

    def walk(points):
        nonlocal total, x, y
        for px, py in points:
            total += math.hypot(px - x, py - y)
            x, y = px, py

    while i < len(tokens):
        if re.match(r"[A-Za-z]", tokens[i]):
            cmd = tokens[i]
            i += 1
            if cmd in "Zz":
                walk([(sx, sy)])
                last_ctrl = None
                continue
        rel = cmd.islower()
        ox, oy = (x, y) if rel else (0.0, 0.0)
        c = cmd.upper()
        if c == "M":
            x, y = num() + ox, num() + oy
            sx, sy = x, y
            cmd = "l" if rel else "L"
            last_ctrl = None
        elif c == "L":
            walk([(num() + ox, num() + oy)])
            last_ctrl = None
        elif c == "H":
            walk([(num() + ox, y)])
            last_ctrl = None
        elif c == "V":
            walk([(x, num() + oy)])
            last_ctrl = None
        elif c == "C":
            p1 = (num() + ox, num() + oy)
            p2 = (num() + ox, num() + oy)
            p3 = (num() + ox, num() + oy)
            walk(_cubic_points((x, y), p1, p2, p3))
            last_ctrl = p2
        elif c == "S":
            p1 = (2 * x - last_ctrl[0], 2 * y - last_ctrl[1]) if last_ctrl else (x, y)
            p2 = (num() + ox, num() + oy)
            p3 = (num() + ox, num() + oy)
            walk(_cubic_points((x, y), p1, p2, p3))
            last_ctrl = p2
        elif c == "A":
            rx, ry, phi = num(), num(), num()
            large, sweep = int(num()), int(num())
            ex, ey = num() + ox, num() + oy
            walk(_arc_points(x, y, rx, ry, phi, large, sweep, ex, ey))
            last_ctrl = None
        else:
            raise ValueError(f"unsupported path command {cmd}")
    return total


def _absolute_dashes(element):
    """Rewrites a pathLength-relative dash pattern in absolute units."""
    m = re.search(r'pathLength="([\d.]+)"', element)
    if not m:
        return element
    declared = float(m.group(1))
    if element.startswith("<circle"):
        r = float(re.search(r'\br="([\d.]+)"', element).group(1))
        real = 2 * math.pi * r
    else:
        real = path_length(re.search(r'\bd="([^"]+)"', element).group(1))
    k = real / declared

    def scale(attr):
        def repl(mm):
            vals = [float(v) * k for v in re.split(r"[\s,]+", mm.group(1).strip())]
            return f'{attr}="{" ".join(f"{v:.3f}" for v in vals)}"'
        return repl

    element = re.sub(r'stroke-dasharray="([^"]+)"', scale("stroke-dasharray"), element)
    element = re.sub(r'stroke-dashoffset="([^"]+)"', scale("stroke-dashoffset"), element)
    return re.sub(r'\s*pathLength="[\d.]+"', "", element)


def to_svg(body):
    body = re.sub(r"<(path|circle)[^>]*>", lambda m: _absolute_dashes(m.group(0)), body)
    body = body.replace('class="e"', 'fill="{ember}" stroke="none"')
    body = body.replace('class="f"', 'fill="{ink}" stroke="none"')
    body = body.replace('class="es"', 'stroke="{ember}"')
    attrs = w.STROKE.replace("currentColor", "{ink}")
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" {attrs}>{body}</svg>'


def camel(key):
    head, *rest = key.split("_")
    return head + "".join(p.capitalize() for p in rest)


def main():
    lines = [
        "// GENERATED by tool/icons/make_mt_icons.py from tool/icons/wahaj_icons.py.",
        "// Do not edit by hand: change the source and run the script again.",
        "",
        "import 'mt_icon_data.dart';",
        "",
        "/// The Wahaj icon set.",
        "abstract final class MTIcons {",
    ]
    for key, body in w.ICONS.items():
        if key in SKIP:
            continue
        if key in w.DOCS:
            lines.append("")
            lines += [f"  /// {line}" for line in w.DOCS[key].splitlines()]
        lines.append(f"  static const {camel(key)} = MTIconData('{key}', r'''{to_svg(body)}''');")
    lines.append("")
    names = ", ".join(camel(k) for k in w.ICONS if k not in SKIP)
    lines.append(f"  static const all = [{names}];")
    lines.append("}")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    # Formatted here so CI's format check passes without a second step.
    subprocess.run(["dart", "format", str(OUT)], check=True, shell=sys.platform == "win32")
    print(f"wrote {len(w.ICONS) - len(SKIP)} icons to {OUT}")


if __name__ == "__main__":
    main()
