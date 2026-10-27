import 'enums.dart';

/// Unidade canônica para manipulação, validação e mapeamento de endereços PLC V1.
///
/// Faixas Válidas:
/// - Entradas Digitais (I):  I0.0 .. I1.7  => ID 10 .. 25  (16 canais)
/// - Saídas Digitais (Q):   Q0.0 .. Q1.7  => ID 100 .. 115 (16 canais)
/// - Memória Bit (M):       M0.0 .. M1.5  => ID 26 .. 39  (14 bits)
/// - Temporizador (T):      T0 .. T15     => ID 40 .. 55  (16 timers)
/// - Contador (C):          C0 .. C15     => ID 56 .. 71  (16 contadores)
class PlcTagContract {
  PlcTagContract._();

  static const int inputBaseId = 10;
  static const int outputBaseId = 100;
  static const int memoryBaseId = 26;
  static const int timerBaseId = 40;
  static const int counterBaseId = 56;
  static const int analogInputBaseId = 72;
  static const int analogOutputBaseId = 80;

  /// Converte qualquer endereço válido ou legado (X0/Y0) em um endereço canônico PLC.
  /// Retorna `null` se a string for inválida.
  static String? normalizeAddress(String? rawInput, {bool allowExtended = false}) {
    if (rawInput == null) return null;
    String clean = rawInput.trim().toUpperCase();
    if (clean.startsWith('%')) {
      clean = clean.substring(1);
    }
    // Remove também 'X' em %IX ou %QX (ex: %IX0.0 -> I0.0, %QX0.0 -> Q0.0)
    if (clean.startsWith('IX')) {
      clean = 'I${clean.substring(2)}';
    } else if (clean.startsWith('QX')) {
      clean = 'Q${clean.substring(2)}';
    }
    if (clean.isEmpty) return null;

    // 1. Suporte Legado X0..X15 -> I0.x / I1.x e Y0..Y15 -> Q0.x / Q1.x
    final matchXY = RegExp(r'^(X|Y)(\d{1,2})$').firstMatch(clean);
    if (matchXY != null) {
      final prefix = matchXY.group(1)!;
      final num = int.parse(matchXY.group(2)!);
      if (num >= 0 && num <= 15) {
        final byteIdx = num ~/ 8;
        final bitIdx = num % 8;
        return (prefix == 'X') ? 'I$byteIdx.$bitIdx' : 'Q$byteIdx.$bitIdx';
      }
      return null;
    }

    // Suporte Formato Compacto DI00..DI17 / DO00..DO17
    final matchDIDO = RegExp(r'^(DI|DO)(\d{2})$').firstMatch(clean);
    if (matchDIDO != null) {
      final prefix = matchDIDO.group(1)!;
      final byteIdx = int.parse(matchDIDO.group(2)![0]);
      final bitIdx = int.parse(matchDIDO.group(2)![1]);
      if (bitIdx <= 7) {
        return (prefix == 'DI') ? 'I$byteIdx.$bitIdx' : 'Q$byteIdx.$bitIdx';
      }
      return null;
    }

    // Suporte Formato Sem Ponto I00..I17 / Q00..Q17
    final matchIQCompact = RegExp(r'^(I|Q)(\d{2})$').firstMatch(clean);
    if (matchIQCompact != null) {
      final prefix = matchIQCompact.group(1)!;
      final byteIdx = int.parse(matchIQCompact.group(2)![0]);
      final bitIdx = int.parse(matchIQCompact.group(2)![1]);
      if (bitIdx <= 7) {
        return '$prefix$byteIdx.$bitIdx';
      }
      return null;
    }

    // Suporte Formato Analógico Compacto AI00..AI29 e AO00..AO29
    final matchAICompact = RegExp(r'^(AI|AO)(\d{2})$').firstMatch(clean);
    if (matchAICompact != null) {
      final prefix = matchAICompact.group(1)!;
      final nodeIdx = int.parse(matchAICompact.group(2)![0]);
      final chIdx = int.parse(matchAICompact.group(2)![1]);
      return '$prefix$nodeIdx.$chIdx';
    }

    // 2. Formato PLC Bit (I0.0..I1.7, Q0.0..Q1.7, M0.0..M1.5)
    final matchBit = RegExp(r'^(I|Q|M)(\d{1,2})\.(\d)$').firstMatch(clean);
    if (matchBit != null) {
      final prefix = matchBit.group(1)!;
      final byteIdx = int.parse(matchBit.group(2)!);
      final bitIdx = int.parse(matchBit.group(3)!);

      if (bitIdx > 7) return null;
      if (!allowExtended) {
        if (prefix == 'I' || prefix == 'Q') {
          if (byteIdx >= 0 && byteIdx <= 9) return '$prefix$byteIdx.$bitIdx';
          return null;
        }
        if (prefix == 'M') {
          if (byteIdx == 0) return '$prefix$byteIdx.$bitIdx';
          if (byteIdx == 1 && bitIdx <= 5) return '$prefix$byteIdx.$bitIdx';
          return null;
        }
      } else {
        if (byteIdx >= 0 && byteIdx <= 29) return '$prefix$byteIdx.$bitIdx';
      }
      return null;
    }

    // 3. Formato Temporizador e Contador (T0..T15, C0..C15 e sub-propriedades T0.DN, T0.Q, T0.PT, T0.ACC, T0.ET, etc)
    final matchTCSub = RegExp(r'^(T|C)(\d{1,2})\.(DN|Q|TT|EN|IN|ACC|ET|PT|PV|CU|CD|CV)$').firstMatch(clean);
    if (matchTCSub != null) {
      final prefix = matchTCSub.group(1)!;
      final idx = int.parse(matchTCSub.group(2)!);
      final sub = matchTCSub.group(3)!;
      if (idx >= 0 && idx <= 15) return '$prefix$idx.$sub';
      return null;
    }

    final matchTC = RegExp(r'^(T|C)(\d{1,2})$').firstMatch(clean);
    if (matchTC != null) {
      final prefix = matchTC.group(1)!;
      final idx = int.parse(matchTC.group(2)!);
      if (idx >= 0 && idx <= 15) return '$prefix$idx';
      return null;
    }

    if (allowExtended) {
      // 4. Formato PLC Analógico
      final matchAnalogDot = RegExp(r'^(AI|AO|IW|QW)(\d{1,2})\.(\d)$').firstMatch(clean);
      if (matchAnalogDot != null) {
        final prefix = matchAnalogDot.group(1)!;
        final nodeIdx = int.parse(matchAnalogDot.group(2)!);
        final chIdx = int.parse(matchAnalogDot.group(3)!);
        if (nodeIdx >= 0 && nodeIdx <= 29 && chIdx <= 7) {
          final normPrefix = (prefix == 'IW') ? 'AI' : (prefix == 'QW') ? 'AO' : prefix;
          return '$normPrefix$nodeIdx.$chIdx';
        }
        return null;
      }

      final matchAnalog = RegExp(r'^(AI|AO|IW|QW)(\d{1,2})$').firstMatch(clean);
      if (matchAnalog != null) {
        final prefix = matchAnalog.group(1)!;
        final idx = int.parse(matchAnalog.group(2)!);
        if (idx >= 0 && idx <= 255) {
          final normPrefix = (prefix == 'IW') ? 'AI' : (prefix == 'QW') ? 'AO' : prefix;
          return '$normPrefix$idx';
        }
        return null;
      }
    }

    return null;
  }

