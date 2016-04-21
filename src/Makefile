CC=clang
CFLAGS=-I$(IDIR) -I.

all: bin word2vec_dsgd

bin:
	mkdir -p ../bin

word2vec_dmapped: word2vec_dmapped.chpl
	chpl --print-passes --fast -o ../bin/word2vec word2vec_dmapped.chpl

word2vec_dsgd: word2vec_dsgd.chpl
	chpl --print-passes --fast -o ../bin/word2vec word2vec_dsgd.chpl

word2vec_classic: word2vec_classic.chpl
	chpl --print-passes --fast -o ../bin/word2vec word2vec_classic.chpl

nettest: nettest.chpl
	chpl --print-passes --fast -o ../bin/nettest nettest.chpl

clean:
	rm -f bin/*
