import '../../models/ladder_project.dart';
import '../../models/simulation_result.dart';

/// Applies the energization status from a [SimulationResult] to the visual
/// representation of the ladder.
///
/// For each [LadderNode] in every network, the flag `isEnergized` is set to true
/// when the node has a non‑null tag and the simulation outputs contain that
/// tag with a value of `true`. Otherwise the flag is set to `false`.
///
/// This function mutates the provided `project` in‑place and returns it for
/// convenience.
LadderProject applySimulationResult(
  LadderProject project,
  SimulationResult result,
) {
  for (final network in project.networks) {
    for (final node in network.nodes) {
      final tag = node.config.tagId;
      if (tag != null && result.outputs.containsKey(tag)) {
        node.isEnergized = result.outputs[tag] ?? false;
      } else {
        node.isEnergized = false;
      }
    }
  }
  return project;
}
