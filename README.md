# Chord

Chord is a Chapel implementation of Google's word2vec.  The project contains
both a 'lexical' port of the original word2vec code (word2vec_classic.chpl) and
a distributed variant which takes advantage of Chapel's locality features (word2vec_dsgd.chpl).

Setup
=====

Install Chapel.  All demo scripts expect a multi-node Chapel installation.

Visit http://chapel.cray.com/download.html and download

To setup Chapel to run locally, add this to your ~/.bash_profile

  cd $CHAPEL_HOME
  source ./util/setchplenv.sh

  export CHPL_COMM=gasnet
  export GASNET_SPAWNFN=L
  export CHPL_TARGET_ARCH=native

Build Chapel

  cd $CHAPEL_HOME
  make
  make check

Run demo-word.sh

    cd scripts
    ./demo-word.sh

Run word2vec_classic in local mode:

    cd src
    make word2vec_classic
    time ../bin/word2vec -nl 5 --train_file ../data/text8 --output_file ../data/vectors.bin --cbow 1 --size 200 --window 8 --negative 25 --hs 0 --sample 1e-4 --binary 1 --read_vocab_file=../data/vocab.txt

References
==========

word2vec: https://code.google.com/p/word2vec/
OSX friendly word2vec: https://github.com/dav/word2vec
