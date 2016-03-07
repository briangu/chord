use BlockDist, CyclicDist, BlockCycDist, ReplicatedDist;
use String;
use Regexp;

require "word2vec.h";

config const textFile = "data.txt";

config const MAX_STRING = 100;
config const EXP_TABLE_SIZE = 1000;
config const MAX_EXP = 6;
config const MAX_SENTENCE_LENGTH = 1000;
config const MAX_CODE_LENGTH = 40;

config const debug_mode = true;
config const vocab_hash_size = 30000000;  // Maximum 30 * 0.7 = 21M words in the vocabulary
config const initial_vocab_max_size = 1000;

config const min_count = 5;

const SPACE = ascii(' '): uint(8);
const TAB = ascii('\t'): uint(8);
const CRLF = ascii('\n'): uint(8);

var wordDomain = {0..#MAX_STRING};

class vocab_word {
  var len: int;
  var word: [0..#len] uint(8);
  var cn: int(64);
  /*var point: [MAX_CODE_LENGTH] int;
  var code: [MAX_CODE_LENGTH] int;*/
  /*var codelen: int;*/
};

var vocab_size = 0;
var vocab_max_size = initial_vocab_max_size;
var vocabDomain = {0..#vocab_max_size};
var vocab: [vocabDomain] vocab_word;
var vocab_hash: [0..#vocab_hash_size] int = -1;

var train_words: int = 0;

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

var atCRLF = false;

inline proc readNextChar(ref ch: uint(8), reader): bool {
  if (atCRLF) {
    atCRLF = false;
    ch = CRLF;
    return true;
  } else {
    return reader.read(ch);
  }
}

proc ReadWord(word: [?] uint(8), reader): int {
  var a: int = 0;
  var ch: uint(8);

  while readNextChar(ch, reader) {
    if (ch == 13) then continue;
    if ((ch == SPACE) || (ch == TAB) || (ch == CRLF)) {
      if (a > 0) {
        // TODO: write reader with ungetc
        if (ch == CRLF) then atCRLF = true; //ungetc(ch, fin);
        break;
      }
      if (ch == CRLF) then return WriteSpaceWord(word);
                      else continue;
    }
    word[a] = ch;
    a += 1;
    if (a >= MAX_STRING - 1) then a -= 1; // Truncate too long words
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

  while (1) {
    if (vocab_hash[hash] == -1) then return -1;
    var vw = vocab[vocab_hash[hash]];
    if (len == vw.len && word[0..#len].equals(vw.word[0..#len])) {
      return vocab_hash[hash];
    }
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
    v = new vocab_word(len);
    vocab[vocab_size] = v;
  }
  v.len = len;
  v.word = word[0..#len];
  v.cn = 0;

  vocab_size += 1;

  // Reallocate memory if needed
  if (vocab_size + 2 >= vocab_max_size) {
    vocab_max_size *= 2;
    vocabDomain = {0..#vocab_max_size};
    writeln("new vocab_max_size ", vocab_max_size);
    stdout.flush();
  }

  var hash = GetWordHash(word, len);
  while (vocab_hash[hash] != -1) {
    hash = (hash + 1) % vocab_hash_size;
  }
  vocab_hash[hash] = vocab_size - 1;
  return vocab_size - 1;
}

private inline proc vocabCount(vocab): int {
  return if vocab == nil then 0 else vocab.cn;
}

private inline proc chpl_sort_cmp(a, b, param reverse=false, param eq=false) {
  if eq {
    if reverse then return vocabCount(a) >= vocabCount(b);
    else return vocabCount(a) <= vocabCount(b);
  } else {
    if reverse then return vocabCount(a) > vocabCount(b);
    else return vocabCount(a) < vocabCount(b);
  }
}

proc XInsertionSort(Data: [?Dom] vocab_word, doublecheck=false, param reverse=false) where Dom.rank == 1 {
  const lo = Dom.low;
  for i in Dom {
    const ithVal = Data(i);
    var inserted = false;
    for j in lo..i-1 by -1 {
      if (chpl_sort_cmp(ithVal, Data(j), reverse)) {
        Data(j+1) = Data(j);
      } else {
        Data(j+1) = ithVal;
        inserted = true;
        break;
      }
    }
    if (!inserted) {
      Data(lo) = ithVal;
    }
  }

  /*if (doublecheck) then VerifySort(Data, "InsertionSort", reverse);*/
}

proc QuickSort(Data: [?Dom] vocab_word, minlen=16, doublecheck=false, param reverse=false) where Dom.rank == 1 {
  // grab obvious indices
  const lo = Dom.low,
        hi = Dom.high,
        mid = lo + (hi-lo+1)/2;

  /*writeln();
  writeln(Dom);
  writeln(lo, " ", Data(lo));
  writeln(hi, " ", Data(hi));
  writeln(mid, " ", Data(mid));*/

  // base case -- use insertion sort
  if (hi - lo < minlen) {
    /*writeln("insertion sort");*/
    XInsertionSort(Data, reverse=reverse);
    return;
  }

  // find pivot using median-of-3 method
  if (chpl_sort_cmp(Data(mid), Data(lo), reverse)) then Data(mid) <=> Data(lo);
  if (chpl_sort_cmp(Data(hi), Data(lo), reverse)) then Data(hi) <=> Data(lo);
  if (chpl_sort_cmp(Data(hi), Data(mid), reverse)) then Data(hi) <=> Data(mid);
  const pivotVal = Data(mid);
  Data(mid) = Data(hi-1);
  Data(hi-1) = pivotVal;
  // end median-of-3 partitioning

  var loptr = lo,
      hiptr = hi-1;
  while (loptr < hiptr) {
    do { loptr += 1; } while (chpl_sort_cmp(Data(loptr), pivotVal, reverse));
    do { hiptr -= 1; } while (chpl_sort_cmp(pivotVal, Data(hiptr), reverse));
    if (loptr < hiptr) {
      Data(loptr) <=> Data(hiptr);
    }
  }

  Data(hi-1) = Data(loptr);
  Data(loptr) = pivotVal;

  //  cobegin {
    QuickSort(Data[..loptr-1], reverse=reverse);  // could use unbounded ranges here
    QuickSort(Data[loptr+1..], reverse=reverse);
    //  }

  /*if (doublecheck) then VerifySort(Data, "QuickSort", reverse);*/
}

proc SortVocab() {
  var a: int;
  var size: int;
  var hash: int;

  // Sort the vocabulary and keep </s> at the first position
  QuickSort(vocab[1..], vocab_size - 1, reverse=true);

  vocab_hash = -1;

  size = vocab_size;
  train_words = 0;

  for (a) in 0..#size {
    if (vocab[a] == nil) then continue;

    // Words occuring less than min_count times will be discarded from the vocab
    if ((vocab[a].cn < min_count) && (a != 0)) {
      vocab_size -= 1;
      vocab[a] = nil;
      /*free(vocab[a].word);*/
    } else {
      // Hash will be re-computed, as after the sorting it is not actual
      hash = GetWordHash(vocab[a].word, vocab[a].len);
      while (vocab_hash[hash] != -1) {
        hash = (hash + 1) % vocab_hash_size;
      }
      vocab_hash[hash] = a;
      train_words += vocab[a].cn;
    }
  }

  /*vocab = (struct vocab_word *)realloc(vocab, (vocab_size + 1) * sizeof(struct vocab_word));*/
  vocabDomain = {0..#vocab_size + 1};

  // Allocate memory for the binary tree construction
  /*for (a = 0; a < vocab_size; a++) {
    vocab[a].code = (char *)calloc(MAX_CODE_LENGTH, sizeof(char));
    vocab[a].point = (int *)calloc(MAX_CODE_LENGTH, sizeof(int));
  }*/
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

  writeln("reading...");
  stdout.flush();

  WriteSpaceWord(word);
  AddWordToVocab(word, 4);

  while (1) {
    len = ReadWord(word, r);
    if (len == 0) then break;

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

  writeln("sorting...");
  if (debug_mode > 0) {
    writeln("Vocab size: ", vocab_size);
    writeln("Words in train file: ", train_words);
  }
  stdout.flush();

  SortVocab();

  if (debug_mode > 0) {
    writeln("Vocab size: ", vocab_size);
    writeln("Words in train file: ", train_words);
    stdout.flush();
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

inline proc WriteSpaceWord(word): int {
  word[0] = ascii('<');
  word[1] = ascii('/');
  word[2] = ascii('s');
  word[3] = ascii('>');
  word[4] = 0;
  return 4;
}

//

LearnVocabFromTrainFile();