  /// Retorna a identidade numérica primária de 16 bits esperada pelo Firmware/Bytecode Compiler.
  /// Lança `FormatException` para endereços fora de contrato ou malformatados.
  static int addressToId(String rawInput) {
    final canonical = normalizeAddress(rawInput, allowExtended: true) ?? normalizeAddress(rawInput);
    if (canonical == null) {
      // Checar se é um ID numérico direto para fallback/testes
      final directNum = int.tryParse(rawInput.trim());
      if (directNum != null && directNum >= 0 && directNum <= 65535) {
        return directNum;
      }
      // Fallback para Tags internas/customizadas com nomes livres sem endereço IEC (faixa 88..99)
      final cleanTag = rawInput.trim();
      if (cleanTag.isNotEmpty) {
        final hash = cleanTag.codeUnits.fold(0, (acc, elem) => (acc * 31 + elem) & 0xFFFF);
        return 88 + (hash % 12);
      }
      throw FormatException('Endereço PLC inválido ou fora do limite contratual: $rawInput');
    }

    final matchBit = RegExp(r'^(I|Q|M)(\d{1,2})\.(\d)$').firstMatch(canonical);
    if (matchBit != null) {
      final prefix = matchBit.group(1)!;
      final byteIdx = int.parse(matchBit.group(2)!);
      final bitIdx = int.parse(matchBit.group(3)!);
      final bitOffset = byteIdx * 8 + bitIdx;

      if (prefix == 'I') {
        if (byteIdx <= 1) return inputBaseId + bitOffset;
        return 120 + ((byteIdx - 2) * 8) + bitIdx;
      }
      if (prefix == 'Q') {
        if (byteIdx <= 1) return outputBaseId + bitOffset;
        return 160 + ((byteIdx - 2) * 8) + bitIdx;
      }
      if (prefix == 'M') return memoryBaseId + bitOffset;
    }

    final matchBlock = RegExp(r'^(T|C)(\d{1,2})$').firstMatch(canonical);
    if (matchBlock != null) {
      final prefix = matchBlock.group(1)!;
      final idx = int.parse(matchBlock.group(2)!);

      if (prefix == 'T') return timerBaseId + idx;
      if (prefix == 'C') return counterBaseId + idx;
    }

    final matchAnalogDot = RegExp(r'^(AI|AO)(\d{1,2})\.(\d)$').firstMatch(canonical);
    if (matchAnalogDot != null) {
      final prefix = matchAnalogDot.group(1)!;
      final nodeIdx = int.parse(matchAnalogDot.group(2)!);
      final chIdx = int.parse(matchAnalogDot.group(3)!);
      final offset = (nodeIdx * 8) + chIdx;
      if (prefix == 'AI') return analogInputBaseId + offset;
      if (prefix == 'AO') return analogOutputBaseId + offset;
    }

    final matchAnalog = RegExp(r'^(AI|AO)(\d{1,2})$').firstMatch(canonical);
    if (matchAnalog != null) {
      final prefix = matchAnalog.group(1)!;
      final idx = int.parse(matchAnalog.group(2)!);
      if (prefix == 'AI') return analogInputBaseId + idx;
      if (prefix == 'AO') return analogOutputBaseId + idx;
    }

    // Fallback dinâmico para Tags internas/customizadas sem endereço IEC explícito (88..99 / 0..65535)
    final cleanTag = rawInput.trim();
    if (cleanTag.isNotEmpty) {
      final hash = cleanTag.codeUnits.fold(0, (acc, elem) => (acc * 31 + elem) & 0xFFFF);
      return 88 + (hash % 12);
    }

    throw FormatException('Falha no mapeamento interno do endereço $canonical');
  }

