/// Núcleo matemático do PID industrial do ENDAP.
///
/// É um espelho bit-a-bit de `firmware/components/runtime/ladder/ladder_pid.c`
/// (aritmética inteira, resolução de 0,001 %), garantindo que a simulação do
/// Studio produza exatamente a mesma saída do CLP. Os vetores dourados em
/// `test/unit/ladder/pid_industrial_test.dart` são gerados pelo teste de mesa C.
///
/// Forma ISA paralela: u = Kp·e + Ki·∫e·dt + Kd·dPV/dt
/// Todas as grandezas (PV, SP, MV) em porcentagem; tempo em segundos.
class PidParams {
  final int kpX100;
  final int kiX100;
  final int kdX100;
  final bool direct; // false = ação reversa
  final bool derivativeOnError; // false = derivada sobre o PV
  final bool manualEnable;
  final int outMin; // %
  final int outMax; // %
  final int deadbandX10; // 0..250 => 0,0..25,0 %
  final int enoThreshold; // %
  final int enoHysteresis; // %
  final int safeOut; // %

  const PidParams({
    required this.kpX100,
    required this.kiX100,
    required this.kdX100,
    this.direct = false,
    this.derivativeOnError = false,
    this.manualEnable = false,
    this.outMin = 0,
    this.outMax = 100,
    this.deadbandX10 = 0,
    this.enoThreshold = 0,
    this.enoHysteresis = 0,
    this.safeOut = 0,
  });

  /// Mesmas regras de `ladder_pid_params_valid()` do firmware.
  bool get isValid =>
      outMax <= 100 &&
      outMin >= 0 &&
      outMin < outMax &&
      deadbandX10 >= 0 &&
      deadbandX10 <= 250 &&
      enoThreshold >= 0 &&
      enoThreshold <= 100 &&
      enoHysteresis >= 0 &&
      enoHysteresis <= 100 &&
      safeOut >= 0 &&
      safeOut <= 100;

  int get flags =>
      (direct ? 0x01 : 0) | (derivativeOnError ? 0x02 : 0) | (manualEnable ? 0x04 : 0);
}

class PidState {
  bool initialized = false;
  bool eno = false;
  int integM = 0; // milésimos de % de saída
  int prevPvM = 0;
  int prevErrM = 0;
  int dFilt = 0; // milésimos de %/s
  int mvM = 0; // milésimos de %

  /// MV arredondada em % inteiro (igual a `ladder_pid_mv_percent`).
  int get mvPercent => (mvM + 500) ~/ 1000;
}

class PidMath {
  static const int sampleMs = 100;

  static int _clamp(int v, int lo, int hi) => v < lo ? lo : (v > hi ? hi : v);

  static int _safeM(PidParams p) =>
      _clamp(p.safeOut * 1000, p.outMin * 1000, p.outMax * 1000);

  /// Bloco desabilitado (EN = 0): saída segura e estado rearmado.
  static void disable(PidParams p, PidState s) {
    s.initialized = false;
    s.eno = false;
    s.integM = 0;
    s.prevPvM = 0;
    s.prevErrM = 0;
    s.dFilt = 0;
    s.mvM = _safeM(p);
  }

  static void _updateEno(PidParams p, PidState s) {
    final onM = p.enoThreshold * 1000;
    var offM = (p.enoThreshold - p.enoHysteresis) * 1000;
    if (offM < 0) offM = 0;
    if (!s.eno) {
      if (s.mvM > onM) s.eno = true;
    } else {
      if (s.mvM <= offM) s.eno = false;
    }
  }

  /// Uma amostra do PID. `pvPct`/`spPct` em % inteiros; `dtMs` > 0.
  static void step(
    PidParams p,
    PidState s, {
    required int pvPct,
    required int spPct,
    bool manual = false,
    int manPct = 0,
    int dtMs = sampleMs,
  }) {
    if (dtMs <= 0) dtMs = sampleMs;

    final outMinM = p.outMin * 1000;
    final outMaxM = p.outMax * 1000;

    final pvM = _clamp(pvPct, 0, 100) * 1000;
    final spM = _clamp(spPct, 0, 100) * 1000;

    var eM = p.direct ? (pvM - spM) : (spM - pvM);
    final dbM = p.deadbandX10 * 100;
    if (eM <= dbM && eM >= -dbM) eM = 0;

    final pTerm = (p.kpX100 * eM) ~/ 100;

    if (!s.initialized) {
      // Transferência sem solavanco a partir da saída segura.
      s.prevPvM = pvM;
      s.prevErrM = eM;
      s.dFilt = 0;
      s.integM = _clamp(_safeM(p) - pTerm, outMinM, outMaxM);
      s.mvM = _safeM(p);
      s.initialized = true;
    }

    // Derivada (sobre PV por padrão) com filtro de 1ª ordem: alpha = 5/6.
    final int dRaw;
    if (p.derivativeOnError) {
      dRaw = ((eM - s.prevErrM) * 1000) ~/ dtMs;
    } else {
      var dpv = pvM - s.prevPvM;
      if (!p.direct) dpv = -dpv;
      dRaw = (dpv * 1000) ~/ dtMs;
    }
    final dF = (5 * s.dFilt + dRaw) ~/ 6;
    s.dFilt = dF;
    s.prevPvM = pvM;
    s.prevErrM = eM;
    final dTerm = (p.kdX100 * dF) ~/ 100;

    final int mvM;
    final manualActive = manual && p.manualEnable;
    if (manualActive) {
      mvM = _clamp(_clamp(manPct, 0, 100) * 1000, outMinM, outMaxM);
      // Rastreamento: ao voltar para AUTO a saída continua em mvM (bumpless).
      s.integM = _clamp(mvM - pTerm - dTerm, outMinM, outMaxM);
    } else {
      final inc = (p.kiX100 * eM * dtMs) ~/ (100 * 1000);
      final cand = _clamp(s.integM + inc, outMinM, outMaxM);
      final uUnsat = pTerm + cand + dTerm;
      // Anti-windup: integração condicional (não integra contra a saturação).
      if (!((uUnsat > outMaxM && eM > 0) || (uUnsat < outMinM && eM < 0))) {
        s.integM = cand;
      }
      mvM = _clamp(pTerm + s.integM + dTerm, outMinM, outMaxM);
    }

    s.mvM = mvM;
    _updateEno(p, s);
  }
}
