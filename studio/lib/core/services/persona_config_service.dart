import 'package:shared_preferences/shared_preferences.dart';

class OperatorKioskConfig {
  bool showCycleControl;
  bool showActuators;
  bool showEmergency;
  bool showAlarms;
  bool showSensors;
  String recipeName;

  OperatorKioskConfig({
    this.showCycleControl = true,
    this.showActuators = true,
    this.showEmergency = true,
    this.showAlarms = true,
    this.showSensors = true,
    this.recipeName = 'LOTE #A-4802',
  });
}

class ManagerAnalyticsConfig {
  int targetPerHour;
  double oeeTarget;
  String lineName;

  ManagerAnalyticsConfig({
    this.targetPerHour = 1200,
    this.oeeTarget = 85.0,
    this.lineName = 'LINHA DE ENVASAMENTO • CÉLULA 04',
  });
}

class PersonaConfigService {
  static final PersonaConfigService instance = PersonaConfigService._();
  PersonaConfigService._();

  static const _kKioskCycle = 'persona_kiosk_cycle';
  static const _kKioskActuators = 'persona_kiosk_actuators';
  static const _kKioskEmergency = 'persona_kiosk_emergency';
  static const _kKioskAlarms = 'persona_kiosk_alarms';
  static const _kKioskSensors = 'persona_kiosk_sensors';
  static const _kKioskRecipe = 'persona_kiosk_recipe';

  static const _kManagerTarget = 'persona_manager_target';
  static const _kManagerOee = 'persona_manager_oee';
  static const _kManagerLine = 'persona_manager_line';

  Future<OperatorKioskConfig> loadKioskConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return OperatorKioskConfig(
        showCycleControl: prefs.getBool(_kKioskCycle) ?? true,
        showActuators: prefs.getBool(_kKioskActuators) ?? true,
        showEmergency: prefs.getBool(_kKioskEmergency) ?? true,
        showAlarms: prefs.getBool(_kKioskAlarms) ?? true,
        showSensors: prefs.getBool(_kKioskSensors) ?? true,
        recipeName: prefs.getString(_kKioskRecipe) ?? 'LOTE #A-4802',
      );
    } catch (_) {
      return OperatorKioskConfig();
    }
  }

  Future<void> saveKioskConfig(OperatorKioskConfig config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kKioskCycle, config.showCycleControl);
      await prefs.setBool(_kKioskActuators, config.showActuators);
      await prefs.setBool(_kKioskEmergency, config.showEmergency);
      await prefs.setBool(_kKioskAlarms, config.showAlarms);
      await prefs.setBool(_kKioskSensors, config.showSensors);
      await prefs.setString(_kKioskRecipe, config.recipeName);
    } catch (_) {}
  }

  Future<ManagerAnalyticsConfig> loadManagerConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return ManagerAnalyticsConfig(
        targetPerHour: prefs.getInt(_kManagerTarget) ?? 1200,
        oeeTarget: prefs.getDouble(_kManagerOee) ?? 85.0,
        lineName: prefs.getString(_kManagerLine) ?? 'LINHA DE ENVASAMENTO • CÉLULA 04',
      );
    } catch (_) {
      return ManagerAnalyticsConfig();
    }
  }

  Future<void> saveManagerConfig(ManagerAnalyticsConfig config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kManagerTarget, config.targetPerHour);
      await prefs.setDouble(_kManagerOee, config.oeeTarget);
      await prefs.setString(_kManagerLine, config.lineName);
    } catch (_) {}
  }
}
