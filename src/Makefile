CC=clang
CFLAGS=-I$(IDIR) -I.

all: bin nettest 

bin:
	mkdir -p bin

word2vec_local: word2vec_local.chpl
	chpl --print-passes --fast -o ../bin/word2vec word2vec_local.chpl

nettest: nettest.chpl
	chpl --print-passes --fast -o ../bin/nettest nettest.chpl

clean:
	rm -f bin/*
