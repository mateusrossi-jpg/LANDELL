/// Modelos e parser de mapeamento de I/O industrial consumidos de /api/io/map
class IoChannelMapping {
  final int channelId;
  final String logicalAddress;
  final String channelName;
  final String type; // 'digital_input', 'digital_output', 'analog_input', 'analog_output'
  final int? gpio;
  final String profile;
  final int state;
  final int desired;
  final int reported;
  final bool failsafe;
  final bool driverEnabled;
  final bool physicalPresent;
  final String controlPath;
  final String lastTransition;
  final String nodeId;
  final String nodeIp;
  final String nodeRole;

  const IoChannelMapping({
    required this.channelId,
    required this.logicalAddress,
    required this.channelName,
    required this.type,
    this.gpio,
    required this.profile,
    required this.state,
    this.desired = 0,
    this.reported = 0,
    this.failsafe = false,
    this.driverEnabled = true,
    this.physicalPresent = true,
    this.controlPath = '',
    this.lastTransition = '',
    this.nodeId = '',
    this.nodeIp = '',
    this.nodeRole = 'Local',
  });

  bool get isDigital => type == 'digital_input' || type == 'digital_output';
  bool get isAnalog => type == 'analog_input' || type == 'analog_output';
  bool get isInput => type == 'digital_input' || type == 'analog_input';
  bool get isOutput => type == 'digital_output' || type == 'analog_output';
  bool get isOn => (isOutput ? (desired > 0) : (state > 0));
  String get uniqueKey => '${nodeId.isNotEmpty ? nodeId : "local"}_$channelId';

  factory IoChannelMapping.fromInputJson(Map<String, dynamic> json, {String nodeId = '', String nodeIp = '', String nodeRole = 'Local'}) {
    final channelId = (json['channel_id'] ?? json['channelId'] ?? 0) as int;
    final name = (json['name'] ?? 'I0.0').toString();
    final type = (json['type'] ?? 'digital_input').toString();
    final gpio = json['gpio'] is int ? json['gpio'] as int : int.tryParse(json['gpio']?.toString() ?? '');
    final profile = (json['profile'] ?? 'gpio').toString();
    final state = (json['state'] ?? json['value'] ?? 0) as int;

    final isRemote = nodeId.isNotEmpty && nodeRole != 'Gateway Principal' && nodeRole != 'Local' && nodeRole != 'Gateway';
    final parsedCtrlIdx = json['controller_index'] != null
        ? int.tryParse(json['controller_index'].toString())
        : (json['controllerIndex'] != null ? int.tryParse(json['controllerIndex'].toString()) : null);
    final nodeIdx = parsedCtrlIdx ?? (isRemote ? 1 : 0);

    int index = 0;
    if (channelId >= 10 && channelId <= 41) {
      index = channelId - 10;
    } else if (channelId >= 12 && channelId <= 19) {
      index = channelId - 12;
    } else {
      final m = RegExp(r'\d+').firstMatch(name);
      if (m != null) {
        index = (int.tryParse(m.group(0)!) ?? 1) - 1;
        if (index < 0) index = 0;
      }
    }

    String logicalAddress;
    if (type == 'analog_input') {
      logicalAddress = 'AI$nodeIdx.$index';
    } else {
      logicalAddress = 'I$nodeIdx.$index';
    }

    if (isRemote) {
      logicalAddress = '$nodeRole · $logicalAddress';
    }

    return IoChannelMapping(
      channelId: channelId,
      logicalAddress: logicalAddress,
      channelName: name,
      type: type,
      gpio: gpio,
      profile: profile,
      state: state,
      desired: state,
      reported: state,
      failsafe: false,
      driverEnabled: true,
      physicalPresent: true,
      nodeId: nodeId,
      nodeIp: nodeIp,
      nodeRole: nodeRole,
    );
  }

