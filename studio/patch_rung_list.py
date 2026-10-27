with open('lib/ladder/ui/editor/ladder_editor_page.dart', 'r') as f:
    content = f.read()

# Add the import for RungList
import_stmt = "import 'widgets/rung_list.dart';\n"
if "import 'widgets/rung_list.dart';" not in content:
    content = content.replace("import 'widgets/variables_panel.dart';", "import 'widgets/variables_panel.dart';\n" + import_stmt)

start_idx = content.find("Widget _buildRungList() {")
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
        new_method = """Widget _buildRungListWrapper() {
    return RungList(
      project: _project,
      runtime: _runtime,
      networkValidationErrors: _networkValidationErrors,
      selectedRungIndex: _selectedRungIndex,
      selectedNodeIndex: _selectedNodeIndex,
      onDraggingStateChanged: (isDragging) {
        setState(() {
          _isDraggingNode = isDragging;
        });
      },
      onProjectChanged: () {
        setState(() {
          _saveProject();
        });
      },
      onNodeSelectionChanged: (rung, node) {
        setState(() {
          _selectedRungIndex = rung;
          _selectedNodeIndex = node;
        });
      },
      onNodeEditRequest: _showEditNodeBottomSheet,
      onNodeOptionsRequest: _showNodeOptionsBottomSheet,
      onComponentAddRequest: (rung, [insertIndex]) => _showComponentBottomSheet(rung, insertIndex),
    );
  }"""
        content = content[:start_idx] + new_method + content[end_idx:]

        # Also replace the usage of _buildRungList in build()
        content = content.replace("_buildRungList()", "_buildRungListWrapper()")

with open('lib/ladder/ui/editor/ladder_editor_page.dart', 'w') as f:
    f.write(content)
print("Patched successfully")
