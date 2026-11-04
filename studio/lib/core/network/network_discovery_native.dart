import 'dart:io';

Future<List<String>> getLocalSubnetPrefixes() async {
  try {
    final interfaces = await NetworkInterface.list(
      includeLinkLocal: false,
      type: InternetAddressType.IPv4,
    );
    final prefixes = <String>{};
    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        final ip = addr.address;
        if (ip.startsWith('127.') || ip == '192.168.4.1') continue;
        final parts = ip.split('.');
        if (parts.length == 4) {
          prefixes.add('${parts[0]}.${parts[1]}.${parts[2]}.');
        }
      }
    }
    return prefixes.toList();
  } catch (_) {
    return [];
  }
}
