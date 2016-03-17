CC=clang
CFLAGS=-I$(IDIR) -I.

all: bin word2vec_local

bin:
	mkdir -p bin

word2vec_local: word2vec_local.chpl
	chpl --print-passes --fast -o ../bin/word2vec word2vec_local.chpl

clean:
	rm -f bin/*
