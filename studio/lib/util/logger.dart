// Simple logger – prints to console. No external dependencies.
// ignore_for_file: avoid_print
class SimpleLogger {
  const SimpleLogger();

  void log(String message) {
    // Using print ensures visibility in debug console.
    // In production you could replace with a more robust solution.
    print('[LOG] $message');
  }
}
