DATA_DIR=../data
BIN_DIR=../bin
SRC_DIR=../src

TEXT_DATA=$DATA_DIR/text8
VECTOR_DATA=$DATA_DIR/text8-vector.bin

pushd ${SRC_DIR} && make; popd

if [ ! -e $VECTOR_DATA ]; then

  if [ ! -e $TEXT_DATA ]; then
    mkdir -p $DATA_DIR
    wget http://mattmahoney.net/dc/text8.zip -O $DATA_DIR/text8.zip
    unzip -d $DATA_DIR $DATA_DIR/text8.zip
  fi
  echo -----------------------------------------------------------------------------------------------------
  echo -- Training vectors...
  time $BIN_DIR/word2vec -nl 1 --train_file $TEXT_DATA --output_file $VECTOR_DATA --cbow 0 --size 200 --window 5 --negative 0 --hs 1 --sample 1e-3 --binary 1
fi

#echo -----------------------------------------------------------------------------------------------------
#echo -- distance...

#$BIN_DIR/distance $DATA_DIR/$VECTOR_DATA
