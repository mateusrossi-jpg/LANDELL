import re

with open('lib/ladder/ui/editor/ladder_editor_page.dart', 'r') as f:
    content = f.read()

# Add the import
import_stmt = "import 'widgets/ladder_node_visual.dart';\n"
if "import 'widgets/ladder_node_visual.dart';" not in content:
    content = content.replace("import 'widgets/variables_panel.dart';", "import 'widgets/variables_panel.dart';\n" + import_stmt)

# Regex to match `Widget _buildLadderNodeVisual(LadderNode node, bool isSelected) { ... }`
# We'll replace it with just:
# Widget _buildLadderNodeVisual(LadderNode node, bool isSelected) {
#   return LadderNodeVisual(node: node, isSelected: isSelected, runtime: _runtime);
# }
# Since regex parsing of brackets is hard, I will find the indices.

start_idx = content.find("Widget _buildLadderNodeVisual(LadderNode node, bool isSelected) {")
if start_idx != -1:
    open_brackets = 0
    end_idx = -1
    for i in range(start_idx, len(content)):
        if content[i] == '{':
            open_brackets += 1
        elif content[i] == '}':
            open_brackets -= 1
            if open_brackets == 0:
                end_idx = i + 1
                break
    
    if end_idx != -1:
        new_method = "Widget _buildLadderNodeVisual(LadderNode node, bool isSelected) {\n    return LadderNodeVisual(node: node, isSelected: isSelected, runtime: _runtime);\n  }"
        content = content[:start_idx] + new_method + content[end_idx:]

# Also remove _DiagonalLinePainter
start_painter = content.find("class _DiagonalLinePainter extends CustomPainter {")
if start_painter != -1:
    open_brackets = 0
    end_painter = -1
    for i in range(start_painter, len(content)):
        if content[i] == '{':
            open_brackets += 1
        elif content[i] == '}':
            open_brackets -= 1
            if open_brackets == 0:
                end_painter = i + 1
                break
    if end_painter != -1:
        content = content[:start_painter] + content[end_painter:]

with open('lib/ladder/ui/editor/ladder_editor_page.dart', 'w') as f:
    f.write(content)
print("Patched successfully")
