/// Agora suporta conexoes explicitas de porta a porta (ex: In, Out, Reset, Enable).
class LadderConnection {
  final String id;
  final String fromNodeId;
  final String fromPort;
  final String toNodeId;
  final String toPort;

  LadderConnection({
    required this.id,
    required this.fromNodeId,
    required this.fromPort,
    required this.toNodeId,
    required this.toPort,
  });

  LadderConnection clone() {
    return LadderConnection(
      id: id,
      fromNodeId: fromNodeId,
      fromPort: fromPort,
      toNodeId: toNodeId,
      toPort: toPort,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fromNodeId': fromNodeId,
        'fromPort': fromPort,
        'toNodeId': toNodeId,
        'toPort': toPort,
      };

  factory LadderConnection.fromJson(Map<String, dynamic> json) => LadderConnection(
        id: json['id'] as String,
        fromNodeId: json['fromNodeId'] as String,
        fromPort: json['fromPort'] as String,
        toNodeId: json['toNodeId'] as String,
        toPort: json['toPort'] as String,
      );
}
