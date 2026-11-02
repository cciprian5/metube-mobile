"""The Wahaj icon set: the single source of the app icons.

24-unit grid, 1.6 stroke, round caps and joins. Three motifs from the
identity: the gap (the launcher icon cuts its symbol out of the plate), the
ember dot (the accent, at most once per icon), and the transcript's time
dots. Class "e" = accent fill, "es" = accent stroke, "f" = ink fill.

Three shapes are borrowed: pause and download from Material Rounded
(Apache 2.0), and queue from Tabler's playlist (MIT, redrawn at our stroke).
"""
import math

STROKE = 'fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"'


def _gear(teeth, r_out, r_in, half_out, half_in, dot):
    """A gear outline: straight flanks, arcs on the tips and the roots."""
    step = 360 / teeth
    pts = []
    for i in range(teeth):
        c = i * step - 90
        pts.append(((r_in, c - half_in), (r_out, c - half_out), (r_out, c + half_out), (r_in, c + half_in)))

    def xy(r, a):
        return 12 + r * math.cos(math.radians(a)), 12 + r * math.sin(math.radians(a))

    d = []
    for i, (p1, p2, p3, p4) in enumerate(pts):
        x1, y1 = xy(*p1)
        x2, y2 = xy(*p2)
        x3, y3 = xy(*p3)
        x4, y4 = xy(*p4)
        d.append(("M" if i == 0 else "L") + f"{x1:.2f} {y1:.2f}")
        d.append(f"L{x2:.2f} {y2:.2f}")
        d.append(f"A{r_out} {r_out} 0 0 1 {x3:.2f} {y3:.2f}")
        d.append(f"L{x4:.2f} {y4:.2f}")
        nx, ny = xy(*pts[(i + 1) % teeth][0])
        d.append(f"A{r_in} {r_in} 0 0 1 {nx:.2f} {ny:.2f}")
    return f'<path d="{"".join(d)}z"/><circle class="e" cx="12" cy="12" r="{dot}"/>'


def _knob():
    """A volume knob: open scale at the bottom, an ember pointer from the centre."""
    dots = "".join(
        f'<circle class="f" cx="{12 + 10 * math.cos(math.radians(a)):.2f}" cy="{12 + 10 * math.sin(math.radians(a)):.2f}" r=".8"/>'
        for a in (135, 180, 225, 270, 315, 360, 405))
    px, py = 12 + 4.2 * math.cos(math.radians(-60)), 12 + 4.2 * math.sin(math.radians(-60))
    return ('<circle cx="12" cy="12" r="6.8"/>' + dots + f'<path class="es" d="M12 12L{px:.2f} {py:.2f}"/>')


