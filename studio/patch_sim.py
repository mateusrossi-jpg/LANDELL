import re

with open('lib/ladder/ui/editor/ladder_editor_page.dart', 'r') as f:
    content = f.read()

target = """  void _executeSimulationTick() {
    _simulationInputs.forEach((tagId, val) {
      _runtime.tagStore.setBool(tagId, val);
    });

    _runtime.singleScan(_scanPeriodMs);"""

rep = """  void _executeSimulationTick() {
    _simulationInputs.forEach((tagId, val) {
      if (!_forcedTags.containsKey(tagId)) {
        _runtime.tagStore.setBool(tagId, val);
      }
    });

    _runtime.singleScan(_scanPeriodMs);
    
    _forcedTags.forEach((tagId, val) {
      _runtime.tagStore.setBool(tagId, val);
    });"""

content = content.replace(target, rep)

with open('lib/ladder/ui/editor/ladder_editor_page.dart', 'w') as f:
    f.write(content)
