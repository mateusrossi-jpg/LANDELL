import '../models/ladder_project.dart';
import '../models/ladder_node.dart';
import '../validation/executable_graph.dart';
import 'evaluator_registry.dart';
import 'node_runtime_state.dart';
import 'scan_engine.dart';
import 'scan_scheduler.dart';
import 'tag_state_store.dart';

class LadderRuntime {
  final TagStateStore tagStore = TagStateStore();
  final ScanScheduler scheduler = ScanScheduler();
  late final ScanEngine engine;
  final Map<String, NodeRuntimeState> nodeStates = {};
  int lastScanDurationUs = 0;

  LadderProject? _currentProject;
  LadderProject get project => _currentProject!;
  final Map<String, List<LadderNode>> _executionPlans = {};

  LadderRuntime() {
    engine = ScanEngine(EvaluatorRegistry());
  }

  void loadProject(ExecutableGraph executableGraph) {
    _currentProject = executableGraph.project;
    nodeStates.clear();
    _executionPlans.clear();

    // Injeta as tags no Store
    _currentProject!.tags.forEach((id, tag) {
      if (tag.initialValue != null) {
        tagStore.initTag(id, tag.initialValue!);
      }
    });

    // Compila o plano de execucao estatico (Ordem topologica)
    for (var network in _currentProject!.networks) {
      _executionPlans[network.id] = engine.buildExecutionPlan(network);
    }
  }

  void start() {
    if (_currentProject == null) return;
    scheduler.start((deltaTimeMs) {
      singleScan(deltaTimeMs);
    });
  }

  void stop() {
    scheduler.stop();
  }

  void singleScan(int deltaTimeMs) {
    if (_currentProject == null) return;
    final sw = Stopwatch()..start();
    
    // Em um sistema real, ler inputs fisicos aconteceria aqui
    
    for (var network in _currentProject!.networks) {
      if (!network.isEnabled) {
        for (var node in network.nodes) {
          node.isEnergized = false;
        }
        continue;
      }
      final plan = _executionPlans[network.id];
      if (plan != null) {
        engine.executeScan(network, plan, nodeStates, tagStore, deltaTimeMs);
      }
    }
    sw.stop();
    lastScanDurationUs = sw.elapsedMicroseconds;
  }
}
