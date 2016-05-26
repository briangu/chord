use BlockCycDim;
use BlockDim;
use BlockDist;
use CyclicDist;
use DimensionalDist2D;
use Logging;
use PrivateDist;
use ReplicatedDist;
use ReplicatedDim;
use Time;

type elemType = real;

config const n = 16;
config const k = 1;
config const num_threads = here.maxTaskPar;

const dom = {0..#(n*1024*1024)};
var priv_arr: [PrivateSpace][dom] elemType;
var local_arr: [dom] elemType;

const dom2 = {0..#k,0..#(n*1024*1024)};
var priv_arr2: [PrivateSpace][dom2] elemType;
var local_arr2: [dom] elemType;

class RemoteMemory {
  var n: int;
  var dom = {0..#n};
  var arr: [dom] elemType;
}

class RemoteMemory2 {
  var m: int;
  var n: int;
  var dom = {0..#m, 0..#n};
  var arr: [dom] elemType;
}

var timer: Timer;

writeln("***********************");
writeln("cross-locale memory copy tests");
writeln("***********************");

timer.clear();
timer.start();
priv_arr[0] = priv_arr[1];
timer.stop();
writeln("priv_arr[0] = priv_arr[1]: ", timer.elapsed(TimeUnits.microseconds));

timer.clear();
timer.start();
priv_arr[0][dom] = priv_arr[1][dom];
timer.stop();
writeln("priv_arr[0][dom] = priv_arr[1][dom]: ", timer.elapsed(TimeUnits.microseconds));

timer.clear();
timer.start();
priv_arr2[0] = priv_arr2[1];
timer.stop();
writeln("priv_arr2[0] = priv_arr2[1]: ", timer.elapsed(TimeUnits.microseconds));

timer.clear();
timer.start();
priv_arr2[0][dom2] = priv_arr2[1][dom2];
timer.stop();
writeln("priv_arr2[0][dom2] = priv_arr2[1][dom2]: ", timer.elapsed(TimeUnits.microseconds));

var localMemory = new RemoteMemory(dom.high);
var remoteMemory: RemoteMemory;
on Locales[1] do remoteMemory = new RemoteMemory(dom.high);
writeln("localMemory.locale.id: ", localMemory.locale.id, " remoteMemory.locale.id: ", remoteMemory.locale.id);

timer.clear();
timer.start();
localMemory.arr = remoteMemory.arr;
timer.stop();
writeln("localMemory.arr = remoteMemory.arr: ", timer.elapsed(TimeUnits.microseconds));

timer.clear();
timer.start();
localMemory.arr[localMemory.dom] = remoteMemory.arr[localMemory.dom];
timer.stop();
writeln("localMemory.arr[localMemory.dom] = remoteMemory.arr[localMemory.dom]: ", timer.elapsed(TimeUnits.microseconds));

timer.clear();
timer.start();
coforall loc in Locales[0..0] do on loc do  localMemory.arr = remoteMemory.arr;
timer.stop();
writeln("coforall loc in Locales[0..0] do on loc do  localMemory.arr = remoteMemory.arr: ", timer.elapsed(TimeUnits.microseconds));

timer.clear();
timer.start();
coforall loc in Locales[1..1] do on loc do  localMemory.arr = remoteMemory.arr;
timer.stop();
writeln("coforall loc in Locales[1..1] do on loc do  localMemory.arr = remoteMemory.arr: ", timer.elapsed(TimeUnits.microseconds));

timer.clear();
timer.start();
coforall loc in Locales[0..0] do on loc do  localMemory.arr[localMemory.dom] = remoteMemory.arr[localMemory.dom];
timer.stop();
writeln("coforall loc in Locales[0..0] do on loc do  localMemory.arr[localMemory.dom] = remoteMemory.arr[localMemory.dom]: ", timer.elapsed(TimeUnits.microseconds));

timer.clear();
timer.start();
coforall loc in Locales[1..1] do on loc do  localMemory.arr[localMemory.dom] = remoteMemory.arr[localMemory.dom];
timer.stop();
writeln("coforall loc in Locales[1..1] do on loc do  localMemory.arr[localMemory.dom] = remoteMemory.arr[localMemory.dom]: ", timer.elapsed(TimeUnits.microseconds));

// super slow
/*timer.clear();
timer.start();
localMemory.arr[localMemory.dom] -= remoteMemory.arr[localMemory.dom];
timer.stop();
writeln("localMemory.arr[localMemory.dom] -= remoteMemory.arr[localMemory.dom]: ", timer.elapsed(TimeUnits.microseconds));*/

var localMemory2 = new RemoteMemory2(1, dom.high);
var remoteMemory2: RemoteMemory2;
on Locales[1] do remoteMemory2 = new RemoteMemory2(1, dom.high);
writeln("localMemory.locale.id: ", localMemory2.locale.id, " remoteMemory2.locale.id: ", remoteMemory.locale.id);

timer.clear();
timer.start();
localMemory2.arr = remoteMemory2.arr;
timer.stop();
writeln("localMemory2.arr = remoteMemory2.arr: ", timer.elapsed(TimeUnits.microseconds));

timer.clear();
timer.start();
localMemory2.arr[localMemory2.dom] = remoteMemory2.arr[localMemory2.dom];
timer.stop();
writeln("localMemory2.arr[localMemory2.dom] = remoteMemory2.arr[localMemory.dom]: ", timer.elapsed(TimeUnits.microseconds));

timer.clear();
timer.start();
coforall loc in Locales[0..0] do on loc do  localMemory2.arr = remoteMemory2.arr;
timer.stop();
writeln("coforall loc in Locales[0..0] do on loc do  localMemory2.arr = remoteMemory2.arr: ", timer.elapsed(TimeUnits.microseconds));

timer.clear();
timer.start();
coforall loc in Locales[1..1] do on loc do  localMemory2.arr = remoteMemory2.arr;
timer.stop();
writeln("coforall loc in Locales[1..1] do on loc do  localMemory2.arr = remoteMemory2.arr: ", timer.elapsed(TimeUnits.microseconds));

timer.clear();
timer.start();
coforall loc in Locales[0..0] do on loc do  localMemory2.arr[localMemory2.dom] = remoteMemory2.arr[localMemory2.dom];
timer.stop();
writeln("coforall loc in Locales[0..0] do on loc do  localMemory2.arr[localMemory2.dom] = remoteMemory2.arr[localMemory2.dom]: ", timer.elapsed(TimeUnits.microseconds));

timer.clear();
timer.start();
coforall loc in Locales[1..1] do on loc do  localMemory2.arr[localMemory2.dom] = remoteMemory2.arr[localMemory2.dom];
timer.stop();
writeln("coforall loc in Locales[1..1] do on loc do  localMemory2.arr[localMemory2.dom] = remoteMemory2.arr[localMemory2.dom]: ", timer.elapsed(TimeUnits.microseconds));

writeln("***********************");
writeln("memory assignment tests");
writeln("***********************");

timer.clear();
timer.start();
local_arr = 0;
timer.stop();
writeln("local_arr = 0 ", timer.elapsed(TimeUnits.microseconds));

timer.clear();
timer.start();
for i in local_arr.domain do local_arr[i] = 0;
timer.stop();
writeln("for i in 0..local_arr.domain do local_arr[i] = 0: ", timer.elapsed(TimeUnits.microseconds));

timer.clear();
timer.start();
forall i in local_arr.domain do local_arr[i] = 0;
timer.stop();
writeln("forall i in 0..local_arr.domain do local_arr[i] = 0: ", timer.elapsed(TimeUnits.microseconds));

timer.clear();
timer.start();
forall n in 0..#num_threads do local_arr = 0;
timer.stop();
writeln("forall n in 0..#num_threads do local_arr = 0: ", timer.elapsed(TimeUnits.microseconds));

timer.clear();
timer.start();
forall n in 0..#num_threads do forall i in local_arr.domain do local_arr[i] = 0;
timer.stop();
writeln("forall n in 0..#num_threads do forall i in local_arr.domain do local_arr[i] = 0: ", timer.elapsed(TimeUnits.microseconds));

timer.clear();
timer.start();
forall n in 0..#num_threads do for i in local_arr.domain do local_arr[i] = 0;
timer.stop();
writeln("forall n in 0..#num_threads do for i in local_arr.domain do local_arr[i] = 0: ", timer.elapsed(TimeUnits.microseconds));

timer.clear();
timer.start();
forall n in 0..#num_threads do for l in local_arr do l = 0;
timer.stop();
writeln("forall n in 0..#num_threads do for l in local_arr do l = 0: ", timer.elapsed(TimeUnits.microseconds));

timer.clear();
timer.start();
coforall loc in Locales[0..0] do on loc {
  forall n in 0..#num_threads do forall i in local_arr.domain do local_arr[i] = 0;
}
timer.stop();
writeln("coforall loc in Locales[0..0] do on loc: ", timer.elapsed(TimeUnits.microseconds));

writeln("***********************");
writeln("dmapped tests");
writeln("***********************");

var syn0Domain = {0..#numLocales, 0..1024};
const syn0DomainSpace = syn0Domain dmapped Block(boundingBox=syn0Domain);
var syn0: [syn0DomainSpace] elemType;
forall s in syn0 do s = here.id: elemType;
/*writeln(syn0);*/

timer.clear();
timer.start();
syn0[0,..] = syn0[1,..];
timer.stop();
writeln("syn0[0,..] = syn0[1,..]: ", timer.elapsed(TimeUnits.microseconds));

timer.clear();
timer.start();
syn0[0,syn0Domain.dim(2)] = syn0[1,syn0Domain.dim(2)];
timer.stop();
writeln("syn0[0,syn0Domain.dim(2)] = syn0[1,syn0Domain.dim(2)]: ", timer.elapsed(TimeUnits.microseconds));

timer.clear();
timer.start();
forall i in syn0Domain.dim(2) do syn0[0,i] = syn0[1,i];
timer.stop();
writeln("forall i in syn0Domain.dim(2) do syn0[0,i] = syn0[1,i]: ", timer.elapsed(TimeUnits.microseconds));

timer.clear();
timer.start();
coforall loc in Locales[0..0] do on loc do forall i in syn0Domain.dim(2) do syn0[0,i] = syn0[1,i];
timer.stop();
writeln("coforall loc on Locales[0..0] do on loc do forall i in syn0Domain.dim(2) do syn0[0,i] = syn0[1,i]: ", timer.elapsed(TimeUnits.microseconds));

timer.clear();
timer.start();
coforall loc in Locales[1..1] do on loc do forall i in syn0Domain.dim(2) do syn0[0,i] = syn0[1,i];
timer.stop();
writeln("coforall loc on Locales[1..1] do on loc do forall i in syn0Domain.dim(2) do syn0[0,i] = syn0[1,i]: ", timer.elapsed(TimeUnits.microseconds));

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
