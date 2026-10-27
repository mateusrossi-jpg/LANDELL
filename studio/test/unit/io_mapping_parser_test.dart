import 'package:flutter_test/flutter_test.dart';
import 'package:endap_studio/core/models/io_channel_mapping.dart';

void main() {
  group('IoChannelMapping and IoMapResponse Tests', () {
    test('Parse inputs and outputs matching official ENDAP contract', () {
      final sampleJson = {
        "inputs": [
          {
            "channel_id": 10,
            "name": "IN1",
            "type": "digital_input",
            "gpio": 16,
            "profile": "gpio",
            "state": 1,
            "implemented": true
          },
          {
            "channel_id": 25,
            "name": "IN16",
            "type": "digital_input",
            "gpio": 17,
            "profile": "gpio",
            "state": 0,
            "implemented": true
          },
          {
            "channel_id": 12,
            "name": "AIN1",
            "type": "analog_input",
            "gpio": 34,
            "profile": "adc",
            "value": 1820,
            "implemented": true
          },
          {
            "channel_id": 13,
            "name": "AIN2",
            "type": "analog_input",
            "gpio": 35,
            "profile": "adc",
            "value": 2048,
            "implemented": true
          }
        ],
        "outputs": [
          {
            "channel_id": 100,
            "name": "OUT101",
            "type": "digital_output",
            "gpio": 2,
            "profile": "relay",
            "desired": 1,
            "reported": 1,
            "failsafe": false,
            "driver_enabled": true,
            "physical_present": true,
            "control_path": "V2",
            "last_transition": "state_set_int -> pending_mask -> gpio_set_level"
          },
          {
            "channel_id": 115,
            "name": "OUT116",
            "type": "digital_output",
            "gpio": 4,
            "profile": "relay",
            "desired": 0,
            "reported": 0,
            "failsafe": true,
            "driver_enabled": true,
            "physical_present": true,
            "control_path": "V2",
            "last_transition": ""
          }
        ]
      };

      final response = IoMapResponse.fromJson(sampleJson);

      // Entradas Digitais
      expect(response.digitalInputs.length, 2);
      final in0 = response.digitalInputs[0];
      expect(in0.channelId, 10);
      expect(in0.logicalAddress, 'I0.0');
      expect(in0.channelName, 'IN1');
      expect(in0.gpio, 16);
      expect(in0.profile, 'gpio');
      expect(in0.state, 1);
      expect(in0.isOn, true);

      final in15 = response.digitalInputs[1];
      expect(in15.channelId, 25);
      expect(in15.logicalAddress, 'I0.15');
      expect(in15.channelName, 'IN16');
      expect(in15.gpio, 17);
      expect(in15.state, 0);
      expect(in15.isOn, false);

      // Entradas Analógicas
      expect(response.analogInputs.length, 2);
      final ain1 = response.analogInputs[0];
      expect(ain1.channelId, 12);
      expect(ain1.logicalAddress, 'AI0.2');
      expect(ain1.gpio, 34);
      expect(ain1.state, 1820);

      final ain2 = response.analogInputs[1];
      expect(ain2.channelId, 13);
      expect(ain2.logicalAddress, 'AI0.3');
      expect(ain2.gpio, 35);
      expect(ain2.state, 2048);

      // Saídas Digitais
      expect(response.digitalOutputs.length, 2);
      final out0 = response.digitalOutputs[0];
      expect(out0.channelId, 100);
      expect(out0.logicalAddress, 'Q0.0');
      expect(out0.channelName, 'OUT101');
      expect(out0.gpio, 2);
      expect(out0.profile, 'relay');
      expect(out0.desired, 1);
      expect(out0.reported, 1);
      expect(out0.isOn, true);
      expect(out0.failsafe, false);
      expect(out0.physicalPresent, true);

      final out15 = response.digitalOutputs[1];
      expect(out15.channelId, 115);
      expect(out15.logicalAddress, 'Q0.15');
      expect(out15.channelName, 'OUT116');
      expect(out15.gpio, 4);
      expect(out15.desired, 0);
      expect(out15.reported, 0);
      expect(out15.isOn, false);
      expect(out15.failsafe, true);
    });

    test('Empty json gracefully handled', () {
      final response = IoMapResponse.fromJson({});
      expect(response.digitalInputs, isEmpty);
      expect(response.digitalOutputs, isEmpty);
      expect(response.analogInputs, isEmpty);
      expect(response.analogOutputs, isEmpty);
    });
  });
}