  factory IoChannelMapping.fromOutputJson(Map<String, dynamic> json, {String nodeId = '', String nodeIp = '', String nodeRole = 'Local'}) {
    final channelId = (json['channel_id'] ?? json['channelId'] ?? 0) as int;
    final name = (json['name'] ?? 'Q0.0').toString();
    final type = (json['type'] ?? 'digital_output').toString();
    final gpio = json['gpio'] is int ? json['gpio'] as int : int.tryParse(json['gpio']?.toString() ?? '');
    final profile = (json['profile'] ?? 'relay').toString();
    final desired = (json['desired'] ?? 0) as int;
    final reported = (json['reported'] ?? 0) as int;
    final failsafe = json['failsafe'] == true || json['failsafe']?.toString() == 'true';
    final driverEnabled = json['driver_enabled'] != false && json['driver_enabled']?.toString() != 'false';
    final physicalPresent = json['physical_present'] != false && json['physical_present']?.toString() != 'false';
    final controlPath = (json['control_path'] ?? '').toString();
    final lastTransition = (json['last_transition'] ?? '').toString();

    final isRemote = nodeId.isNotEmpty && nodeRole != 'Gateway Principal' && nodeRole != 'Local' && nodeRole != 'Gateway';
    final parsedCtrlIdx = json['controller_index'] != null
        ? int.tryParse(json['controller_index'].toString())
        : (json['controllerIndex'] != null ? int.tryParse(json['controllerIndex'].toString()) : null);
    final nodeIdx = parsedCtrlIdx ?? (isRemote ? 1 : 0);

    int index = 0;
    if (channelId >= 100 && channelId <= 131) {
      index = channelId - 100;
    } else {
      final m = RegExp(r'\d+').firstMatch(name);
      if (m != null) {
        index = int.tryParse(m.group(0)!) ?? 0;
      }
    }

    String logicalAddress;
    if (type == 'analog_output') {
      logicalAddress = 'AO$nodeIdx.$index';
    } else {
      logicalAddress = 'Q$nodeIdx.$index';
    }

    if (isRemote) {
      logicalAddress = '$nodeRole · $logicalAddress';
    }

    return IoChannelMapping(
      channelId: channelId,
      logicalAddress: logicalAddress,
      channelName: name,
      type: type,
      gpio: gpio,
      profile: profile,
      state: desired,
      desired: desired,
      reported: reported,
      failsafe: failsafe,
      driverEnabled: driverEnabled,
      physicalPresent: physicalPresent,
      controlPath: controlPath,
      lastTransition: lastTransition,
      nodeId: nodeId,
      nodeIp: nodeIp,
      nodeRole: nodeRole,
    );
  }
}

class IoMapResponse {
  final List<IoChannelMapping> digitalInputs;
  final List<IoChannelMapping> digitalOutputs;
  final List<IoChannelMapping> analogInputs;
  final List<IoChannelMapping> analogOutputs;

  const IoMapResponse({
    required this.digitalInputs,
    required this.digitalOutputs,
    required this.analogInputs,
    required this.analogOutputs,
  });

  factory IoMapResponse.fromJson(Map<String, dynamic> json) {
    final rawInputs = json['inputs'] as List<dynamic>? ?? [];
    final rawOutputs = json['outputs'] as List<dynamic>? ?? [];

    final List<IoChannelMapping> dIn = [];
    final List<IoChannelMapping> aIn = [];
    final List<IoChannelMapping> dOut = [];
    final List<IoChannelMapping> aOut = [];

    for (final item in rawInputs) {
      if (item is Map<String, dynamic>) {
        final mapping = IoChannelMapping.fromInputJson(item);
        if (mapping.type == 'analog_input') {
          aIn.add(mapping);
        } else {
          dIn.add(mapping);
        }
      }
    }

    for (final item in rawOutputs) {
      if (item is Map<String, dynamic>) {
        final mapping = IoChannelMapping.fromOutputJson(item);
        if (mapping.type == 'analog_output') {
          aOut.add(mapping);
        } else {
          dOut.add(mapping);
        }
      }
    }

    return IoMapResponse(
      digitalInputs: dIn,
      digitalOutputs: dOut,
      analogInputs: aIn,
      analogOutputs: aOut,
    );
  }
}
