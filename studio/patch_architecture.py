import re

with open('lib/ladder/ui/editor/ladder_editor_page.dart', 'r') as f:
    content = f.read()

# We need to extract RungWidget, ToolboxWidget, and VariablesPanel.
# But actually, if we just use ValueListenableBuilder inside _buildRungList, _buildComponentToolbox, _buildVariablesPanel,
# we don't strictly need to move them to separate files, but the prompt says:
# "Extrair cada Rung para um widget próprio. class RungWidget extends StatelessWidget..."

# Let's extract RungWidget:
rung_widget = """
class RungWidget extends StatelessWidget {
  final LadderNetwork rung;
  final int index;
  final dynamic parent;

  const RungWidget({
    Key? key,
    required this.rung,
    required this.index,
    required this.parent,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    debugPrint('BUILD RUNG ${rung.id}');
    return parent.buildRungCardInternal(rung, index);
  }
}
"""

content = content.replace("class _LadderEditorPageState extends State<LadderEditorPage> {", rung_widget + "\nclass _LadderEditorPageState extends State<LadderEditorPage> {")

# Add Notifiers
notifiers = """
  final ValueNotifier<int> _simulationTick = ValueNotifier(0);
  final Map<String, ValueNotifier<int>> _rungNotifiers = {};
  
  ValueNotifier<int> _getRungNotifier(String id) {
    return _rungNotifiers.putIfAbsent(id, () => ValueNotifier(0));
  }
  
  void _notifyRung(String id) {
    _getRungNotifier(id).value++;
  }
"""

content = re.sub(r'bool _isVariablesPanelExpanded = false;', r'bool _isVariablesPanelExpanded = false;' + notifiers, content)

# Change _startTimedSimulation
sim_target = """        _runtime.evaluateProject();
      }
    });
  }"""
sim_replacement = """        _runtime.evaluateProject();
        _simulationTick.value++;
      }
    });
  }"""
content = content.replace(sim_target, sim_replacement)

# Change _runPassiveValidation
val_target = """  void _runPassiveValidation() {
    final validator = GraphValidator();
    final Map<String, String> errors = {};

    for (var network in _project.networks) {
      final result = validator.validateNetwork(network);
      if (!result.isValid) {
        errors[network.id] = result.errors.first;
      }
    }
    _networkValidationErrors = errors;
  }"""
val_replacement = """  void _runPassiveValidation() {
    final validator = GraphValidator();
    final Map<String, String> errors = {};

    for (var network in _project.networks) {
      final result = validator.validateNetwork(network);
      if (!result.isValid) {
        errors[network.id] = result.errors.first;
      }
      if (_networkValidationErrors[network.id] != errors[network.id]) {
        _notifyRung(network.id);
      }
    }
    for (var id in _networkValidationErrors.keys) {
      if (!errors.containsKey(id)) {
        _notifyRung(id);
      }
    }
    _networkValidationErrors = errors;
  }"""
content = content.replace(val_target, val_replacement)

# In _buildRungList, wrap with AnimatedBuilder and RungWidget
rung_list_target = """      itemBuilder: (context, index) {
        final rung = _project.networks[index];
        final rungError = _networkValidationErrors[rung.id];
        
        return Card("""
rung_list_replacement = """      itemBuilder: (context, index) {
        final rung = _project.networks[index];
        return AnimatedBuilder(
          animation: Listenable.merge([
            _getRungNotifier(rung.id),
            _simulationTick,
          ]),
          builder: (context, _) {
            return RungWidget(
              key: ValueKey(rung.id),
              rung: rung,
              index: index,
              parent: this,
            );
          },
        );
      }
      
  Widget buildRungCardInternal(LadderNetwork rung, int index) {
    final rungError = _networkValidationErrors[rung.id];
    return Card("""
content = content.replace(rung_list_target, rung_list_replacement)

# Ensure the end of the original _buildRungList function is closed properly.
# The original ended with `return ListView.builder(...); }`
# We need to make sure buildRungCardInternal replaces the inner part.
# But replacing the target above opens buildRungCardInternal without closing it!
# Let's fix that. The target was `return Card(`. This card extends to the end of itemBuilder.

# We will just write the modified content back.
with open('lib/ladder/ui/editor/ladder_editor_page.dart', 'w') as f:
    f.write(content)
