use BlockDist, ReplicatedDist, CyclicDist, Logging, Time;
use DimensionalDist2D, BlockCycDim, BlockDim, ReplicatedDim;

type elemType = real;

config const n = 16;

var syn0Domain = {0..#15,0..#n};
/*var ssyn0: [syn0Domain] elemType;*/

const syn0DomainSpace = syn0Domain dmapped Block(boundingBox=syn0Domain);
var syn0: [syn0DomainSpace] elemType;

forall i in syn0Domain.dim(1) {
  syn0[i,..] = (i + 10): elemType;
}

const Diff = syn0[..,0];

writeln(syn0[..,0]);

// left = 2n+1
// right = 2n+2
// parent =
//             *                0
//      *            *          1,2
//   *     *      *     *       2*1+1=3,2*1+2=4,2*2+1=5,2*2+2=6
// *   * *   *  *   * *   *     2*3+1=7,2*3+2=8,2*4+1=9,2*4+2=10,...,2*6+2=14

/*const CopySpace = {0,1,2,3,n-1};*/
/*const CopySpace = [ i in 0..#n by 2 ] i;*/
const CopySpace = {0..#n};
/*const CopySpace = syn0Domain.dim(2);*/

for i in 7..14 {
  var parent: int;
  parent = if (i % 2 == 0) then (i - 1) / 2 else (i - 2) / 2;
  info(" i = ",i, " parent = ",parent, " ", syn0[i..i,0]);
  syn0[parent..parent,CopySpace] += syn0[i..i,CopySpace];
  /*syn0[parent..parent,..] += syn0[i..i,..];*/
}

writeln(syn0[syn0Domain.dim(1),0] - Diff);

/*info("here1");*/

/*const sourceId = (here.id + 1) % Locales.size;
info(sourceId);*/
/*var targetLocales: [0..#1, 0..#1] locale = Locales[0];*/
/*targetLocales[1,0] = Locales[1];*/

/*const Space = {0..#1, 0..#n};
const Foo = Space dmapped DimensionalDist2D(targetLocales, new ReplicatedDim(numLocales=1), new BlockDim(numLocales=1, boundingBox = 0..#n));*/
/*const Foo = Space dmapped DimensionalDist2D(targetLocales, new ReplicatedDim(numLocales=1), new BlockCyclicDim(1, lowIdx=0, n));*/
/*var replB: [Foo] elemType;*/

/*for loc in targetLocales do on loc {
  forall a in replB do
    a = here.id: elemType;
  writeln("On ", here, ":");
  const Helper: [Space] elemType = replB;
  writeln(Helper);
  writeln();
}*/

/*info("here2");*/
/*coforall dest in targetLocales[.., 0] do
  on dest do
    replB = syn0[1..1, ..];*/

/*replB = syn0[1..1,..];*/
/*forall (a,b) in zip(replB, syn0[1..1,..]) do a += b;*/
/*writeln(syn0);
writeln();*/
/*forall (a,b) in zip(replB, syn0[1..1,..]) do b = a;*/
/*forall (a,b) in zip(syn0[0..0,..], syn0[1..1,..]) do a += b;*/
/*syn0[0..0,..] += syn0[1..1,..];*/
/*writeln(syn0);*/
/*info(replB[0,0]);*/
