use ReplicatedDist;

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

class ConstContext {
  var MAX_STRING = 100;
  /*var EXP_TABLE_SIZE = 1000;
  var MAX_EXP = 6;*/
  var MAX_SENTENCE_LENGTH = 1000;
  var MAX_CODE_LENGTH = 40;

  var SPACE = ascii(' '): uint(8);
  var TAB = ascii('\t'): uint(8);
  var CRLF = ascii('\n'): uint(8);
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

  var constants: ConstContext;
}

class VocabContext {
  var vocab_size = 0;
  var vocab_max_size = initial_vocab_max_size;

  const EXP_TABLE_SIZE = 1000;
  const MAX_EXP = 6;

  var train_words: int = 0;

  var vocabDomain = {0..#vocab_max_size};
  var vocab: [vocabDomain] VocabEntry;

  var vocab_hash: [0..#vocab_hash_size] int = -1;

  var expTable: [0..#(EXP_TABLE_SIZE+1)] real;

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
}

class TaskContext {
  var configContext: ConfigContext;
  var vocabContext: VocabContext;
}

const Space = {0..Locales.size-1};
const ReplicatedSpace = Space dmapped ReplicatedDist();
var Partitions: [ReplicatedSpace] TaskContext;

for loc in Locales {
  on loc {
    var constants = new ConstContext();

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
      classes,
      constants
    );

    var vocabContext = new VocabContext(
      configContext.initial_vocab_max_size,
      configContext.vocab_hash_size
      );

    Partitions[here.id] = new TaskContext(configContext, vocabContext);
  }
}

on Locales[1] {
  writeln(Partitions[1].locale.id);
}
