module WordUtil {

  inline proc readNextChar(ref ch: uint(8), reader, ref atCRLF: bool): bool {
    const CRLF = ascii('\n'): uint(8);

    if (atCRLF) {
      atCRLF = false;
      ch = CRLF;
      return true;
    } else {
      return reader.read(ch);
    }
  }

  proc ReadWord(word: [?D] uint(8), reader, ref atCRLF: bool): int {
    const SPACE = ascii(' '): uint(8);
    const TAB = ascii('\t'): uint(8);
    const CRLF = ascii('\n'): uint(8);

    var a: int = 0;
    var ch: uint(8);

    while readNextChar(ch, reader, atCRLF) {
      if (ch == 13) then continue;
      if ((ch == SPACE) || (ch == TAB) || (ch == CRLF)) {
        if (a > 0) {
          // TODO: write reader with ungetc
          if (ch == CRLF) then atCRLF = true; //ungetc(ch, fin);
          break;
        }
        if (ch == CRLF) then return writeSpaceWord(word);
                        else continue;
      }
      word[a] = ch;
      a += 1;
      if (a >= D.high - 1) then a -= 1; // Truncate too long words
    }
    word[a] = 0;
    return a;
  }

  inline proc writeSpaceWord(word): int {
    word[0] = ascii('<');
    word[1] = ascii('/');
    word[2] = ascii('s');
    word[3] = ascii('>');
    word[4] = 0;
    return 4;
  }

  inline proc wordToInt(word: [?] uint(8), len: int): int {
    var cn = 0;
    var x = 1;
    for (i) in 0..#len by -1 {
      cn += x * (word[i] - 48);
      x *= 10;
    }
    return cn;
  }
}
