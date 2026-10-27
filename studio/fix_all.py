import re

with open('lib/ladder/ui/editor/ladder_editor_page.dart', 'r') as f:
    content = f.read()

# Fix 1: Add _forcedTags
target_state = """  // Active inputs during simulation
  final Map<String, bool> _simulationInputs = {};"""
rep_state = """  // Active inputs during simulation
  final Map<String, bool> _simulationInputs = {};
  
  // Forced tags to override logic during simulation
  final Map<String, bool> _forcedTags = {};"""
content = content.replace(target_state, rep_state)

# Fix 2: Remove 'const' from BoxDecoration that uses _forcedTags
target_box = """                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Color(0xFF334155), width: 0.5)),
                        color: _forcedTags.containsKey(tag.id) ? Colors.orangeAccent.withValues(alpha: 0.1) : Colors.transparent,
                      ),"""
rep_box = """                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        border: const Border(bottom: BorderSide(color: Color(0xFF334155), width: 0.5)),
                        color: _forcedTags.containsKey(tag.id) ? Colors.orangeAccent.withValues(alpha: 0.1) : Colors.transparent,
                      ),"""
content = content.replace(target_box, rep_box)

# Fix 3: Fix syntax error in GestureDetector replacement (I added an extra parenthesis at the end)
# Wait, let's look at the old replacement logic.
target_syntax = """                          ],
                        ),
                      ],
                    ),
                  ));
                },"""
rep_syntax = """                          ],
                        ),
                      ],
                    ),
                  );
                },"""
content = content.replace(target_syntax, rep_syntax)

with open('lib/ladder/ui/editor/ladder_editor_page.dart', 'w') as f:
    f.write(content)
