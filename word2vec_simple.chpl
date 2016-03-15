use BlockDist, CyclicDist, BlockCycDist, ReplicatedDist, Time, Logging, Random;
use ReplicatedDist;
use VocabSort;

config const log_level = 2;
config const vocab_hash_size = 30000000;  // Maximum 30 * 0.7 = 21M words in the vocabulary
config const initial_vocab_max_size = 1000;
config const min_count = 5;
config const train_file = "";
config const save_vocab_file = "";
config const read_vocab_file = "";
config const output_file = "";
config const hs = 0;
config const negative = 5;
config const layer1_size = 100;
config const iterations = 5;
config const window = 5;
config const cbow = 1;
config const binary = 0;
config const sample = 1e-3;
config const alpha = 0.025 * 2;
config const classes = 0;

class VocabWord {
  var len: int;
  var word: [0..#len] uint(8);
}

class VocabTreeNode {
  var codelen: uint(8);
  var code: [0..#codelen] uint(8);
  var point: [0..#codelen] int;
}

record VocabEntry {
  var word: VocabWord = nil;
  var cn: int(64);
  var node: VocabTreeNode;
};

class ConfigContext {
  var log_level: int;
  var vocab_hash_size: int;
  var initial_vocab_max_size: int;
  var min_count: int;
  var train_file: string;
  var save_vocab_file: string;
  var read_vocab_file: string;
  var output_file: string;
  var hs: int;
  var negative: int;
  var layer1_size: int;
  /*config const random_seed = 0;*/
  var iterations: int;
  var window: int;
  var cbow: int;
  var binary: int;
  var sample = 1e-3;
  var alpha = 0.025 * 2;
  var classes = 0;
}

class VocabContext {
  var vocab_size = 0;
  var vocab_max_size = initial_vocab_max_size;

  const EXP_TABLE_SIZE = 1000;
  const MAX_EXP = 6;
  const MAX_STRING = 100;

  var train_words: int = 0;

  var vocabDomain = {0..#vocab_max_size};
  var vocab: [vocabDomain] VocabEntry;

  var vocab_hash: [0..#vocab_hash_size] int = -1;

  var expTable: [0..#(EXP_TABLE_SIZE+1)] real;

  const table_size: int = 1e8:int;
  var table: [0..#table_size] int;

  proc VocabContext(vocab_size: int, vocab_max_size: int) {
    this.vocab_size = vocab_size;
    this.vocab_max_size = vocab_max_size;
    /*this.EXP_TABLE_SIZE = expTableSize;
    this.MAX_EXP = maxExp;*/

    for (i) in 0..#EXP_TABLE_SIZE {
      expTable[i] = exp((i / EXP_TABLE_SIZE:real * 2 - 1) * MAX_EXP); // Precompute the exp() table
      expTable[i] = expTable[i] / (expTable[i] + 1);                   // Precompute f(x) = x / (x + 1)
    }
  }

  proc InitUnigramTable() {
    var a, i: int;
    var train_words_pow: real = 0;
    var d1: real;
    var power: real = 0.75;
    for (a) in 0..#vocab_size do train_words_pow += vocab[a].cn ** power;
    i = 0;
    d1 = (vocab[i].cn ** power) / train_words_pow;
    for (a) in 0..#table_size {
      table[a] = i;
      if (a / table_size:real > d1) {
        i += 1;
        d1 += (vocab[i].cn ** power) / train_words_pow;
      }
      if (i >= vocab_size) then i = vocab_size - 1;
    }
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

  proc ReadWordIndex(reader): int {
    var word: [0..MAX_STRING] uint(8);
    var len = ReadWord(word, reader);
    if (len == 0) then return -2;
    return SearchVocab(word, len);
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

    vocabDomain = {0..#(vocab_size + 1)};

    // Allocate memory for the binary tree construction
    for (a) in 0..#vocab_size {
      vocab[a].node = new VocabTreeNode();
    }
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
    const MAX_CODE_LENGTH = 40;

    var b: int(64);
    var i: int(64);
    var min1i: int(64);
    var min2i: int(64);
    var pos1: int(64);
    var pos2: int(64);
    var point: [0..#MAX_CODE_LENGTH] int(64);
    var code: [0..#MAX_CODE_LENGTH] uint(8);
    var dom = {0..#(vocab_size*2 + 1)};
    var count: [dom] int(64);
    var binary: [dom] int(64);
    var parent_node: [dom] int(64);

    count = 1e15: int(64);
    for (a) in 0..#vocab_size {
      count[a] = vocab[a].cn;
    }

    pos1 = vocab_size - 1;
    pos2 = vocab_size;

    // Following algorithm constructs the Huffman tree by adding one node at a time
    for (a) in 0..#(vocab_size-1) {
      // First, find two smallest nodes 'min1, min2'
      if (pos1 >= 0) {
        if (count[pos1] < count[pos2]) {
          min1i = pos1;
          pos1 -= 1;
        } else {
          min1i = pos2;
          pos2 += 1;
        }
      } else {
        min1i = pos2;
        pos2 += 1;
      }
      if (pos1 >= 0) {
        if (count[pos1] < count[pos2]) {
          min2i = pos1;
          pos1 -= 1;
        } else {
          min2i = pos2;
          pos2 += 1;
        }
      } else {
        min2i = pos2;
        pos2 += 1;
      }
      count[vocab_size + a] = count[min1i] + count[min2i];
      parent_node[min1i] = vocab_size + a;
      parent_node[min2i] = vocab_size + a;
      binary[min2i] = 1;
    }
    // Now assign binary code to each vocabulary word
    for (a) in 0..#vocab_size {
      b = a;
      i = 0;
      while (1) {
        code[i] = binary[b]: uint(8);
        point[i] = b;
        i += 1;
        b = parent_node[b];
        if (b == vocab_size * 2 - 2) then break;
      }
      vocab[a].node.codelen = i: uint(8);
      vocab[a].node.point[0] = vocab_size - 2;
      for (b) in 0..#i {
        vocab[a].node.code[i - b - 1] = code[b];
        vocab[a].node.point[i - b] = point[b] - vocab_size;
      }
    }
  }

  proc LearnVocabFromTrainFile() {
    var word: [0..#MAX_STRING] uint(8);
    var i: int(64);
    var len: int;

    vocab_hash = -1;

    var f = open(train_file, iomode.r);
    /*if (fin == NULL) {
      printf("ERROR: training data file not found!\n");
      exit(1);
    }*/
    var r = f.reader(kind=ionative, locking=false);

    vocab_size = 0;

    writeSpaceWord(word);
    AddWordToVocab(word, 4);

    while (1) {
      len = ReadWord(word, r);
      if (len == 0) then break;

      train_words += 1;

      if (log_level > 0 && (train_words % 100000 == 0)) {
        write(train_words / 1000, "K\r");
        stdout.flush();
      }

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

    if (log_level > 0) {
      info("Vocab size: ", vocab_size);
      info("Words in train file: ", train_words);
    }

    /*file_size = ftell(fin);*/

    r.close();
    f.close();
  }

  proc SaveVocab() {
    var f = open(save_vocab_file, iomode.cw);
    var w = f.writer(locking=false);
    for (i) in 0..#vocab_size {
      var vw = vocab[i].word;
      /* parallelizes output! [j in 0..#vw.len] w.writef("%c", vw.word[j]);*/
      for (j) in 0..#vw.len {
        w.writef("%c", vw.word[j]);
      }
      w.writeln(" ", vocab[i].cn);
    }
    w.close();
    f.close();
  }

  proc ReadVocab() {
    var a: int(64);
    var cn: int;
    var c: uint(8);
    var len: int;
    var word: [0..#MAX_STRING] uint(8);

    var f = open(read_vocab_file, iomode.r);
    /*if (fin == NULL) {
      printf("Vocabulary file not found\n");
      exit(1);
    }*/
    var r = f.reader(kind=ionative);

    vocab_hash = -1;
    vocab_size = 0;
    train_words = 0;

    while (1) {
      len = ReadWord(word, r);
      if (len == 0) then break;
      a = AddWordToVocab(word, len);

      // read and compute word count
      len = ReadWord(word, r);
      if (len == 0) then break;
      vocab[a].cn = wordToInt(word, len);
      train_words += vocab[a].cn;

      // skip CRLF
      ReadWord(word, r);
    }

    r.close();
    f.close();

    /*SortVocab();*/
    if (log_level > 0) {
      writeln("Vocab size: ", vocab_size);
      writeln("Words in train file: ", train_words);
    }

    /*file_size = ftell(fin);*/
    for (a) in 0..#vocab_size {
      vocab[a].node = new VocabTreeNode();
    }
  }
}

class TaskContext {
  var configContext: ConfigContext;
  var vocabContext: VocabContext;

  var word_count_actual = 0;
  var starting_alpha: real;
  var atCRLF = false;
}

const Space = {0..Locales.size-1};
const ReplicatedSpace = Space dmapped ReplicatedDist();
var Partitions: [ReplicatedSpace] TaskContext;

for loc in Locales {
  on loc {
    var configContext = new ConfigContext(
      log_level,
      vocab_hash_size,
      initial_vocab_max_size,
      min_count,
      train_file,
      save_vocab_file,
      read_vocab_file,
      output_file,
      hs,
      negative,
      layer1_size,
      iterations,
      window,
      cbow,
      binary,
      sample,
      alpha,
      classes
    );

    var vocabContext = new VocabContext(
      configContext.initial_vocab_max_size,
      configContext.vocab_hash_size
      );

    Partitions[here.id] = new TaskContext(configContext, vocabContext);
  }
}

class NetworkContext {
  var vocab_size: int;
  var layer1_size: int;

  var syn0Domain = {0..#vocab_size*layer1_size};
  var syn0: [syn0Domain] real;

  var syn1Domain = {0..#1};
  var syn1: [syn1Domain] real;

  var syn1negDomain = {0..#1};
  var syn1neg: [syn1negDomain] real;

  proc InitNet() {
    syn0Domain = {0..#vocab_size*layer1_size};

    if (hs) {
      syn1Domain = syn0Domain;
      syn1 = 0;
    }

    if (negative > 0) {
      syn1negDomain = syn0Domain;
      syn1neg = 0;
    }

    var next_random: uint(64) = 1;
    for (a) in 0..#vocab_size {
      for (b) in 0..#layer1_size {
        next_random = next_random * 25214903917:uint(64) + 11;
        syn0[a * layer1_size + b] = (((next_random & 0xFFFF) / 65536:real) - 0.5) / layer1_size;
      }
    }

    /*CreateBinaryTree();*/
  }
}

inline proc readNextChar(ref ch: uint(8), reader): bool {
  if (atCRLF) {
    atCRLF = false;
    ch = CRLF;
    return true;
  } else {
    return reader.read(ch);
  }
}

proc ReadWord(word: [?D] uint(8), reader): int {
  const SPACE = ascii(' '): uint(8);
  const TAB = ascii('\t'): uint(8);
  const CRLF = ascii('\n'): uint(8);

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

proc TrainModelThread(taskContext: TaskContext) {
  const MAX_SENTENCE_LENGTH = 1000;

  var a, d, cw, word, last_word, l1, l2, c, target, labelx: int;
  var b: int(64);
  var sentence_length = 0;
  var sentence_position = 0;
  var word_count = 0;
  var last_word_count = 0;
  var sen: [0..#(MAX_SENTENCE_LENGTH + 1)] int;
  var local_iter = iterations;
  var f, g: real;
  var t: Timer;

  var neuDomain = {0..#layer1_size};
  var neu1: [neuDomain] real = 0.0;
  var neu1e: [neuDomain] real = 0.0;

  var trainFile = open(taskContext.configContext.train_file, iomode.r);
  var fileChunkSize = trainFile.length() / Locales.size;
  var seekStart = fileChunkSize * here.id;
  var seekStop = fileChunkSize * (here.id + 1);
  var reader = trainFile.reader(kind = ionative, start=seekStart, end=seekStop);
  var next_random: uint(64) = here.id:uint(64); //(randStreamSeeded.getNext() * 25214903917:uint(64) + 11):uint(64);
  var atEOF = false;

  t.start();
  var start = t.elapsed(TimeUnits.microseconds);

  while (1) {
    /*writeln(train_words, " ", word_count, " ", last_word_count, " ", word_count_actual);*/
    if (word_count - last_word_count > 10000) {
      word_count_actual += word_count - last_word_count;
      last_word_count = word_count;
      if (log_level > 1) {
        var now = t.elapsed(TimeUnits.milliseconds);
        write("\rAlpha: ", alpha,
              "  word_count_actual: ", word_count_actual,
              "  iterations ", iterations, " local_iter ", local_iter, " train_words ", train_words, " ", (iterations * train_words + 1):real,
              "  Progress: ", (word_count_actual / (iterations * train_words + 1):real),
              "  Words/thread/sec: ", word_count_actual / ((now - start + 1) / 1000) / 1000, "k");
        stdout.flush();
      }
      alpha = starting_alpha * (1 - word_count_actual / (iterations * train_words + 1):real);
      if (alpha < starting_alpha * 0.0001) then alpha = starting_alpha * 0.0001;
    }
    if (sentence_length == 0) {
      while (1) {
        word = ReadWordIndex(reader);
        if (word == -2) {
          atEOF = true;
          break;
        }
        if (word == -1) then continue;
        word_count += 1;
        if (word == 0) then break;
        // The subsampling randomly discards frequent words while keeping the ranking same
        if (sample > 0) {
          var ran = (sqrt(vocab[word].cn / (sample * train_words):real) + 1) * (sample * train_words):real / vocab[word].cn;
          /*next_random = (randStreamSeeded.getNext() * 25214903917:uint(64) + 11):uint(64);*/
          next_random = (next_random * 25214903917:uint(64) + 11):uint(64);
          if (ran < (next_random & 0xFFFF):real / 65536:real) then continue;
        }
        sen[sentence_length] = word;
        sentence_length += 1;
        if (sentence_length >= MAX_SENTENCE_LENGTH) then break;
      }
      sentence_position = 0;
    }
    if (atEOF || (word_count > train_words / Locales.size)) {
      word_count_actual += word_count - last_word_count;
      local_iter -= 1;
      if (local_iter == 0) then break;
      word_count = 0;
      last_word_count = 0;
      sentence_length = 0;
      reader.close();
      reader = trainFile.reader(kind = ionative, start=seekStart, end=seekStop);
      atEOF = false;
      continue;
    }
    word = sen[sentence_position];
    if (word == -1) then continue;
    for (c) in 0..#layer1_size {
      neu1[c] = 0;
      neu1e[c] = 0;
    }
    /*next_random = (randStreamSeeded.getNext() * 25214903917:uint(64) + 11):uint(64);*/
    next_random = (next_random * 25214903917:uint(64) + 11):uint(64);
    b = (next_random % window: uint(64)):int(64);
    if (cbow) {  //train the cbow architecture
      // in -> hidden
      cw = 0;
      for (a) in b..(window * 2 - b) {
        if (a != window) {
          c = sentence_position - window + a;
          if (c < 0) then continue;
          if (c >= sentence_length) then continue;
          last_word = sen[c];
          if (last_word == -1) then continue;
          for (c) in 0..#layer1_size do neu1[c] += syn0[c + last_word * layer1_size];
          cw += 1;
        }
      }
      if (cw) {
        for (c) in 0..#layer1_size do neu1[c] /= cw;
        /*neu1 /= cw;*/
        if (hs) {
           for (d) in 0..#vocab[word].node.codelen {
            f = 0;
            l2 = vocab[word].node.point[d] * layer1_size;
            /*writeln(l2);*/
            // Propagate hidden -> output
            for (c) in 0..#layer1_size do f += neu1[c] * syn1[c + l2];
            if (f <= -MAX_EXP) then continue;
            else if (f >= MAX_EXP) then continue;
            else {
              var idx = floor((f + MAX_EXP) * (EXP_TABLE_SIZE / MAX_EXP / 2)):int;
              f = expTable[idx];
            }
            // 'g' is the gradient multiplied by the learning rate
            g = (1 - vocab[word].node.code[d] - f) * alpha;
            /*writeln(alpha, " ", f, " ", g);*/
            // Propagate errors output -> hidden
            for (c) in 0..#layer1_size do neu1e[c] += g * syn1[c + l2];
            // Learn weights hidden -> output
            for (c) in 0..#layer1_size do syn1[c + l2] += g * neu1[c];
          }
        }
        // NEGATIVE SAMPLING
        if (negative > 0) {
          for (d) in 0..#(negative + 1) {
            if (d == 0) {
              target = word;
              labelx = 1;
            } else {
              /*next_random = (randStreamSeeded.getNext() * 25214903917:uint(64) + 11):uint(64);*/
              next_random = (next_random * 25214903917:uint(64) + 11):uint(64);
              target = table[((next_random >> 16) % table_size:uint(64)):int];
              if (target == 0) then target = (next_random % (vocab_size - 1):uint(64) + 1):int;
              if (target == word) then continue;
              labelx = 0;
            }
            l2 = target * layer1_size;
            f = 0;
            for (c) in 0..#layer1_size do f += neu1[c] * syn1neg[c + l2];
            if (f > MAX_EXP) then g = (labelx - 1) * alpha;
            else if (f < -MAX_EXP) then g = (labelx - 0) * alpha;
            else g = (labelx - expTable[((f + MAX_EXP) * (EXP_TABLE_SIZE / MAX_EXP / 2)):int]) * alpha;
            for (c) in 0..#layer1_size do neu1e[c] += g * syn1neg[c + l2];
            for (c) in 0..#layer1_size do syn1neg[c + l2] += g * neu1[c];
          }
        }
        // hidden -> in
        for (a) in b..(window * 2 - b) {
          if (a != window) {
            c = sentence_position - window + a;
            if (c < 0) then continue;
            if (c >= sentence_length) then continue;
            last_word = sen[c];
            if (last_word == -1) then continue;
            for (c) in 0..#layer1_size do syn0[c + last_word * layer1_size] += neu1e[c];
          }
        }
      }
    } else {  //train skip-gram
      /*for (a = b; a < window * 2 + 1 - b; a++) if (a != window) {
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
      }*/
    }
    sentence_position += 1;
    if (sentence_position >= sentence_length) {
      sentence_length = 0;
      continue;
    }
  }
  t.stop();
  reader.close();
  trainFile.close();
  writeln();
}

proc TrainModel() {
  var a, b, c, d: int;
  var t: Timer;

  info("Starting training using file ", train_file);
  starting_alpha = alpha;
  if (read_vocab_file != "") then ReadVocab(); else LearnVocabFromTrainFile();
  if (save_vocab_file != "") then SaveVocab();
  if (output_file == "") then return;

  InitNet();
  CreateBinaryTree();

  if (negative > 0) then InitUnigramTable();

  forall loc in Locales {
    on loc {
      var tf = train_file;
      /*local {*/
        TrainModelThread(tf);
      /*}*/
    }
  }

  var outputFile = open(output_file, iomode.cw);
  var writer = outputFile.writer(locking=false);
  if (classes == 0) {
    // Save the word vectors
    /*fprintf(fo, "%lld %lld\n", vocab_size, layer1_size);*/
    writer.writeln(vocab_size, " ", layer1_size);
    for (a) in 0..#vocab_size {
      var vw = vocab[a].word;
      /*fprintf(fo, "%s ", vocab[a].word);*/
      for (j) in 0..#vw.len {
        writer.writef("%c", vw.word[j]);
      }
      writer.write(" ");
      if (binary) then for (b) in 0..#layer1_size do writer.writef("%|4r", syn0[a * layer1_size + b]);
      else for (b) in 0..#layer1_size do writer.write(syn0[a * layer1_size + b], " ");
      writer.writeln();
    }
  }/* else {
    // Run K-means on the word vectors
    int clcn = classes, iter = 10, closeid;
    int *centcn = (int *)malloc(classes * sizeof(int));
    int *cl = (int *)calloc(vocab_size, sizeof(int));
    real closev, x;
    real *cent = (real *)calloc(classes * layer1_size, sizeof(real));
    for (a = 0; a < vocab_size; a++) cl[a] = a % clcn;
    for (a = 0; a < iter; a++) {
      for (b = 0; b < clcn * layer1_size; b++) cent[b] = 0;
      for (b = 0; b < clcn; b++) centcn[b] = 1;
      for (c = 0; c < vocab_size; c++) {
        for (d = 0; d < layer1_size; d++) cent[layer1_size * cl[c] + d] += syn0[c * layer1_size + d];
        centcn[cl[c]]++;
      }
      for (b = 0; b < clcn; b++) {
        closev = 0;
        for (c = 0; c < layer1_size; c++) {
          cent[layer1_size * b + c] /= centcn[b];
          closev += cent[layer1_size * b + c] * cent[layer1_size * b + c];
        }
        closev = sqrt(closev);
        for (c = 0; c < layer1_size; c++) cent[layer1_size * b + c] /= closev;
      }
      for (c = 0; c < vocab_size; c++) {
        closev = -10;
        closeid = 0;
        for (d = 0; d < clcn; d++) {
          x = 0;
          for (b = 0; b < layer1_size; b++) x += cent[layer1_size * d + b] * syn0[c * layer1_size + b];
          if (x > closev) {
            closev = x;
            closeid = d;
          }
        }
        cl[c] = closeid;
      }
    }
    // Save the K-means classes
    for (a = 0; a < vocab_size; a++) fprintf(fo, "%s %d\n", vocab[a].word, cl[a]);
    free(centcn);
    free(cent);
    free(cl);
  }
  fclose(fo);*/
  writer.close();
  outputFile.close();
}

// Utilities

inline proc writeSpaceWord(word): int {
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

inline proc wordToInt(word: [?] uint(8), len: int): int {
  var cn = 0;
  var x = 1;
  for (i) in 0..#len by -1 {
    cn += x * (word[i] - 48);
    x *= 10;
  }
  return cn;
}

TrainModel();
