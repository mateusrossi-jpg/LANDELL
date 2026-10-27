import '../models/tag_value.dart';

class TagStateStore {
  final Map<String, TagValue> _states = {};
  final Set<String> _forcedTags = {};

  void initTag(String tagId, TagValue initialValue) {
    if (!_forcedTags.contains(tagId)) {
      _states[tagId] = initialValue;
    }
  }

  TagValue? getValue(String tagId) {
    return _states[tagId];
  }

  void setValue(String tagId, TagValue newValue) {
    if (_forcedTags.contains(tagId)) return; // Bloqueia sobrescrita se forçado
    _states[tagId] = newValue;
  }

  bool getBool(String tagId) {
    return _states[tagId]?.boolValue ?? false;
  }

  void setBool(String tagId, bool value) {
    if (_forcedTags.contains(tagId)) return; // Bloqueia sobrescrita se forçado
    _states[tagId] = TagValue.boolean(value);
  }

  int getInt(String tagId) {
    final v = _states[tagId];
    if (v == null) return 0;
    if (v.intValue != null) return v.intValue!;
    if (v.realValue != null) return v.realValue!.round();
    if (v.stringValue != null) return int.tryParse(v.stringValue!) ?? 0;
    return 0;
  }

  void setInt(String tagId, int value) {
    if (_forcedTags.contains(tagId)) return; // Bloqueia sobrescrita se forçado
    _states[tagId] = TagValue(intValue: value, realValue: value.toDouble());
  }

  double getReal(String tagId) {
    final v = _states[tagId];
    if (v == null) return 0.0;
    if (v.realValue != null) return v.realValue!;
    if (v.intValue != null) return v.intValue!.toDouble();
    if (v.stringValue != null) return double.tryParse(v.stringValue!) ?? 0.0;
    return 0.0;
  }

  void setReal(String tagId, double value) {
    if (_forcedTags.contains(tagId)) return; // Bloqueia sobrescrita se forçado
    _states[tagId] = TagValue(realValue: value, intValue: value.round());
  }

  bool isForced(String tagId) {
    return _forcedTags.contains(tagId);
  }

  void forceBool(String tagId, bool value) {
    _forcedTags.add(tagId);
    _states[tagId] = TagValue.boolean(value);
  }

  void forceValue(String tagId, TagValue value) {
    _forcedTags.add(tagId);
    _states[tagId] = value;
  }

  void releaseForce(String tagId) {
    _forcedTags.remove(tagId);
  }

  void releaseAllForces() {
    _forcedTags.clear();
  }
}
