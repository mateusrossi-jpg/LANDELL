import 'dart:async';

import '../models/tag.dart';
import '../models/tag_value.dart';
import '../models/ladder_project.dart';
import '../models/enums.dart';
import '../validation/graph_validator.dart';
import '../runtime/ladder_runtime.dart';
import '../models/simulation_result.dart';

class LadderSimulationController {
  /// Executes a simulation for the given [LadderProject].
  /// Returns a [SimulationResult] containing success flag, outputs, validation errors,
  /// execution time and a summary.
  static Future<SimulationResult> runSimulation(LadderProject project, Map<String, bool> inputValues) async {
    final stopwatch = Stopwatch()..start();

    // 1. Generate tags automatically based on nodes in the project.
    for (final network in project.networks) {
      for (final node in network.nodes) {
        final tagName = node.config.tagId?.trim();
        if (tagName != null && tagName.isNotEmpty) {
          project.tags.putIfAbsent(
            tagName,
            () => Tag(
              id: tagName,
              name: tagName,
              type: TagType.bool,
              initialValue: TagValue.boolean(false),
            ),
          );
        }
      }
    }

    // 2. Validate the graph.
    final validationResult = GraphValidator().validate(project);
    if (!validationResult.isValid) {
      stopwatch.stop();
      return SimulationResult(
        success: false,
        outputs: {},
        validationErrors: validationResult.errors.map((e) => e.message).toList(),
        executionTime: stopwatch.elapsed,
        summary: 'Validation failed',
      );
    }

    // 3. Load executable graph into a fresh runtime instance.
    final runtime = LadderRuntime();
    runtime.loadProject(validationResult.executableGraph!);
    // Apply input values to tag store
    inputValues.forEach((tagId, val) {
      runtime.tagStore.setBool(tagId, val);
    });

    // 4. Perform a single scan (deltaTimeMs set to 0 for deterministic behaviour).
    runtime.singleScan(0);

    // 5. Gather coil outputs.
    final outputs = <String, bool>{};
    for (final network in project.networks) {
      for (final node in network.nodes) {
        if (node.type == NodeType.coil) {
          final tagId = node.config.tagId?.trim() ?? '';
          if (tagId.isNotEmpty) {
            outputs[tagId] = runtime.tagStore.getBool(tagId);
          }
        }
      }
    }

    stopwatch.stop();
    return SimulationResult(
      success: true,
      outputs: outputs,
      validationErrors: [],
      executionTime: stopwatch.elapsed,
      summary: 'Simulation completed successfully',
    );
  }
}
