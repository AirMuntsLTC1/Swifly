import shutil

path = 'lib/notifications_tab.dart'
if not __import__('os').path.exists(path):
    raise SystemExit("Run from Swifly project root.")

shutil.copyfile(path, path + '.bak_import')
with open(path) as f:
    content = f.read()

old = """import 'count_badge.dart';
import 'inbox_store.dart';"""

new = """import 'count_badge.dart';
import 'dm_theme.dart';
import 'inbox_store.dart';"""

if old in content:
    content = content.replace(old, new)
    with open(path, 'w') as f:
        f.write(content)
    print('✅ Added dm_theme.dart import to notifications_tab.dart')
else:
    print('⚠️ Pattern not found, please check imports.')
