use BlockDist, CyclicDist, BlockCycDist, ReplicatedDist, Time, Logging, Random, WordUtil;

// NOTE: these are all on locale 0 and should not be accessed directly from tasks
config const x_log_level = 2;
config const x_vocab_hash_size = 30000000;  // Maximum 30 * 0.7 = 21M words in the vocabulary
config const x_initial_vocab_max_size = 1000;
config const x_min_count = 5;
config const x_train_file = "";
config const x_save_vocab_file = "";
config const x_read_vocab_file = "";
config const x_output_file = "";
config const x_hs = 0;
config const x_negative = 5;
config const x_layer1_size = 100;
config const x_iterations = 5;
config const x_window = 5;
config const x_cbow = 1;
config const x_binary = 0;
config const x_sample = 1e-3;
config const x_alpha = 0.025 * 2;
config const x_classes = 0;

const Space = {0..Locales.size-1};
const ReplicatedSpace = Space dmapped ReplicatedDist();
var ConfigPartitions: [ReplicatedSpace] ConfigContext;
var VocabPartitions: [ReplicatedSpace] VocabContext;
var NetworkPartitions: [ReplicatedSpace] NetworkContext;


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

proc QuickSort(Data: [?Dom] VocabEntry, minlen=7, doublecheck=false, param reverse=false) where Dom.rank == 1 {
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
  var vocab_hash_size: int;
  var vocab_max_size: int;
  var min_count: int;

  var vocab_size = 0;

  const EXP_TABLE_SIZE = 1000;
  const MAX_EXP = 6;
  const MAX_STRING = 100;
  const MAX_CODE_LENGTH = 40: uint(8);

  var train_words: int = 0;

  var vocabDomain = {0..#vocab_max_size};
  var vocab: [vocabDomain] VocabEntry;

  var vocabHashDomain = {0..#vocab_hash_size};
  var vocab_hash: [vocabHashDomain] int = -1;

  var expTable: [0..#(EXP_TABLE_SIZE+1)] real;

  const table_size: int = 1e8:int;
  var table: [0..#table_size] int;

  proc VocabContext(vocab_hash_size: int, vocab_max_size: int, min_count: int) {
    this.vocab_hash_size = vocab_hash_size;
    this.vocab_max_size = vocab_max_size;
    this.min_count = min_count;
    this.vocabDomain = {0..#vocab_max_size};
    this.vocabHashDomain = {0..#vocab_hash_size};

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

  proc ReadWordIndex(reader, ref atCRLF: bool): int {
    var word: [0..MAX_STRING] uint(8);
    var len = ReadWord(word, reader, atCRLF);
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
      vocab[a].node = new VocabTreeNode(MAX_CODE_LENGTH);
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

  proc LearnVocabFromTrainFile(train_file: string) {
    var word: [0..#MAX_STRING] uint(8);
    var i: int(64);
    var len: int;
    var atCRLF = false;

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
      len = ReadWord(word, r, atCRLF);
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

  proc SaveVocab(save_vocab_file: string) {
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

  proc ReadVocab(read_vocab_file: string) {
    var a: int(64);
    var cn: int;
    var c: uint(8);
    var len: int;
    var word: [0..#MAX_STRING] uint(8);
    var atCRLF = false;

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
      len = ReadWord(word, r, atCRLF);
      if (len == 0) then break;
      a = AddWordToVocab(word, len);

      // read and compute word count
      len = ReadWord(word, r, atCRLF);
      if (len == 0) then break;
      vocab[a].cn = wordToInt(word, len);
      train_words += vocab[a].cn;

      // skip CRLF
      ReadWord(word, r, atCRLF);
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
      vocab[a].node = new VocabTreeNode(MAX_CODE_LENGTH);
    }
  }
}

class NetworkContext {
  var vocab_size: int;
  var layer1_size: int;
  var hs: int;
  var negative: int;

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

class TaskContext {
  var networkContext: NetworkContext;

  var configContext = ConfigPartitions[here.id];
  var vocabContext = VocabPartitions[here.id];

  const CRLF = ascii('\n'): uint(8);

  var word_count_actual = 0;

  proc TrainModelTask() {
    const MAX_SENTENCE_LENGTH = 1000;

    const layer1_size = configContext.layer1_size;
    const sample = configContext.sample;
    const window = configContext.window;
    const cbow = configContext.cbow;
    const hs = configContext.hs;
    const negative = configContext.negative;
    const vocab_hash_size = vocabContext.vocab_hash_size;

    var a, d, cw, word, last_word, l1, l2, c, target, labelx: int;
    var b: int(64);
    var sentence_length = 0;
    var sentence_position = 0;
    var word_count = 0;
    var last_word_count = 0;
    var sen: [0..#(MAX_SENTENCE_LENGTH + 1)] int;
    var local_iter = configContext.iterations;
    var f, g: real;
    var t: Timer;

    var neuDomain = {0..#layer1_size};
    var neu1: [neuDomain] real = 0.0;
    var neu1e: [neuDomain] real = 0.0;

    var trainFile = open(configContext.train_file, iomode.r);
    var fileChunkSize = trainFile.length() / Locales.size;
    var seekStart = fileChunkSize * here.id;
    var seekStop = fileChunkSize * (here.id + 1);
    var reader = trainFile.reader(kind = ionative, locking=false); //, start=seekStart, end=seekStop);
    var next_random: uint(64) = here.id:uint(64); //(randStreamSeeded.getNext() * 25214903917:uint(64) + 11):uint(64);
    var atEOF = false;
    var alpha = configContext.alpha;
    var atCRLF = false;

    const starting_alpha = alpha;
    const train_words = vocabContext.train_words;
    const iterations = configContext.iterations;
    const MAX_EXP = vocabContext.MAX_EXP;
    const EXP_TABLE_SIZE = vocabContext.EXP_TABLE_SIZE;
    const table_size = vocabContext.table_size;
    const vocab_size = vocabContext.vocab_size;

    t.start();
    var start = t.elapsed(TimeUnits.microseconds);

    while (1) {
      /*if here.id == 1 then info(train_words, " ", word_count, " ", last_word_count, " ", word_count_actual);*/
      if (word_count - last_word_count > 10000) {
        word_count_actual += word_count - last_word_count;
        last_word_count = word_count;
        if (log_level > 1) {
          var now = t.elapsed(TimeUnits.milliseconds);
          /*write("\rAlpha: ", alpha,
                "  Progress: ", (word_count_actual / (iterations * train_words + 1):real),
                "  Words/thread/sec: ", word_count_actual / ((now - start + 1) / 1000) / 1000, "k");
          stdout.flush();*/
        }
        alpha = starting_alpha * (1 - word_count_actual / (iterations * train_words + 1):real);
        if (alpha < starting_alpha * 0.0001) then alpha = starting_alpha * 0.0001;
      }
      /*if (here.id == 1) then info("sentence_length ", word_count);*/
      if (sentence_length == 0) {
        while (1) {
          word = vocabContext.ReadWordIndex(reader, atCRLF);
          if (word == -2) {
            atEOF = true;
            break;
          }
          if (word == -1) then continue;
          word_count += 1;
          if (word == 0) then break;
          // The subsampling randomly discards frequent words while keeping the ranking same
          if (sample > 0) {
            var ran = (sqrt(vocabContext.vocab[word].cn / (sample * train_words):real) + 1) * (sample * train_words):real / vocabContext.vocab[word].cn;
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
        if (here.id == 1) then info("atEOF ", word_count);
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
      /*if (here.id == 1) then info("next_random ", word_count);*/

      /*next_random = (randStreamSeeded.getNext() * 25214903917:uint(64) + 11):uint(64);*/
      next_random = (next_random * 25214903917:uint(64) + 11):uint(64);
      b = (next_random % window: uint(64)):int(64);
      /*if (here.id == 1) then info("cbow ", word_count);*/
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
            for (c) in 0..#layer1_size do neu1[c] += networkContext.syn0[c + last_word * layer1_size];
            cw += 1;
          }
        }
        if (cw) {
          for (c) in 0..#layer1_size do neu1[c] /= cw;
          /*neu1 /= cw;*/
          if (hs) {
             for (d) in 0..#vocabContext.vocab[word].node.codelen {
              f = 0;
              l2 = vocabContext.vocab[word].node.point[d] * layer1_size;
              /*writeln(l2);*/
              // Propagate hidden -> output
              for (c) in 0..#layer1_size do f += neu1[c] * networkContext.syn1[c + l2];
              if (f <= -MAX_EXP) then continue;
              else if (f >= MAX_EXP) then continue;
              else {
                var idx = floor((f + MAX_EXP) * (EXP_TABLE_SIZE / MAX_EXP / 2)):int;
                f = vocabContext.expTable[idx];
              }
              // 'g' is the gradient multiplied by the learning rate
              g = (1 - vocabContext.vocab[word].node.code[d] - f) * alpha;
              /*writeln(alpha, " ", f, " ", g);*/
              // Propagate errors output -> hidden
              for (c) in 0..#layer1_size do neu1e[c] += g * networkContext.syn1[c + l2];
              // Learn weights hidden -> output
              for (c) in 0..#layer1_size do networkContext.syn1[c + l2] += g * neu1[c];
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
                target = vocabContext.table[((next_random >> 16) % table_size:uint(64)):int];
                if (target == 0) then target = (next_random % (vocab_size - 1):uint(64) + 1):int;
                if (target == word) then continue;
                labelx = 0;
              }
              l2 = target * layer1_size;
              f = 0;
              for (c) in 0..#layer1_size do f += neu1[c] * networkContext.syn1neg[c + l2];
              if (f > MAX_EXP) then g = (labelx - 1) * alpha;
              else if (f < -MAX_EXP) then g = (labelx - 0) * alpha;
              else g = (labelx - vocabContext.expTable[((f + MAX_EXP) * (EXP_TABLE_SIZE / MAX_EXP / 2)):int]) * alpha;
              for (c) in 0..#layer1_size do neu1e[c] += g * networkContext.syn1neg[c + l2];
              for (c) in 0..#layer1_size do networkContext.syn1neg[c + l2] += g * neu1[c];
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
              for (c) in 0..#layer1_size do networkContext.syn0[c + last_word * layer1_size] += neu1e[c];
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
}

proc TrainModel() {
  var a, b, c, d: int;
  var t: Timer;

  var configContext = ConfigPartitions[here.id];

  /*var vocabContext = new VocabContext(
    configContext.vocab_hash_size,
    configContext.initial_vocab_max_size,
    configContext.min_count);*/

  const train_file = configContext.train_file;
  const read_vocab_file = configContext.read_vocab_file;
  const save_vocab_file = configContext.save_vocab_file;
  const output_file = configContext.output_file;
  const negative = configContext.negative;

  info("Starting training using file ", train_file);
  /*if (read_vocab_file != "") then vocabContext.ReadVocab(read_vocab_file); else vocabContext.LearnVocabFromTrainFile(train_file);
  if (save_vocab_file != "") then vocabContext.SaveVocab(save_vocab_file);
  if (output_file == "") then return;*/

  /*var networkContext = new NetworkContext(vocabContext.vocab_size, configContext.layer1_size, configContext.hs, configContext.negative);
  networkContext.InitNet();*/

  /*vocabContext.CreateBinaryTree();
  if (negative > 0) then vocabContext.InitUnigramTable();*/

  forall loc in Locales {
    on loc {
      var configContext = ConfigPartitions[here.id];

      // copy the context to the locale
      var vocabContext = new VocabContext(
        configContext.vocab_hash_size,
        configContext.initial_vocab_max_size,
        configContext.min_count);

      vocabContext.LearnVocabFromTrainFile(configContext.train_file);
      vocabContext.CreateBinaryTree();
      if (negative > 0) then vocabContext.InitUnigramTable();

      VocabPartitions[here.id] = vocabContext;

      var networkContext = new NetworkContext(
        vocabContext.vocab_size,
        configContext.layer1_size,
        configContext.hs,
        configContext.negative
        );
      networkContext.InitNet();

      NetworkPartitions[here.id] = networkContext;

      var taskContext = new TaskContext(networkContext);
      /*TaskPartitions[here.id] = taskContext;*/
      info("here!");
      taskContext.TrainModelTask();
      info("done!");
    }
  }

  var networkContext = NetworkPartitions[here.id];
  var vocabContext = VocabPartitions[here.id];
  
  var outputFile = open(configContext.output_file, iomode.cw);
  var writer = outputFile.writer(locking=false);
  if (configContext.classes == 0) {
    // Save the word vectors
    /*fprintf(fo, "%lld %lld\n", vocab_size, layer1_size);*/
    writer.writeln(vocabContext.vocab_size, " ", configContext.layer1_size);
    for (a) in 0..#vocabContext.vocab_size {
      var vw = vocabContext.vocab[a].word;
      /*fprintf(fo, "%s ", vocab[a].word);*/
      for (j) in 0..#vw.len {
        writer.writef("%c", vw.word[j]);
      }
      writer.write(" ");
      if (configContext.binary) then for (b) in 0..#configContext.layer1_size do writer.writef("%|4r", networkContext.syn0[a * configContext.layer1_size + b]);
      else for (b) in 0..#configContext.layer1_size do writer.write(networkContext.syn0[a * configContext.layer1_size + b], " ");
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

for loc in Locales {
  on loc {
    ConfigPartitions[here.id] = new ConfigContext(
      x_log_level,
      x_vocab_hash_size,
      x_initial_vocab_max_size,
      x_min_count,
      x_train_file,
      x_save_vocab_file,
      x_read_vocab_file,
      x_output_file,
      x_hs,
      x_negative,
      x_layer1_size,
      x_iterations,
      x_window,
      x_cbow,
      x_binary,
      x_sample,
      x_alpha,
      x_classes
    );
  }
}

TrainModel();
