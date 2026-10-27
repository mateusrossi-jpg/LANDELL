with open('lib/ladder/ui/editor/ladder_editor_page.dart', 'r') as f:
    content = f.read()

target = """        );
      }
      
  Widget buildRungCardInternal(LadderNetwork rung, int index) {"""

replacement = """        );
      },
    );
  }
      
  Widget buildRungCardInternal(LadderNetwork rung, int index) {"""

content = content.replace(target, replacement)

with open('lib/ladder/ui/editor/ladder_editor_page.dart', 'w') as f:
    f.write(content)
