with open('lib/ladder/ui/editor/ladder_editor_page.dart', 'r') as f:
    content = f.read()
import re
match = re.search(r'Widget _buildComponentToolbox\(\) \{.*?(?=Widget _buildTrashDropZone\(\) \{)', content, re.DOTALL)
if match:
    print(match.group(0))
