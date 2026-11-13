#!/usr/bin/env python3
"""Deletes ALL mock data from the project. Run from the project root:
    python3 tools/remove_mock.py
After this the app can only show real database data."""
import os, re, shutil
shutil.rmtree('lib/mock', ignore_errors=True)
p = 'lib/app_bootstrap.dart'
s = open(p, encoding='utf-8').read()
s = re.sub(r"import 'mock/[^']*';\n", "", s)
s = s.replace("  if (kUseMockData) {\n    loadMockData();\n    return;\n  }\n", "")
s = s.replace("  if (kUseMockData) {\n    MockRealtime.start();\n    return;\n  }\n", "")
s = s.replace("import 'app_config.dart';\n", "")
open(p, 'w', encoding='utf-8').write(s)
p = 'lib/app_config.dart'
open(p, 'w', encoding='utf-8').write("/// Mock data was removed. The app only shows data from the real database.\nconst bool kUseMockData = false;\n")
print('Mock data removed. Run: flutter analyze')
