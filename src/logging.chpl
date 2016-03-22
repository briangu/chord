module Logging {

  config const debug_mode = 2;

  inline proc debug(args ...?k) {
    if (debug_mode >= 5) {
      write(here.id, "\t");
      writeln((...args));
      stdout.flush();
    }
  }

  inline proc info(args ...?k) {
    if (debug_mode >= 1) {
      write(here.id, "\t");
      writeln((...args));
      stdout.flush();
    }
  }

  inline proc timing(args ...?k) {
    if (debug_mode >= 2) {
      write(here.id, "\t");
      writeln((...args));
      stdout.flush();
    }
  }

  inline proc error(args ...?k) {
    write(here.id, "\tERROR\t");
    writeln((...args));
    stdout.flush();
  }
}
