with open('build/web/main.dart.js', 'r', encoding='utf-8') as f:
    content = f.read()

pos = content.find('interceptorsByTag')
if pos != -1:
    print('interceptorsByTag:')
    print(content[pos:pos+400])

pos2 = content.find('leafTags')
if pos2 != -1:
    print('leafTags:')
    print(content[pos2:pos2+400])

# Search for A.aX in object literals
import re
for m in re.finditer(r'([a-zA-Z0-9_\$]+:\s*A\.aX\b)', content):
    p = m.start()
    print('MAPPING:', content[max(0, p-40):p+80])