ICONS = {
    # navigation
    "library": '<rect x="3.5" y="4" width="17" height="16" rx="3"/>'
               '<circle class="f" cx="6.6" cy="8" r=".85"/><circle class="f" cx="6.6" cy="12" r=".85"/><circle class="f" cx="6.6" cy="16" r=".85"/>'
               '<circle class="f" cx="17.4" cy="8" r=".85"/><circle class="f" cx="17.4" cy="12" r=".85"/><circle class="f" cx="17.4" cy="16" r=".85"/>'
               '<path d="M10.4 9.4v5.2l4.2-2.6z"/>',
    "favorite": '<path pathLength="100" stroke-dasharray="33 8 59 0" '
                'd="M12 19.6s-7.4-4.4-7.4-9.7A4 4 0 0 1 12 7.6a4 4 0 0 1 7.4 2.3c0 5.3-7.4 9.7-7.4 9.7z"/>',
    "favorite_on": '<path class="f" d="M12 19.6s-7.4-4.4-7.4-9.7A4 4 0 0 1 12 7.6a4 4 0 0 1 7.4 2.3c0 5.3-7.4 9.7-7.4 9.7z"/>',
    "offline": '<rect x="6.8" y="3.4" width="10.4" height="17.2" rx="2.6"/><path d="M12 7.6v6"/>'
               '<path d="M9.6 11.4L12 13.8l2.4-2.4"/><path d="M11 17.4h2"/>',
    "search": '<circle cx="10.5" cy="10.5" r="6.2" pathLength="100" stroke-dasharray="80 20" stroke-dashoffset="-97.5"/>'
              '<path d="M15.2 15.2l4.6 4.6"/><circle class="e" cx="14.88" cy="6.12" r="1.1"/>',
    "settings": _gear(6, 8.4, 6.1, 11, 19, 2.4),
    "settings_8": _gear(8, 8.6, 6.6, 8, 13.5, 2.4),
    "sliders": '<path d="M4 7h8.6"/><path d="M17.4 7H20"/><circle cx="15" cy="7" r="2.1"/>'
               '<path d="M4 12h2.6"/><path d="M11.4 12H20"/><circle class="e" cx="9" cy="12" r="2.1"/>'
               '<path d="M4 17h10.6"/><path d="M19.4 17H20"/><circle cx="17" cy="17" r="2.1"/>',
    "knob": _knob(),
    "server": '<rect x="4" y="4.4" width="16" height="6.2" rx="2"/><rect x="4" y="13.4" width="16" height="6.2" rx="2"/>'
              '<circle class="e" cx="7.6" cy="7.5" r="1.05"/><circle class="f" cx="7.6" cy="16.5" r="1.05"/>'
              '<path d="M11 7.5h5.4"/><path d="M11 16.5h5.4"/>',
    "plus": '<path d="M12 5.5v13"/><path d="M5.5 12h13"/>',
    "back": '<path d="M14.5 6l-6 6 6 6"/>',
    "forward": '<path d="M9.5 6l6 6-6 6"/>',
    "chevron_down": '<path d="M6.5 9.5l5.5 5.5 5.5-5.5"/>',
    "close": '<path d="M6.5 6.5l11 11"/><path d="M17.5 6.5l-11 11"/>',
    "check": '<path d="M5 12.5l4.5 4.5L19 7.5"/>',
    "grid": '<rect x="4" y="4" width="6.6" height="6.6" rx="1.7"/><rect x="13.4" y="4" width="6.6" height="6.6" rx="1.7"/>'
            '<rect x="4" y="13.4" width="6.6" height="6.6" rx="1.7"/><rect x="13.4" y="13.4" width="6.6" height="6.6" rx="1.7"/>',
    "table": '<rect x="3.5" y="4.5" width="17" height="15" rx="2.4"/><path d="M3.5 9.6h17"/><path d="M3.5 14.6h17"/>'
             '<path d="M9.4 9.6v9.9"/>',
    "stats": '<path d="M4.5 19.5h15"/><path d="M7.6 16.4v-4.2"/><path d="M12 16.4V7.6"/><path d="M16.4 16.4v-6.2"/>'
             '<circle class="e" cx="12" cy="4.4" r="1.1"/>',
    "sidebar_close": '<rect x="3.5" y="4.5" width="17" height="15" rx="2.6"/><path d="M9.4 4.5v15"/>'
                     '<path d="M15.6 9.4L13 12l2.6 2.6"/>',
    "sidebar_open": '<rect x="3.5" y="4.5" width="17" height="15" rx="2.6"/><path d="M9.4 4.5v15"/>'
                    '<path d="M13 9.4l2.6 2.6-2.6 2.6"/>',
    "list": '<circle class="f" cx="5" cy="7" r="1.05"/><circle class="f" cx="5" cy="12" r="1.05"/><circle class="f" cx="5" cy="17" r="1.05"/>'
            '<path d="M8.6 7h11"/><path d="M8.6 12h11"/><path d="M8.6 17h11"/>',
    # playback
    "play": '<path d="M8 5.6v12.8l10.2-6.4z"/>',
    "play_fill": '<path class="f" d="M8 5.6v12.8l10.2-6.4z"/>',
    "pause": '<g class="f"><path d="M8 19c1.1 0 2-.9 2-2V7c0-1.1-.9-2-2-2s-2 .9-2 2v10c0 1.1.9 2 2 2zm6-12v10c0 1.1.9 2 2 2s2-.9 2-2V7c0-1.1-.9-2-2-2s-2 .9-2 2z"/></g>',
    "next": '<path d="M6.5 6.2v11.6l8.6-5.8z"/><path d="M18 6v12"/>',
    "prev": '<path d="M17.5 6.2v11.6l-8.6-5.8z"/><path d="M6 6v12"/>',
    "shuffle": '<path d="M4 7h3.2c2 0 3.2 1 4.2 2.6l1.6 2.8c1 1.6 2.2 2.6 4.2 2.6H20"/><path d="M17.6 12.6L20 15l-2.4 2.4"/>'
               '<path d="M4 17h3.2c1.1 0 2-.3 2.8-.9"/><path d="M13.9 7.9c.8-.6 1.7-.9 2.8-.9H20"/><path d="M17.6 4.6L20 7l-2.4 2.4"/>',
    "repeat": '<path d="M5 11.2V9.6A2.6 2.6 0 0 1 7.6 7H18.4"/><path d="M16 4.6L18.4 7 16 9.4"/>'
              '<path d="M19 12.8v1.6a2.6 2.6 0 0 1-2.6 2.6H5.6"/><path d="M8 19.4L5.6 17 8 14.6"/>',
    "repeat_one": '<path d="M5 11.2V9.6A2.6 2.6 0 0 1 7.6 7H18.4"/><path d="M16 4.6L18.4 7 16 9.4"/>'
                  '<path d="M19 12.8v1.6a2.6 2.6 0 0 1-2.6 2.6H5.6"/><path d="M8 19.4L5.6 17 8 14.6"/>'
                  '<path class="es" d="M11.2 10.9l1.3-.9v4.4"/>',
    "stop_after": '<path d="M4 12h10.6"/><path d="M11.4 8.6L14.8 12l-3.4 3.4"/><path d="M19 6v12"/>',
    "captions": '<rect x="3" y="5.5" width="18" height="13" rx="2.8"/>'
                '<path d="M10.6 10.3a2.1 2.1 0 1 0 0 3.4"/><path d="M16.6 10.3a2.1 2.1 0 1 0 0 3.4"/>',
    "sort": '<path d="M4.5 7h9"/><path d="M4.5 12h6.5"/><path d="M4.5 17h4"/>'
            '<path d="M17.5 6v12"/><path d="M15 15.6l2.5 2.5 2.5-2.5"/>',
    "volume": '<path d="M4.5 9.6h3l4.2-3.6v12l-4.2-3.6h-3z"/><path d="M15.2 9.4a3.6 3.6 0 0 1 0 5.2"/><path d="M17.8 6.8a7.2 7.2 0 0 1 0 10.4"/>',
    "queue": '<circle cx="14" cy="17" r="3"/><path d="M17 17V4h4"/><path d="M13 5H3"/><path d="M3 9h10"/><path d="M9 13H3"/>',
    "transcript": '<circle class="e" cx="5" cy="7" r="1.25"/><circle class="f" cx="5" cy="12" r="1.05"/><circle class="f" cx="5" cy="17" r="1.05"/>'
                  '<path d="M8.6 7h11"/><path d="M8.6 12h8.6"/><path d="M8.6 17h5.8"/>',
    "pip": '<rect x="3.5" y="5" width="17" height="14" rx="2.6"/><rect class="e" x="12" y="11.6" width="6" height="4.6" rx="1.1"/>',
    "theater": '<rect x="2.8" y="7" width="18.4" height="10" rx="2.2"/>',
    "fullscreen": '<path d="M4 9V5.6A1.6 1.6 0 0 1 5.6 4H9"/><path d="M15 4h3.4A1.6 1.6 0 0 1 20 5.6V9"/>'
                  '<path d="M20 15v3.4a1.6 1.6 0 0 1-1.6 1.6H15"/><path d="M9 20H5.6A1.6 1.6 0 0 1 4 18.4V15"/>',
    "collapse": '<path d="M9 4v3.4A1.6 1.6 0 0 1 7.4 9H4"/><path d="M20 9h-3.4A1.6 1.6 0 0 1 15 7.4V4"/>'
                '<path d="M15 20v-3.4a1.6 1.6 0 0 1 1.6-1.6H20"/><path d="M4 15h3.4A1.6 1.6 0 0 1 9 16.6V20"/>',
    "headphones": '<path d="M4.6 15.2v-3a7.4 7.4 0 0 1 14.8 0v3"/><rect x="3.8" y="13.6" width="4.4" height="6.4" rx="1.8"/>'
                  '<rect x="15.8" y="13.6" width="4.4" height="6.4" rx="1.8"/>',
    "reading": '<path d="M12 6.6c-1.8-1.3-4.4-2-7.5-2V18c3.1 0 5.7.7 7.5 2 1.8-1.3 4.4-2 7.5-2V4.6c-3.1 0-5.7.7-7.5 2z"/><path d="M12 6.6V20"/>',
    # actions
    # The phones' filled Material download, like pause.
    "download": '<g class="f"><path d="M16.59 9H15V4c0-.55-.45-1-1-1h-4c-.55 0-1 .45-1 1v5H7.41c-.89 0-1.34 1.08-.71 1.71l4.59 4.59c.39.39 1.02.39 1.41 0l4.59-4.59c.63-.63.19-1.71-.7-1.71zM5 19c0 .55.45 1 1 1h12c.55 0 1-.45 1-1s-.45-1-1-1H6c-.55 0-1 .45-1 1z"/></g>',
    "download_line": '<path d="M12 4v10"/><path d="M8 10.5l4 4 4-4"/><path d="M4.5 19h5.2"/><path d="M14.3 19h5.2"/>'
                '<circle class="e" cx="12" cy="19" r="1.25"/>',
    "save_to": '<path d="M3.5 7.5A2 2 0 0 1 5.5 5.5h4l2 2h7a2 2 0 0 1 2 2v7.5a2 2 0 0 1-2 2h-13a2 2 0 0 1-2-2z"/>'
               '<path d="M12 10v5"/><path d="M9.8 12.8L12 15l2.2-2.2"/>',
    "tags": '<path d="M4 5.6A1.6 1.6 0 0 1 5.6 4H11l9 9-7 7-9-9z"/><circle class="e" cx="8.3" cy="8.3" r="1.35"/>',
    "link": '<path d="M11 7.6l1.3-1.3a3.6 3.6 0 0 1 5.1 5.1L16.1 12.7"/><path d="M13 16.4l-1.3 1.3a3.6 3.6 0 0 1-5.1-5.1L7.9 11.3"/>'
            '<path d="M10 14l4-4"/>',
    "addlink": '<path d="M11 7.6l1.3-1.3a3.6 3.6 0 0 1 5.1 5.1L16.1 12.7"/><path d="M13 16.4l-1.3 1.3a3.6 3.6 0 0 1-5.1-5.1L7.9 11.3"/>'
               '<path d="M10 14l4-4"/><path class="es" d="M18.6 15.9v5.4"/><path class="es" d="M15.9 18.6h5.4"/>',
    "external": '<path d="M13.6 4.8H19.2v5.6"/><path d="M19 5l-8 8"/><path d="M17 13.8v4a1.6 1.6 0 0 1-1.6 1.6H6.2A1.6 1.6 0 0 1 4.6 17.8V8.6A1.6 1.6 0 0 1 6.2 7h4"/>',
    "copy": '<rect x="8.6" y="8.6" width="11" height="11" rx="2.2"/><path d="M15.4 5.6v-.2A1.8 1.8 0 0 0 13.6 3.6H5.4A1.8 1.8 0 0 0 3.6 5.4v8.2a1.8 1.8 0 0 0 1.8 1.8h.2"/>',
    "trash": '<path d="M5 7h14"/><path d="M10 4.4h4"/><path d="M7 7l.8 11.2A1.8 1.8 0 0 0 9.6 20h4.8a1.8 1.8 0 0 0 1.8-1.8L17 7"/>'
             '<path d="M10.4 11v5"/><path d="M13.6 11v5"/>',
    "folder": '<path d="M3.5 7.5A2 2 0 0 1 5.5 5.5h4l2 2h7a2 2 0 0 1 2 2v7.5a2 2 0 0 1-2 2h-13a2 2 0 0 1-2-2z"/>',
    # settings sections
    "swap": '<path d="M7 18.5v-13"/><path d="M4.2 8.2L7 5.4l2.8 2.8"/><path d="M17 5.5v13"/><path d="M14.2 15.8l2.8 2.8 2.8-2.8"/>',
    "globe": '<circle cx="12" cy="12" r="8.2"/><path d="M3.9 12h16.2"/>'
             '<path d="M12 3.8c2.2 2.3 3.3 5 3.3 8.2s-1.1 5.9-3.3 8.2c-2.2-2.3-3.3-5-3.3-8.2s1.1-5.9 3.3-8.2z"/>',
    "more": '<circle class="f" cx="6" cy="12" r="1.5"/><circle class="f" cx="12" cy="12" r="1.5"/><circle class="f" cx="18" cy="12" r="1.5"/>',
    "cookie": '<path d="M19.8 12.6a7.9 7.9 0 1 1-8.4-8.4 2.7 2.7 0 0 0 3.2 3.2 2.7 2.7 0 0 0 3 3 2.6 2.6 0 0 0 2.2 2.2z"/>'
              '<circle class="f" cx="9" cy="10" r="1"/><circle class="e" cx="14.6" cy="14.6" r="1.1"/><circle class="f" cx="9.4" cy="15.4" r="1"/>',
    "subscriptions": '<path d="M5 4.8a14.2 14.2 0 0 1 14.2 14.2"/><path d="M5 10.4a8.6 8.6 0 0 1 8.6 8.6"/><circle class="e" cx="6.2" cy="17.8" r="1.6"/>',
    "playback": '<circle cx="12" cy="12" r="8.4"/><path d="M10.2 9v6l4.8-3z"/>',
    "monitor": '<rect x="3.5" y="4.5" width="17" height="11.5" rx="2"/><path d="M9 20h6"/><path d="M12 16v4"/>',
    "appearance": '<circle cx="12" cy="12" r="8"/><path class="f" d="M12 4a8 8 0 0 1 0 16z"/>',
    "backup": '<path d="M7.6 18.4a4 4 0 0 1-.6-7.95A5.5 5.5 0 0 1 17.6 9.7a4.4 4.4 0 0 1-1 8.7z"/><path d="M12 16.2v-5"/><path d="M9.8 13.2L12 11l2.2 2.2"/>',
    "info": '<circle cx="12" cy="12" r="8.4"/><path d="M12 11v5.4"/><circle class="f" cx="12" cy="7.9" r="1.05"/>',
    # phones: what Lite and Super show that the computer does not
    "share": '<circle cx="17.4" cy="5.8" r="2.3"/><circle cx="6.6" cy="12" r="2.3"/><circle cx="17.4" cy="18.2" r="2.3"/>'
             '<path d="M8.6 10.9l6.8-3.9"/><path d="M8.6 13.1l6.8 3.9"/>',
    "more_vert": '<circle class="f" cx="12" cy="5.6" r="1.5"/><circle class="f" cx="12" cy="12" r="1.5"/><circle class="f" cx="12" cy="18.4" r="1.5"/>',
    "refresh": '<path d="M19 12.4a7 7 0 1 1-2.2-5.4"/><path d="M19.2 4.6v3.8h-3.8"/>',
    "music": '<path d="M9.4 17.4V6.2l9.2-2v11"/><circle cx="7" cy="17.4" r="2.4"/><circle cx="16.2" cy="15.2" r="2.4"/>',
    "video": '<rect x="3.6" y="5.6" width="16.8" height="12.8" rx="2.4"/><path d="M10.2 9.4v5.2l4.4-2.6z"/>',
    "cloud": '<path d="M7.4 18.2h9.7a3.8 3.8 0 0 0 .4-7.58 5.3 5.3 0 0 0-10.2 1.2A3.2 3.2 0 0 0 7.4 18.2z"/><circle class="e" cx="12.4" cy="14.3" r="1.7"/>',
    "cloud_check": '<path d="M7.4 18.2h9.7a3.8 3.8 0 0 0 .4-7.58 5.3 5.3 0 0 0-10.2 1.2A3.2 3.2 0 0 0 7.4 18.2z"/><path d="M9.6 14.2l1.8 1.8 3.4-3.4"/>',
    "cloud_wait": '<path d="M7.4 18.2h9.7a3.8 3.8 0 0 0 .4-7.58 5.3 5.3 0 0 0-10.2 1.2A3.2 3.2 0 0 0 7.4 18.2z"/><circle class="f" cx="9.6" cy="14.6" r=".9"/>'
                  '<circle class="f" cx="12.4" cy="14.6" r=".9"/><circle class="e" cx="15.2" cy="14.6" r=".9"/>',
    "cloud_off": '<path d="M7.4 18.2h9.7a3.8 3.8 0 0 0 .4-7.58 5.3 5.3 0 0 0-10.2 1.2A3.2 3.2 0 0 0 7.4 18.2z"/><path d="M4.4 4.4l15.2 15.2"/>',
    "lock": '<rect x="5.5" y="10.5" width="13" height="9.5" rx="2.2"/><path d="M8.5 10.5V8a3.5 3.5 0 0 1 7 0v2.5"/>'
            '<circle class="e" cx="12" cy="15.2" r="1.25"/>',
    "unlock": '<rect x="5.5" y="10.5" width="13" height="9.5" rx="2.2"/><path d="M8.5 10.5V8a3.5 3.5 0 0 1 6.8-1.2"/>'
              '<circle class="e" cx="12" cy="15.2" r="1.25"/>',
    "link_off": '<path d="M11 7.6l1.3-1.3a3.6 3.6 0 0 1 5.1 5.1L16.1 12.7"/><path d="M13 16.4l-1.3 1.3a3.6 3.6 0 0 1-5.1-5.1L7.9 11.3"/>'
                '<path d="M4.6 4.6l14.8 14.8"/>',
    "pin": '<path d="M9.2 4.2h5.6"/><path d="M10 4.2v5.2L7.4 13h9.2L14 9.4V4.2"/><path d="M12 13v6.8"/>',
    "pin_on": '<path d="M9.2 4.2h5.6"/><path class="f" d="M10 4.2v5.2L7.4 13h9.2L14 9.4V4.2z"/><path d="M12 13v6.8"/>',
    "help": '<circle cx="12" cy="12" r="8.4"/><path d="M9.7 9.6a2.4 2.4 0 1 1 3.3 2.2c-.6.3-1 .8-1 1.5v.5"/>'
            '<circle class="f" cx="12" cy="16.6" r="1.05"/>',
    "alert": '<circle cx="12" cy="12" r="8.4"/><path d="M12 7.6V13"/><circle class="f" cx="12" cy="16.1" r="1.05"/>',
    "edit": '<path d="M14.6 5.6l3.8 3.8L9 18.8l-4.6.8.8-4.6z"/><path d="M12.8 7.4l3.8 3.8"/>',
    "shield": '<path d="M12 3.8l6.6 2.6v5c0 4.2-2.8 7.4-6.6 8.8-3.8-1.4-6.6-4.6-6.6-8.8v-5z"/>'
              '<circle class="e" cx="12" cy="11.6" r="1.3"/>',
    "sparkle": '<path d="M12 4.2c.5 3.9 2 5.4 5.8 5.8-3.8.5-5.3 2-5.8 5.8-.5-3.8-2-5.3-5.8-5.8 3.8-.4 5.3-1.9 5.8-5.8z"/>'
               '<path d="M18 16v3.6"/><path d="M16.2 17.8h3.6"/>',
    "select_all": '<rect x="4" y="4" width="16" height="16" rx="3" stroke-dasharray="2.4 2.6"/><path d="M8.4 12.2l2.6 2.6 4.8-5"/>',
    "clock": '<circle cx="12" cy="12" r="8.4"/><path d="M12 7.6V12l3 1.8"/>',
    "code": '<path d="M8.6 7.4L4 12l4.6 4.6"/><path d="M15.4 7.4L20 12l-4.6 4.6"/><path d="M13.2 5.8l-2.4 12.4"/>',
    "mail": '<rect x="3.6" y="5.6" width="16.8" height="12.8" rx="2.4"/><path d="M4.4 7.2l7.6 5.6 7.6-5.6"/>',
    "bug": '<rect x="7.4" y="7.8" width="9.2" height="11.6" rx="4.6"/><path d="M12 11.4v8"/><path d="M9.4 5.2l1.2 2.2"/>'
           '<path d="M14.6 5.2l-1.2 2.2"/><path d="M7.4 12.6h-3"/><path d="M16.6 12.6h3"/><path d="M7.6 16.6L5 18.2"/><path d="M16.4 16.6l2.6 1.6"/>',
    "phone": '<rect x="6.8" y="3.4" width="10.4" height="17.2" rx="2.6"/><path d="M11 17.4h2"/>',
    "phone_off": '<rect x="6.8" y="3.4" width="10.4" height="17.2" rx="2.6"/><path d="M10 8.6l4 4"/><path d="M14 8.6l-4 4"/><path d="M11 17.4h2"/>',
    "folder_off": '<path d="M3.5 7.5A2 2 0 0 1 5.5 5.5h4l2 2h7a2 2 0 0 1 2 2v7.5a2 2 0 0 1-2 2h-13a2 2 0 0 1-2-2z"/><path d="M4.4 4.4l15.2 15.2"/>',
    "text_size": '<path d="M4 18.4L9 6.4l5 12"/><path d="M5.8 14.4h6.4"/><path d="M15 18.4l2.6-6.4 2.6 6.4"/><path d="M15.9 16.4h3.4"/>',
    "upload": '<path d="M13.6 3.6H7.2a1.8 1.8 0 0 0-1.8 1.8v13.2a1.8 1.8 0 0 0 1.8 1.8h9.6a1.8 1.8 0 0 0 1.8-1.8V8.6z"/>'
              '<path d="M13.6 3.6v5h5"/><path d="M12 17v-5.4"/><path d="M9.8 13.8L12 11.6l2.2 2.2"/>',
    "chevron_up": '<path d="M6.5 14.5L12 9l5.5 5.5"/>',
    "captions_off": '<rect x="3" y="5.5" width="18" height="13" rx="2.8"/>'
                    '<path d="M10.6 10.3a2.1 2.1 0 1 0 0 3.4"/><path d="M16.6 10.3a2.1 2.1 0 1 0 0 3.4"/><path d="M4 4l16 16"/>',
    "bolt": '<path d="M13.2 3.6L6 13.4h5.4l-.8 7 7.4-9.8h-5.4z"/>',
    "back10": '<path d="M5.4 9.6A7.4 7.4 0 1 1 4.6 13"/><path d="M5.2 5.4v4.4h4.4"/><path d="M10 10.4v5.2"/>'
              '<rect x="12.4" y="10.4" width="3.4" height="5.2" rx="1.7"/>',
    "forward10": '<path d="M18.6 9.6A7.4 7.4 0 1 0 19.4 13"/><path d="M18.8 5.4v4.4h-4.4"/><path d="M8.2 10.4v5.2"/>'
                 '<rect x="10.6" y="10.4" width="3.4" height="5.2" rx="1.7"/>',
    "paste": '<rect x="5.4" y="5" width="13.2" height="15.4" rx="2.2"/><rect x="9" y="3.4" width="6" height="3.4" rx="1.2"/>'
             '<path d="M9 12h6"/><path d="M9 15.6h4"/>',
    "queue_add": '<path d="M13 5H3"/><path d="M3 9h10"/><path d="M9 13H3"/><path class="es" d="M17 12v8"/><path class="es" d="M13 16h8"/>',
    "queue_remove": '<path d="M13 5H3"/><path d="M3 9h10"/><path d="M9 13H3"/><path d="M13 16h8"/>',
    # window frame
    "win_min": '<path d="M6 12h12"/>',
    "win_max": '<rect x="6" y="6" width="12" height="12" rx="1.6"/>',
    "win_close": '<path d="M6.5 6.5l11 11"/><path d="M17.5 6.5l-11 11"/>',
}

# Notes carried into the generated catalogue, for icons whose use is not
# plain from the name.
DOCS = {
    "globe": "The server's addresses (at home and away): the network the server is\n"
             "reached across. Its own glyph, apart from [swap], which is the sync.",
    "more": "More actions behind a menu: three dots across.",
    "more_vert": "More actions behind a menu on a phone: three dots down.",
}

CSS = ".e{fill:var(--acc);stroke:none}.f{fill:currentColor;stroke:none}.es{stroke:var(--acc)}"


def icon(key, size=20, cls="", stroke=None):
    body = ICONS[key]
    attrs = STROKE if stroke is None else STROKE.replace('stroke-width="1.6"', f'stroke-width="{stroke}"')
    return (f'<svg class="wi {cls}" viewBox="0 0 24 24" width="{size}" height="{size}" {attrs} '
            f'style="flex:none;vertical-align:middle">{body}</svg>')
