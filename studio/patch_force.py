import re

with open('lib/ladder/ui/editor/ladder_editor_page.dart', 'r') as f:
    content = f.read()

# Add _forcedTags to state
target_state = """  final Map<String, ValueNotifier<int>> _rungNotifiers = {};"""
rep_state = """  final Map<String, ValueNotifier<int>> _rungNotifiers = {};
  final Map<String, bool> _forcedTags = {};"""
content = content.replace(target_state, rep_state)

# Modify simulation loop to support forces
target_sim = """  void _startTimedSimulation() {
    _simulationTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (mounted) {
        // Feed external inputs into the simulation
        _simulationInputs.forEach((tag, value) {
          _runtime.tagStore.setBool(tag, value);
        });

        // Use singleScan instead of evaluateProject to keep internal state
        _runtime.singleScan(100);
        _simulationTick.value++;
      }
    });
  }"""
rep_sim = """  void _startTimedSimulation() {
    _simulationTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (mounted) {
        // Feed external inputs into the simulation
        _simulationInputs.forEach((tag, value) {
          if (!_forcedTags.containsKey(tag)) {
            _runtime.tagStore.setBool(tag, value);
          }
        });

        // Use singleScan instead of evaluateProject to keep internal state
        _runtime.singleScan(100);
        
        // Apply forced tags overriding any logic
        _forcedTags.forEach((tag, value) {
          _runtime.tagStore.setBool(tag, value);
        });

        _simulationTick.value++;
      }
    });
  }"""
# Wait, evaluateProject was replaced by singleScan in previous phases? 
# Let's check how the simulation is actually written in the file right now.
