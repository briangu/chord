use BlockDist, CyclicDist, BlockCycDist, ReplicatedDist;
use String;
use Regexp;

config const textFile = "data.txt";

config const MAX_STRING = 100;
config const EXP_TABLE_SIZE = 1000;
config const MAX_EXP = 6;
config const MAX_SENTENCE_LENGTH = 1000;
config const MAX_CODE_LENGTH = 40;

config const debug_mode = true;
config const vocab_hash_size = 30000000;  // Maximum 30 * 0.7 = 21M words in the vocabulary
config const initial_vocab_max_size = 1000;

const SPACE = ascii(' ');
const TAB = ascii('\t');
const CRLF = ascii('\n');

var wordDomain = {0..#MAX_STRING};

class vocab_word {
  var cn: int(64);
  /*var point: [MAX_CODE_LENGTH] int;
  var code: [MAX_CODE_LENGTH] int;*/
  var len: int;
  var word: [wordDomain] uint(8);
  /*var codelen: int;*/
};

var vocab_size = 0;
var vocab_max_size = initial_vocab_max_size;
var vocabDomain = {0..#vocab_max_size};
var vocab: [vocabDomain] vocab_word;
var vocab_hash: [0..#vocab_hash_size] int = -1;

var train_words: uint(64) = 0;

/*void InitUnigramTable() {
  int a, i;
  double train_words_pow = 0;
  double d1, power = 0.75;
  table = (int *)malloc(table_size * sizeof(int));
  for (a = 0; a < vocab_size; a++) train_words_pow += pow(vocab[a].cn, power);
  i = 0;
  d1 = pow(vocab[i].cn, power) / train_words_pow;
  for (a = 0; a < table_size; a++) {
    table[a] = i;
    if (a / (double)table_size > d1) {
      i++;
      d1 += pow(vocab[i].cn, power) / train_words_pow;
    }
    if (i >= vocab_size) i = vocab_size - 1;
  }
}*/

proc ReadWord(word: [?] uint(8), reader): int {
  var a: int = 0;
  var ch: uint(8);

  /*word = 0;*/

  while reader.read(ch) {
    if (ch == 13) {
      continue;
    }
    if ((ch == SPACE) || (ch == TAB) || (ch == CRLF)) {
      if (a > 0) {
        // TODO: write reader with ungetc
        /*if (ch == '\n') ungetc(ch, fin);*/
        break;
      }
      if (ch == CRLF) {
        WriteSpaceWord(word);
        return 4;
      } else {
        continue;
      }
    }
    word[a] = ch;
    a += 1;
    if (a >= MAX_STRING - 1) {
      a -= 1;   // Truncate too long words
    }
  }
  word[a] = 0;
  return a;
}

inline proc GetWordHash(word: [?] uint(8), len: int): int {
  var hash: uint = 0;
  for (ch) in 0..#len {
    hash = hash * 257 + word[ch]: uint;
  }
  hash = hash % vocab_hash_size: uint;
  return hash: int;
}

// Returns position of a word in the vocabulary; if the word is not found, returns -1
proc SearchVocab(word: [?D] uint(8), len: int): int {
  var hash = GetWordHash(word, len);

  /*var idx = -1;*/
  while (1) {
    if (vocab_hash[hash] == -1) {
      return -1;
    }
    var vw = vocab[vocab_hash[hash]];
    if (len == vw.len && word[0..#len].equals(vw.word[0..#len])) {
      /*writeln("eq word: ", word, " vw.word ", vw.word);*/
      return vocab_hash[hash];
    }
    /*writeln("word: ", word, " vw.word ", vw.word);*/
    hash = (hash + 1) % vocab_hash_size;
  }

  return -1;
}

proc ReadWordIndex(): int {
  return -1;
}

// Adds a word to the vocabulary
proc AddWordToVocab(word: [?D] uint(8), len: int): int {
  var v = vocab[vocab_size];
  if (v == nil) {
    v = new vocab_word();
    vocab[vocab_size] = v;
  }
  v.len = len;
  v.word = word[0..#len];
  v.cn = 0;

  vocab_size += 1;

  // Reallocate memory if needed
  /*if (vocab_size + 2 >= vocab_max_size) {
    vocab_max_size *= 2;
    vocabDomain = {0..#vocab_max_size};
  }*/

  var hash = GetWordHash(word, len);
  while (vocab_hash[hash] != -1) {
    hash = (hash + 1) % vocab_hash_size;
  }
  vocab_hash[hash] = vocab_size - 1;
  return vocab_size - 1;
}

proc SortVocab() {

}

proc ReduceVocab() {

}

proc CreateBinaryTree() {

}

proc LearnVocabFromTrainFile() {
  var word: [wordDomain] uint(8);
  var i: int(64);
  var len: int;

  vocab_hash = -1;

  var f = open(textFile, iomode.r);
  /*if (fin == NULL) {
    printf("ERROR: training data file not found!\n");
    exit(1);
  }*/
  var r = f.reader(kind=ionative);

  vocab_size = 0;

  WriteSpaceWord(word);
  AddWordToVocab(word, 4);

  while (1) {
    len = ReadWord(word, r);
    if (len == 0) {
      break;
    }

    train_words += 1;

    /*if (debug_mode && (train_words % 100000 == 0)) {*/
      /*write(train_words / 1000, "\r");
      stdout.flush();*/
    /*}*/

    i = SearchVocab(word, len);
    if (i == -1) {
      var a = AddWordToVocab(word, len);
      vocab[a].cn = 1;
    } else {
      vocab[i].cn += 1;
    }
    /*if (vocab_size > vocab_hash_size * 0.7) {
      ReduceVocab();
    }*/
  }

  SortVocab();

  if (debug_mode > 0) {
    writeln("Vocab size: ", vocab_size);
    writeln("Words in train file: ", train_words);
  }

  /*file_size = ftell(fin);*/

  r.close();
  f.close();
}

proc SaveVocab() {

}

proc ReadVocab() {
}

proc InitNet() {
}

proc TrainModel() {

}

// Utilities

inline proc WriteSpaceWord(word) {
  word[0] = ascii('<');
  word[1] = ascii('/');
  word[2] = ascii('s');
  word[3] = ascii('>');
  word[4] = 0;
}

//

LearnVocabFromTrainFile();
