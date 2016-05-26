all: bin word2vec_dsgd

bin:
	mkdir -p ../bin

word2vec_dmapped: word2vec_dmapped.chpl
	chpl --print-passes --fast -o ../bin/word2vec word2vec_dmapped.chpl

word2vec_dsgd: word2vec_dsgd.chpl
	chpl --print-passes --fast -o ../bin/word2vec word2vec_dsgd.chpl

word2vec_classic: word2vec_classic.chpl
	chpl --print-passes --fast --local -o ../bin/word2vec word2vec_classic.chpl

memorytest: memorytest.chpl
	python gen_memorytest.py > memorytest.chpl
	chpl --print-passes --fast -o ../bin/memorytest memorytest.chpl

clean:
	rm -f bin/*
