import 'package:flutter_test/flutter_test.dart';
import 'package:endap_studio/ladder/models/tag.dart';
import 'package:endap_studio/ladder/models/enums.dart';

void main() {
  test('Calibração Universal de Sensores: Offset e Gain (Caso 18C -> 28C)', () {
    // 1. Tag configurada com calibração universal
    final tempTag = Tag(
      id: 'TEMP_AHT10',
      name: 'Temperatura Ambiente',
      type: TagType.real,
      unit: '°C',
      calOffset: 10.0, // Usuário calibrou +10.0 graus de offset
      calGain: 1.0,    // Ganho 1.0
    );

    expect(tempTag.calOffset, 10.0);
    expect(tempTag.calGain, 1.0);

    // Teste de cálculo com a fórmula universal: (raw * gain) + offset
    final rawMeasured = 18.0;
    final calibratedVal = tempTag.scaleValue(rawMeasured);
    expect(calibratedVal, 28.0);

    // Serialization / Deserialization check
    final json = tempTag.toJson();
    expect(json['calOffset'], 10.0);
    expect(json['calGain'], 1.0);

    final restored = Tag.fromJson(json);
    expect(restored.calOffset, 10.0);
    expect(restored.calGain, 1.0);
    expect(restored.scaleValue(18.0), 28.0);
  });

  test('Calibração Universal de 2 Pontos (Zero e Span)', () {
    // Sensor medindo:
    // Ponto 1: Medido X1 = 10, Real Y1 = 20
    // Ponto 2: Medido X2 = 50, Real Y2 = 100
    // m = (100 - 20) / (50 - 10) = 80 / 40 = 2.0
    // b = 20 - (2.0 * 10) = 0.0
    final m = (100.0 - 20.0) / (50.0 - 10.0);
    final b = 20.0 - (m * 10.0);

    expect(m, 2.0);
    expect(b, 0.0);

    final pressureTag = Tag(
      id: 'PRES_01',
      name: 'Transmissor Pressão',
      type: TagType.real,
      unit: 'bar',
      calGain: m,
      calOffset: b,
    );

    // Leitura medida de 30 bar no sensor: (30 * 2.0) + 0 = 60 bar calibrados
    expect(pressureTag.scaleValue(30.0), 60.0);
  });
}
