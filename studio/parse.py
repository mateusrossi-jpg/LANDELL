with open('lib/ladder/ui/editor/ladder_editor_page.dart', 'r') as f:
    content = f.read()

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
    print(content[start_idx:end_idx])
