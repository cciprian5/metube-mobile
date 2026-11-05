# -*- coding: utf-8 -*-
"""Report localization keys that no app shows, and which app shows the rest.

**Why a tool rather than a test.** The `arb_parity_test.dart` guard lives in
`mt_ui`, which deliberately knows nothing about the apps, so it cannot decide
that a key is dead when it cannot see who uses it. This script stands above
the whole repository instead.

**Three apps share one pair of arb files**: MeTube Lite, MeTube Super and the
Windows app, MeTube Ember. A key one of them shows is alive even if the other
two never do, so each key is credited to the code that names it:

* `packages/*/lib` - shared, reaches every app that uses the package;
* `apps/<app>/lib` - that app alone;
* tests - not a user. A key only a test names is a sentence nobody sees.

**When to run it:** before translating into a new language, and before any
release. One dead key is a sentence translated into **every** language that
nobody ever sees.

    python tool/dead-l10n.py            # dead keys, and a count per app
    python tool/dead-l10n.py --only ember   # the keys only Ember shows

Always exits 0 - a report, not a gate: deleting is a human decision, and a key
may have been added ahead of a screen still being built.
"""

import io
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EN_ARB = os.path.join(ROOT, 'packages', 'mt_ui', 'lib', 'src', 'l10n',
                      'app_en.arb')
SKIP_DIRS = {'.git', '.dart_tool', 'build', '.design', 'node_modules',
             '.agents'}

# The folder under `apps/` of each app, by the name the report uses.
APPS = {'lite': 'metube_lite', 'super': 'metube_super',
        'ember': 'metube_desktop'}
SHARED = 'shared'
TESTS = 'tests'


def user_of(rel):
    """Who a source file speaks for: an app, the shared packages, or only
    the tests. None for code outside those (tools, third-party copies)."""
    parts = rel.split('/')
    if any(p in ('test', 'integration_test') for p in parts):
        return TESTS
    if len(parts) > 2 and parts[0] == 'apps' and parts[2] == 'lib':
        for name, folder in APPS.items():
            if parts[1] == folder:
                return name
    if len(parts) > 2 and parts[0] == 'packages' and parts[2] == 'lib':
        return SHARED
    return None


def dart_sources():
    """(user, text) for every Dart source except the l10n folder itself,
    which holds the generated code and the key definitions."""
    for base, dirs, files in os.walk(ROOT):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for name in files:
            if not name.endswith('.dart') or name.endswith('.g.dart'):
                continue
            path = os.path.join(base, name)
            rel = os.path.relpath(path, ROOT).replace(os.sep, '/')
            if '/l10n/' in '/' + rel:
                continue
            user = user_of(rel)
            if user is None:
                continue
            try:
                yield user, io.open(path, encoding='utf-8').read()
            except (IOError, UnicodeDecodeError):
                continue


def users_of_keys(keys):
    """For each key, the set of users whose code names it."""
    texts = {}
    for user, text in dart_sources():
        texts.setdefault(user, []).append(text)
    joined = {user: '\n'.join(parts) for user, parts in texts.items()}
    found = {}
    for key in keys:
        pattern = re.compile(r'\b' + re.escape(key) + r'\b')
        found[key] = {u for u, text in joined.items() if pattern.search(text)}
    return found


def label(users):
    """A short name for who shows a key; SHARED outranks any one app."""
    shown = users - {TESTS}
    if SHARED in shown:
        return SHARED
    return '+'.join(sorted(shown))


def main(argv):
    only = None
    if len(argv) == 2 and argv[0] == '--only' and argv[1] in APPS:
        only = argv[1]
    elif argv:
        sys.stderr.write('usage: dead-l10n.py [--only %s]\n'
                         % '|'.join(APPS))
        return 0

    doc = json.loads(io.open(EN_ARB, encoding='utf-8').read())
    keys = [k for k in doc if not k.startswith('@')]
    found = users_of_keys(keys)
    # Arabic values must print on a console whose code page is not UTF-8.
    out = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

    if only:
        mine = [k for k in keys if label(found[k]) == only]
        out.write('keys only %s shows: %d\n' % (only, len(mine)))
        for key in mine:
            out.write('  %s = %s\n' % (key, str(doc[key])[:70]))
        return 0

    dead = [k for k in keys if not label(found[k])]
    out.write('keys: %d - unused: %d\n' % (len(keys), len(dead)))
    counts = {}
    for key in keys:
        name = label(found[key])
        if name:
            counts[name] = counts.get(name, 0) + 1
    out.write('shown by: %s\n' % ' . '.join(
        '%s %d' % (name, counts[name]) for name in sorted(counts)))
    for key in dead:
        why = ' (only a test names it)' if found[key] else ''
        out.write('  %s = %s%s\n' % (key, str(doc[key])[:70], why))
    if not dead:
        out.write('clean: every key has a user.\n')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
