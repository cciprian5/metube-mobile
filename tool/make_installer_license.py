"""Writes the installer's license pages from the repository's LICENSE.

Each language gets a short preface in its own words (the terms in plain
language, the privacy line, where the third-party licenses are, who makes
the app), then the GNU GPL v3 itself, in English, which is the text that
binds. RTF rather than text so the Arabic preface reads right to left while
the license under it reads left to right.

Run after changing a preface:
    python tool/make_installer_license.py
A test checks that the pages still carry LICENSE word for word.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'apps' / 'metube_desktop' / 'windows' / 'installer'

DEVELOPER = {'en': 'Yasir Sagheer', 'ar': 'ياسر صغير'}
PAGE = 'https://sagheerys.github.io/metube-mobile/'
SOURCE = 'https://github.com/sagheerys/metube-mobile'

PREFACE = {
    'en': [
        ('h', 'Terms of use and license'),
        ('p', 'MeTube Ember is free, open-source software by '
              f'{DEVELOPER["en"]}, made to work with a MeTube server you run '
              'yourself.'),
        ('b', 'License: the GNU General Public License, version 3, below. '
              'You may use, copy, change and share the program under its '
              'terms.'),
        ('b', 'No warranty: the program comes as it is, without any '
              'warranty, as sections 15 and 16 of the license say.'),
        ('b', 'Your privacy: the program collects nothing about you and '
              'sends nothing about you anywhere. It talks to your server, to '
              'the sites your clips come from (for their pictures and '
              'transcripts) and to GitHub (to check for updates).'),
        ('b', 'Content: you are responsible for what you download, and for '
              "respecting its owners' rights and the terms of the sites it "
              'comes from.'),
        ('b', 'Third-party libraries and their licenses: in the app, under '
              'Settings → About → Open-source licenses.'),
        ('p', f'Developer: {DEVELOPER["en"]}'),
        ('l', f'Project page: {PAGE}'),
        ('l', f'Source and issues: {SOURCE}'),
    ],
    'ar': [
        ('h', 'شروط الاستخدام والرخصة'),
        ('p', 'MeTube Ember برنامج حرّ مفتوح المصدر من '
              f'{DEVELOPER["ar"]}، يعمل مع سيرفر MeTube الذي تشغّله أنت.'),
        ('b', 'الرخصة: رخصة جنو العمومية العامة، الإصدار الثالث (GNU GPL v3)، '
              'ونصها أدناه. لك أن تستعمل البرنامج وتنسخه وتعدّله وتنشره '
              'بشروطها، والنص الإنجليزي هو المعتمد.'),
        ('b', 'بلا ضمان: يُقدَّم البرنامج كما هو، دون أي ضمان، كما تنص '
              'المادتان 15 و16 من الرخصة.'),
        ('b', 'خصوصيتك: لا يجمع البرنامج أي بيانات عنك ولا يرسلها إلى أي '
              'جهة. يتصل بسيرفرك، وبالمواقع التي تأتي منها مقاطعك لجلب صورها '
              'ونصوصها، وبـGitHub للتحقق من التحديثات.'),
        ('b', 'المحتوى: أنت المسؤول عمّا تنزّله، وعن احترام حقوق أصحابه '
              'وشروط المواقع التي يأتي منها.'),
        ('b', 'مكتبات الطرف الثالث ورخصها: في البرنامج نفسه، من الإعدادات '
              '← عن التطبيق ← تراخيص البرمجيات مفتوحة المصدر.'),
        ('p', f'المطوّر: {DEVELOPER["ar"]}'),
        ('l', f'صفحة المشروع: {PAGE}'),
        ('l', f'المصدر والبلاغات: {SOURCE}'),
    ],
}


def escape(text: str) -> str:
    """RTF for plain text: braces and backslashes escaped, anything past
    ASCII as a Unicode escape with a question mark for old readers."""
    out = []
    for ch in text:
        code = ord(ch)
        if ch in '\\{}':
            out.append('\\' + ch)
        elif code > 127:
            out.append(f'\\u{code if code < 32768 else code - 65536}?')
        else:
            out.append(ch)
    return ''.join(out)


def page(lang: str, license_text: str) -> str:
    rtl = lang == 'ar'
    para = r'\pard\rtlpar\qr' if rtl else r'\pard\ltrpar\ql'
    run = r'\rtlch\f1' if rtl else r'\ltrch\f0'
    lines = [
        r'{\rtf1\ansi\ansicpg1252\deff0\uc1'
        r'{\fonttbl{\f0\fswiss\fcharset0 Segoe UI;}'
        r'{\f1\fswiss\fcharset178 Segoe UI;}'
        r'{\f2\fmodern\fcharset0 Consolas;}}',
        r'\viewkind4',
    ]
    for kind, text in PREFACE[lang]:
        body = escape(text)
        if kind == 'h':
            lines.append(f'{para}\\sa160{run}\\fs24\\b {body}\\b0\\par')
        elif kind == 'b':
            lines.append(f'{para}\\sa100{run}\\fs19 \\u8226? {body}\\par')
        elif kind == 'l':
            lines.append(f'{para}\\sa40{run}\\fs19 {body}\\par')
        else:
            lines.append(f'{para}\\sa120{run}\\fs19 {body}\\par')
    lines.append(r'\pard\ltrpar\ql\sa0\ltrch\f0\fs19\par')
    # The license as it is, line for line, left to right whatever the
    # wizard's language.
    for line in license_text.split('\n'):
        lines.append(r'\pard\ltrpar\ql\sa0\ltrch\f2\fs16 ' + escape(line) + r'\par')
    lines.append('}')
    return '\r\n'.join(lines) + '\r\n'


def main() -> None:
    license_text = (ROOT / 'LICENSE').read_text(encoding='utf-8').replace('\r\n', '\n').rstrip('\n')
    for lang in ('en', 'ar'):
        target = OUT / f'license_{lang}.rtf'
        target.write_bytes(page(lang, license_text).encode('ascii'))
        print('wrote', target.relative_to(ROOT))


if __name__ == '__main__':
    main()
