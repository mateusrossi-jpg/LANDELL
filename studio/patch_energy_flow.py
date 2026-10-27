import re

with open('lib/ladder/ui/editor/ladder_editor_page.dart', 'r') as f:
    content = f.read()

# Replace pulse/glow logic
target_glow = """  Widget _buildLadderNodeVisual(LadderNode node, bool isSelected) {
    final int ms = DateTime.now().millisecondsSinceEpoch;
    // Calculate pulse multiplier (goes from 0.0 to 1.0 back and forth over 1.5 seconds)
    final double pulse = (math.sin(ms * 2 * math.pi / 1500) + 1.0) / 2.0;
    final double glowRadius = node.isEnergized ? 4.0 + (pulse * 8.0) : 0.0;
    final double glowOpacity = node.isEnergized ? 0.2 + (pulse * 0.4) : 0.0;"""

rep_glow = """  Widget _buildLadderNodeVisual(LadderNode node, bool isSelected) {
    final double glowRadius = node.isEnergized ? 4.0 : 0.0;
    final double glowOpacity = node.isEnergized ? 0.2 : 0.0;"""

content = content.replace(target_glow, rep_glow)

with open('lib/ladder/ui/editor/ladder_editor_page.dart', 'w') as f:
    f.write(content)