  /// Mapeamento imutável e oficial dos GPIOs físicos do ESP32 atribuídos a cada endereço IEC.
  static const Map<String, int> hardwareGpios = {
    // Entradas Digitais (DI)
    'I0.0': 16,
    'I0.1': 17,
    'I0.2': 18,
    'I0.3': 19,
    'I0.4': 27,
    'I0.5': 13,
    // Saídas Digitais (DO)
    'Q0.0': 4,
    'Q0.1': 21,
    'Q0.2': 22,
    'Q0.3': 33,
    'Q0.4': 23,
    'Q0.5': 32,
    'Q0.6': 14,
    'Q0.7': 2,
    // Entradas Analógicas (AI)
    'AI0.0': 34,
    'AI0.1': 35,
    'AI0.2': 36,
    'AI0.3': 39,
    // Saídas Analógicas (AO - DAC)
    'AO0.0': 25,
    'AO0.1': 26,
  };

  /// Conjunto de pinos de boot / strapping proibidos para saídas ou I/O gerais no ESP32.
  static const Set<int> forbiddenStrappingPins = {0, 5, 12, 15};

  /// Valida a integridade do mapa de hardware.
  /// Retorna lista de erros encontrados (vazia se estiver 100% válido).
  static List<String> validateHardwareMap() {
    final errors = <String>[];
    final seenGpios = <int, String>{};

    hardwareGpios.forEach((channel, gpio) {
      if (seenGpios.containsKey(gpio)) {
        errors.add('CONFLITO DE GPIO: Pinos duplicados entre $channel e ${seenGpios[gpio]} (GPIO $gpio)');
      } else {
        seenGpios[gpio] = channel;
      }

      if (forbiddenStrappingPins.contains(gpio)) {
        errors.add('STRAPPING PIN PROIBIDO: $channel está alocado no pino de boot sensível GPIO $gpio');
      }
    });

    return errors;
  }

  /// Retorna o TagType correspondente ao formato do endereço PLC.
  static TagType? getTagTypeForAddress(String address) {
    final canonical = normalizeAddress(address);
    if (canonical == null) return null;
    if (canonical.startsWith('AI') || canonical.startsWith('AO')) {
      return TagType.real;
    }
    if (canonical.startsWith('I') || canonical.startsWith('Q') || canonical.startsWith('M')) {
      return TagType.bool;
    }
    if (canonical.startsWith('T')) return TagType.timer;
    if (canonical.startsWith('C')) return TagType.counter;
    return null;
  }
}
