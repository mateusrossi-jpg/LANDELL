import re

with open('lib/ladder/ui/editor/ladder_editor_page.dart', 'r') as f:
    content = f.read()

target = """                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFF334155), width: 0.5)),
                    ),
                    child: Row("""
rep = """                  return GestureDetector(
                    onLongPress: () => _showForceTagBottomSheet(tag.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Color(0xFF334155), width: 0.5)),
                        color: _forcedTags.containsKey(tag.id) ? Colors.orangeAccent.withValues(alpha: 0.1) : Colors.transparent,
                      ),
                      child: Row("""
content = content.replace(target, rep)

# Find the end of the Container to close the GestureDetector
target2 = """                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),"""
rep2 = """                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ));
                },
              ),
            ),"""
content = content.replace(target2, rep2)

bottom_sheet = """
  void _showForceTagBottomSheet(String tagId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Forçar Variável: $tagId', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.flash_on, color: Colors.greenAccent),
                title: const Text('Forçar ON', style: TextStyle(color: Colors.white)),
                onTap: () {
                  setState(() { _forcedTags[tagId] = true; });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.flash_off, color: Colors.redAccent),
                title: const Text('Forçar OFF', style: TextStyle(color: Colors.white)),
                onTap: () {
                  setState(() { _forcedTags[tagId] = false; });
                  Navigator.pop(context);
                },
              ),
              if (_forcedTags.containsKey(tagId))
                ListTile(
                  leading: const Icon(Icons.clear, color: Colors.grey),
                  title: const Text('Remover Forçamento', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    setState(() { _forcedTags.remove(tagId); });
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        );
      },
    );
  }
"""

content = content.replace("  Widget _buildVariablesPanel() {", bottom_sheet + "\n  Widget _buildVariablesPanel() {")

with open('lib/ladder/ui/editor/ladder_editor_page.dart', 'w') as f:
    f.write(content)
