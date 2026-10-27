import '../models/ladder_project.dart';

/// Camada de protecao: Representa um grafo que foi compulsoriamente
/// verificado pelo GraphValidator. O Runtime passa a aceitar APENAS esta classe.
class ExecutableGraph {
  final LadderProject project;

  /// Construtor protegido (por convencao). Realiza DEEP CLONE imediato para evitar 
  /// Shared Reference Leak com a UI. Nenhuma classe, exceto o GraphValidator,
  /// deve instanciar o ExecutableGraph.
  ExecutableGraph.validated(LadderProject rawProject) : project = rawProject.clone();
}
