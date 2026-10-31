// ENDAP Ladder Engine Opcodes
// ignore_for_file: constant_identifier_names

class Opcodes {
  // Ler valor de Tag para a Pilha
  static const int LD = 0x01;
  static const int LDN = 0x02; // Load NOT

  // Operações Lógicas com a Pilha
  static const int AND = 0x03;
  static const int ANDN = 0x04; // And NOT
  static const int OR = 0x05;
  static const int ORN = 0x06; // Or NOT

  // Escrita de Saídas
  static const int ST = 0x10; // Store (Bobina Simples)
  static const int SET = 0x11; // Latch (Set)
  static const int RST = 0x12; // Unlatch (Reset)
  
  // Controle de Bloco Paralelo
  static const int OR_BLOCK_START = 0x20;
  static const int OR_BLOCK_NEXT = 0x21;
  static const int OR_BLOCK_END = 0x22;

  // Temporizadores e Contadores
  static const int TON = 0x30;
  static const int TOF = 0x31;
  static const int CTU = 0x32;
  static const int CTD = 0x33;

  // Comparações e Operações
  static const int EQU = 0x40;
  static const int GRT = 0x41;
  static const int LES = 0x42;
  static const int ADD = 0x50;
  static const int SUB = 0x51;
  static const int MUL = 0x52;
  static const int DIV = 0x53;

  // Controle de Processo
  static const int PID = 0x60; // legado (12 bytes de operando)
  static const int PIDX = 0x61; // PID industrial (23 bytes de operando)
}
