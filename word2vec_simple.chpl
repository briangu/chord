use BlockDist, CyclicDist, BlockCycDist, ReplicatedDist, Time;
/*use String;*/

/*require "word2vec.h";*/

config const textFile = "data.txt";

config const MAX_STRING = 100;
config const EXP_TABLE_SIZE = 1000;
config const MAX_EXP = 6;
config const MAX_SENTENCE_LENGTH = 1000;
config const MAX_CODE_LENGTH = 40;

config const log_level = 2;

config const vocab_hash_size = 30000000;  // Maximum 30 * 0.7 = 21M words in the vocabulary
config const initial_vocab_max_size = 1000;

config const min_count = 5;

const SPACE = ascii(' '): uint(8);
const TAB = ascii('\t'): uint(8);
const CRLF = ascii('\n'): uint(8);

class VocabWord {
  var len: int = MAX_STRING;
  var word: [0..#len] uint(8);
}

record VocabEntry {
  var word: VocabWord = nil;
  var cn: int(64);
};

var vocab_size = 0;
var vocab_max_size = initial_vocab_max_size;
var vocabDomain = {0..#vocab_max_size};
var vocab: [vocabDomain] VocabEntry;
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

inline proc GetWordHash(word: VocabWord): int {
  return GetWordHash(word.word, word.len);
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
    var vw = vocab[vocab_hash[hash]].word;
    /* SLOW!
      if (len == vw.len && word[0..#len].equals(vw.word[0..#len])) {
      return vocab_hash[hash];
    }*/
    if (len == vw.len) {
      var found = true;
      for (i) in 0..#len {
        if (word[i] != vw.word[i]) {
          found = false;
          break;
        }
      }
      if found then return vocab_hash[hash];
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
  var vw = new VocabWord(len);
  /*vw.word = word[0..#len];*/
  for (i) in 0..#len {
    vw.word[i] = word[i];
  }
  vocab[vocab_size].word = vw;
  vocab[vocab_size].cn = 0;

  vocab_size += 1;

  // Reallocate memory if needed
  if (vocab_size + 2 >= vocab_max_size) {
    vocab_max_size *= 2;
    vocabDomain = {0..#vocab_max_size};
  }

  var hash = GetWordHash(word, len);
  while (vocab_hash[hash] != -1) {
    hash = (hash + 1) % vocab_hash_size;
  }
  vocab_hash[hash] = vocab_size - 1;
  return vocab_size - 1;
}

private inline proc chpl_sort_cmp(a, b, param reverse=false, param eq=false) {
  if eq {
    if reverse then return a >= b;
    else return a <= b;
  } else {
    if reverse then return a > b;
    else return a < b;
  }
}

proc XInsertionSort(Data: [?Dom] VocabEntry, doublecheck=false, param reverse=false) where Dom.rank == 1 {
  const lo = Dom.low;
  for i in Dom {
    const ithVal = Data(i);
    var inserted = false;
    for j in lo..i-1 by -1 {
      if (chpl_sort_cmp(ithVal.cn, Data(j).cn, reverse)) {
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

proc QuickSort(Data: [?Dom] VocabEntry, minlen=16, doublecheck=false, param reverse=false) where Dom.rank == 1 {
  // grab obvious indices
  const lo = Dom.low,
        hi = Dom.high,
        mid = lo + (hi-lo+1)/2;

  // base case -- use insertion sort
  if (hi - lo < minlen) {
    XInsertionSort(Data, reverse=reverse);
    return;
  }

  // find pivot using median-of-3 method
  if (chpl_sort_cmp(Data(mid).cn, Data(lo).cn, reverse)) then Data(mid) <=> Data(lo);
  if (chpl_sort_cmp(Data(hi).cn, Data(lo).cn, reverse)) then Data(hi) <=> Data(lo);
  if (chpl_sort_cmp(Data(hi).cn, Data(mid).cn, reverse)) then Data(hi) <=> Data(mid);
  const pivotVal = Data(mid);
  Data(mid) = Data(hi-1);
  Data(hi-1) = pivotVal;
  // end median-of-3 partitioning

  var loptr = lo,
      hiptr = hi-1;
  while (loptr < hiptr) {
    do { loptr += 1; } while (chpl_sort_cmp(Data(loptr).cn, pivotVal.cn, reverse));
    do { hiptr -= 1; } while (chpl_sort_cmp(pivotVal.cn, Data(hiptr).cn, reverse));
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
    // Words occuring less than min_count times will be discarded from the vocab
    if ((vocab[a].cn < min_count) && (a != 0)) {
      vocab_size -= 1;

      /*free(vocab[a].word);*/
      vocab[a].word = nil;
      vocab[a].cn = 0;
    } else {
      // Hash will be re-computed, as after the sorting it is not actual
      hash = GetWordHash(vocab[a].word);
      while (vocab_hash[hash] != -1) {
        hash = (hash + 1) % vocab_hash_size;
      }
      vocab_hash[hash] = a;
      train_words += vocab[a].cn;
    }
  }

  vocabDomain = {0..#vocab_size + 1};

  // Allocate memory for the binary tree construction
  /*for (a = 0; a < vocab_size; a++) {
    vocab[a].code = (char *)calloc(MAX_CODE_LENGTH, sizeof(char));
    vocab[a].point = (int *)calloc(MAX_CODE_LENGTH, sizeof(int));
  }*/
}

proc ReduceVocab() {
  /*int a, b = 0;
  unsigned int hash;
  for (a = 0; a < vocab_size; a++) if (vocab[a].cn > min_reduce) {
    vocab[b].cn = vocab[a].cn;
    vocab[b].word = vocab[a].word;
    b++;
  } else free(vocab[a].word);
  vocab_size = b;
  for (a = 0; a < vocab_hash_size; a++) vocab_hash[a] = -1;
  for (a = 0; a < vocab_size; a++) {
    // Hash will be re-computed, as it is not actual
    hash = GetWordHash(vocab[a].word);
    while (vocab_hash[hash] != -1) hash = (hash + 1) % vocab_hash_size;
    vocab_hash[hash] = a;
  }
  fflush(stdout);
  min_reduce++;*/
}

proc CreateBinaryTree() {
  /*long long a, b, i, min1i, min2i, pos1, pos2, point[MAX_CODE_LENGTH];
  char code[MAX_CODE_LENGTH];
  long long *count = (long long *)calloc(vocab_size * 2 + 1, sizeof(long long));
  long long *binary = (long long *)calloc(vocab_size * 2 + 1, sizeof(long long));
  long long *parent_node = (long long *)calloc(vocab_size * 2 + 1, sizeof(long long));
  for (a = 0; a < vocab_size; a++) count[a] = vocab[a].cn;
  for (a = vocab_size; a < vocab_size * 2; a++) count[a] = 1e15;
  pos1 = vocab_size - 1;
  pos2 = vocab_size;
  // Following algorithm constructs the Huffman tree by adding one node at a time
  for (a = 0; a < vocab_size - 1; a++) {
    // First, find two smallest nodes 'min1, min2'
    if (pos1 >= 0) {
      if (count[pos1] < count[pos2]) {
        min1i = pos1;
        pos1--;
      } else {
        min1i = pos2;
        pos2++;
      }
    } else {
      min1i = pos2;
      pos2++;
    }
    if (pos1 >= 0) {
      if (count[pos1] < count[pos2]) {
        min2i = pos1;
        pos1--;
      } else {
        min2i = pos2;
        pos2++;
      }
    } else {
      min2i = pos2;
      pos2++;
    }
    count[vocab_size + a] = count[min1i] + count[min2i];
    parent_node[min1i] = vocab_size + a;
    parent_node[min2i] = vocab_size + a;
    binary[min2i] = 1;
  }
  // Now assign binary code to each vocabulary word
  for (a = 0; a < vocab_size; a++) {
    b = a;
    i = 0;
    while (1) {
      code[i] = binary[b];
      point[i] = b;
      i++;
      b = parent_node[b];
      if (b == vocab_size * 2 - 2) break;
    }
    vocab[a].codelen = i;
    vocab[a].point[0] = vocab_size - 2;
    for (b = 0; b < i; b++) {
      vocab[a].code[i - b - 1] = code[b];
      vocab[a].point[i - b] = point[b] - vocab_size;
    }
  }
  free(count);
  free(binary);
  free(parent_node);*/
}

proc LearnVocabFromTrainFile() {
  var word: [0..#MAX_STRING] uint(8);
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

  if (log_level > 0) {
    var t: Timer;

    writeln("sorting...");
    writeln("Vocab size: ", vocab_size);
    writeln("Words in train file: ", train_words);
    stdout.flush();

    t.start();
    SortVocab();
    t.stop();
    timing("SortVocab in ",t.elapsed(TimeUnits.microseconds), " microseconds");
  }

  if (log_level > 0) {
    writeln("Vocab size: ", vocab_size);
    writeln("Words in train file: ", train_words);
    stdout.flush();
  }

  /*file_size = ftell(fin);*/

  r.close();
  f.close();
}

proc SaveVocab() {
  /*long long i;
  FILE *fo = fopen(save_vocab_file, "wb");
  for (i = 0; i < vocab_size; i++) fprintf(fo, "%s %lld\n", vocab[i].word, vocab[i].cn);
  fclose(fo);*/
}

proc ReadVocab() {
  /*long long a, i = 0;
  char c;
  char word[MAX_STRING];
  FILE *fin = fopen(read_vocab_file, "rb");
  if (fin == NULL) {
    printf("Vocabulary file not found\n");
    exit(1);
  }
  for (a = 0; a < vocab_hash_size; a++) vocab_hash[a] = -1;
  vocab_size = 0;
  while (1) {
    ReadWord(word, fin);
    if (feof(fin)) break;
    a = AddWordToVocab(word);
    fscanf(fin, "%lld%c", &vocab[a].cn, &c);
    i++;
  }
  SortVocab();
  if (debug_mode > 0) {
    printf("Vocab size: %lld\n", vocab_size);
    printf("Words in train file: %lld\n", train_words);
  }
  fin = fopen(train_file, "rb");
  if (fin == NULL) {
    printf("ERROR: training data file not found!\n");
    exit(1);
  }
  fseek(fin, 0, SEEK_END);
  file_size = ftell(fin);
  fclose(fin);*/
}

proc InitNet() {
  /*long long a, b;
  unsigned long long next_random = 1;
  a = posix_memalign((void **)&syn0, 128, (long long)vocab_size * layer1_size * sizeof(real));
  if (syn0 == NULL) {printf("Memory allocation failed\n"); exit(1);}
  if (hs) {
    a = posix_memalign((void **)&syn1, 128, (long long)vocab_size * layer1_size * sizeof(real));
    if (syn1 == NULL) {printf("Memory allocation failed\n"); exit(1);}
    for (a = 0; a < vocab_size; a++) for (b = 0; b < layer1_size; b++)
     syn1[a * layer1_size + b] = 0;
  }
  if (negative>0) {
    a = posix_memalign((void **)&syn1neg, 128, (long long)vocab_size * layer1_size * sizeof(real));
    if (syn1neg == NULL) {printf("Memory allocation failed\n"); exit(1);}
    for (a = 0; a < vocab_size; a++) for (b = 0; b < layer1_size; b++)
     syn1neg[a * layer1_size + b] = 0;
  }
  for (a = 0; a < vocab_size; a++) for (b = 0; b < layer1_size; b++) {
    next_random = next_random * (unsigned long long)25214903917 + 11;
    syn0[a * layer1_size + b] = (((next_random & 0xFFFF) / (real)65536) - 0.5) / layer1_size;
  }
  CreateBinaryTree();*/
}

proc TrainModel() {
  /*long long a, b, d, cw, word, last_word, sentence_length = 0, sentence_position = 0;
  long long word_count = 0, last_word_count = 0, sen[MAX_SENTENCE_LENGTH + 1];
  long long l1, l2, c, target, label, local_iter = iter;
  unsigned long long next_random = (long long)id;
  real f, g;
  clock_t now;
  real *neu1 = (real *)calloc(layer1_size, sizeof(real));
  real *neu1e = (real *)calloc(layer1_size, sizeof(real));
  FILE *fi = fopen(train_file, "rb");
  fseek(fi, file_size / (long long)num_threads * (long long)id, SEEK_SET);
  while (1) {
    if (word_count - last_word_count > 10000) {
      word_count_actual += word_count - last_word_count;
      last_word_count = word_count;
      if ((debug_mode > 1)) {
        now=clock();
        printf("%cAlpha: %f  Progress: %.2f%%  Words/thread/sec: %.2fk  ", 13, alpha,
         word_count_actual / (real)(iter * train_words + 1) * 100,
         word_count_actual / ((real)(now - start + 1) / (real)CLOCKS_PER_SEC * 1000));
        fflush(stdout);
      }
      alpha = starting_alpha * (1 - word_count_actual / (real)(iter * train_words + 1));
      if (alpha < starting_alpha * 0.0001) alpha = starting_alpha * 0.0001;
    }
    if (sentence_length == 0) {
      while (1) {
        word = ReadWordIndex(fi);
        if (feof(fi)) break;
        if (word == -1) continue;
        word_count++;
        if (word == 0) break;
        // The subsampling randomly discards frequent words while keeping the ranking same
        if (sample > 0) {
          real ran = (sqrt(vocab[word].cn / (sample * train_words)) + 1) * (sample * train_words) / vocab[word].cn;
          next_random = next_random * (unsigned long long)25214903917 + 11;
          if (ran < (next_random & 0xFFFF) / (real)65536) continue;
        }
        sen[sentence_length] = word;
        sentence_length++;
        if (sentence_length >= MAX_SENTENCE_LENGTH) break;
      }
      sentence_position = 0;
    }
    if (feof(fi) || (word_count > train_words / num_threads)) {
      word_count_actual += word_count - last_word_count;
      local_iter--;
      if (local_iter == 0) break;
      word_count = 0;
      last_word_count = 0;
      sentence_length = 0;
      fseek(fi, file_size / (long long)num_threads * (long long)id, SEEK_SET);
      continue;
    }
    word = sen[sentence_position];
    if (word == -1) continue;
    for (c = 0; c < layer1_size; c++) neu1[c] = 0;
    for (c = 0; c < layer1_size; c++) neu1e[c] = 0;
    next_random = next_random * (unsigned long long)25214903917 + 11;
    b = next_random % window;
    if (cbow) {  //train the cbow architecture
      // in -> hidden
      cw = 0;
      for (a = b; a < window * 2 + 1 - b; a++) if (a != window) {
        c = sentence_position - window + a;
        if (c < 0) continue;
        if (c >= sentence_length) continue;
        last_word = sen[c];
        if (last_word == -1) continue;
        for (c = 0; c < layer1_size; c++) neu1[c] += syn0[c + last_word * layer1_size];
        cw++;
      }
      if (cw) {
        for (c = 0; c < layer1_size; c++) neu1[c] /= cw;
        if (hs) for (d = 0; d < vocab[word].codelen; d++) {
          f = 0;
          l2 = vocab[word].point[d] * layer1_size;
          // Propagate hidden -> output
          for (c = 0; c < layer1_size; c++) f += neu1[c] * syn1[c + l2];
          if (f <= -MAX_EXP) continue;
          else if (f >= MAX_EXP) continue;
          else f = expTable[(int)((f + MAX_EXP) * (EXP_TABLE_SIZE / MAX_EXP / 2))];
          // 'g' is the gradient multiplied by the learning rate
          g = (1 - vocab[word].code[d] - f) * alpha;
          // Propagate errors output -> hidden
          for (c = 0; c < layer1_size; c++) neu1e[c] += g * syn1[c + l2];
          // Learn weights hidden -> output
          for (c = 0; c < layer1_size; c++) syn1[c + l2] += g * neu1[c];
        }
        // NEGATIVE SAMPLING
        if (negative > 0) for (d = 0; d < negative + 1; d++) {
          if (d == 0) {
            target = word;
            label = 1;
          } else {
            next_random = next_random * (unsigned long long)25214903917 + 11;
            target = table[(next_random >> 16) % table_size];
            if (target == 0) target = next_random % (vocab_size - 1) + 1;
            if (target == word) continue;
            label = 0;
          }
          l2 = target * layer1_size;
          f = 0;
          for (c = 0; c < layer1_size; c++) f += neu1[c] * syn1neg[c + l2];
          if (f > MAX_EXP) g = (label - 1) * alpha;
          else if (f < -MAX_EXP) g = (label - 0) * alpha;
          else g = (label - expTable[(int)((f + MAX_EXP) * (EXP_TABLE_SIZE / MAX_EXP / 2))]) * alpha;
          for (c = 0; c < layer1_size; c++) neu1e[c] += g * syn1neg[c + l2];
          for (c = 0; c < layer1_size; c++) syn1neg[c + l2] += g * neu1[c];
        }
        // hidden -> in
        for (a = b; a < window * 2 + 1 - b; a++) if (a != window) {
          c = sentence_position - window + a;
          if (c < 0) continue;
          if (c >= sentence_length) continue;
          last_word = sen[c];
          if (last_word == -1) continue;
          for (c = 0; c < layer1_size; c++) syn0[c + last_word * layer1_size] += neu1e[c];
        }
      }
    } else {  //train skip-gram
      for (a = b; a < window * 2 + 1 - b; a++) if (a != window) {
        c = sentence_position - window + a;
        if (c < 0) continue;
        if (c >= sentence_length) continue;
        last_word = sen[c];
        if (last_word == -1) continue;
        l1 = last_word * layer1_size;
        for (c = 0; c < layer1_size; c++) neu1e[c] = 0;
        // HIERARCHICAL SOFTMAX
        if (hs) for (d = 0; d < vocab[word].codelen; d++) {
          f = 0;
          l2 = vocab[word].point[d] * layer1_size;
          // Propagate hidden -> output
          for (c = 0; c < layer1_size; c++) f += syn0[c + l1] * syn1[c + l2];
          if (f <= -MAX_EXP) continue;
          else if (f >= MAX_EXP) continue;
          else f = expTable[(int)((f + MAX_EXP) * (EXP_TABLE_SIZE / MAX_EXP / 2))];
          // 'g' is the gradient multiplied by the learning rate
          g = (1 - vocab[word].code[d] - f) * alpha;
          // Propagate errors output -> hidden
          for (c = 0; c < layer1_size; c++) neu1e[c] += g * syn1[c + l2];
          // Learn weights hidden -> output
          for (c = 0; c < layer1_size; c++) syn1[c + l2] += g * syn0[c + l1];
        }
        // NEGATIVE SAMPLING
        if (negative > 0) for (d = 0; d < negative + 1; d++) {
          if (d == 0) {
            target = word;
            label = 1;
          } else {
            next_random = next_random * (unsigned long long)25214903917 + 11;
            target = table[(next_random >> 16) % table_size];
            if (target == 0) target = next_random % (vocab_size - 1) + 1;
            if (target == word) continue;
            label = 0;
          }
          l2 = target * layer1_size;
          f = 0;
          for (c = 0; c < layer1_size; c++) f += syn0[c + l1] * syn1neg[c + l2];
          if (f > MAX_EXP) g = (label - 1) * alpha;
          else if (f < -MAX_EXP) g = (label - 0) * alpha;
          else g = (label - expTable[(int)((f + MAX_EXP) * (EXP_TABLE_SIZE / MAX_EXP / 2))]) * alpha;
          for (c = 0; c < layer1_size; c++) neu1e[c] += g * syn1neg[c + l2];
          for (c = 0; c < layer1_size; c++) syn1neg[c + l2] += g * syn0[c + l1];
        }
        // Learn weights input -> hidden
        for (c = 0; c < layer1_size; c++) syn0[c + l1] += neu1e[c];
      }
    }
    sentence_position++;
    if (sentence_position >= sentence_length) {
      sentence_length = 0;
      continue;
    }
  }
  fclose(fi);
  free(neu1);
  free(neu1e);
  pthread_exit(NULL);*/
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

inline proc timing(args ...?k) {
  if (log_level >= 2) {
    write(here.id, "\t");
    writeln((...args));
  }
}

//
var t: Timer;
t.start();

LearnVocabFromTrainFile();

t.stop();
timing("LearnVocabFromTrainFile in ",t.elapsed(TimeUnits.microseconds), " microseconds");
