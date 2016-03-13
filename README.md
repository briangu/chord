# chord
word2vec in Chapel

time ./word2vec -train news.1000 -save_vocab vocab.t2.t -output vout -threads 1 -size 4 -binary 1

time ./w2v -nl 1 --train_file news.1000 --read_vocab_file vocab.t2.t --output_file vectors.txt --layer1_size=4 --binary 1
