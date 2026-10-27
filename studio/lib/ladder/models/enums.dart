enum TagType { bool, int, dint, real, string, timer, counter }

enum PortDataType { boolean, analogFloat, timeDuration }

enum PortDirection { input, output }

enum NodeType {
  contactNO,
  contactNC,
  coil,
  timerTON,
  timerTOF,
  counterCTU,
  counterCTD,
  coilSet,
  coilReset,
  compareEqual,
  compareGreater,
  compareLess,
  mathADD,
  mathSUB,
  mathMUL,
  mathDIV,
  pid,
  parallel
}
