# chord

Chord is a Chapel implementation of Google's word2vec.  The project contains
both a 'lexical' port of the original word2vec code and a distributed variant
which takes advantage of Chapel's locality features.

Setup
=====

Install Chapel.  Note, all demo scripts expect a multi-node Chapel installation.

For single node Chapel

  brew install chapel

For multi-node Chapel, visit http://chapel.cray.com/download.html

Run demo-word.sh

  cd scripts
  ./demo-word.sh

Note, if you want to pull a copy of original Google implementation, fetch the submodule:

  git submodule init
  git submodule update




References:

word2vec: https://code.google.com/p/word2vec/
