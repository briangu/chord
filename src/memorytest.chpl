use BlockDist;
use Logging;
use PrivateDist;
use DimensionalDist2D, BlockDim, BlockCycDim, ReplicatedDim;
use Time;

type elemType = real;

config const n = 16;
config const k = 1;
config const num_threads = here.maxTaskPar;

var timer: Timer;

writeln("**");
writeln("** PrivateSpace copy tests");
writeln("**");

{

  const dom = {0..#(n*1024*1024)};
  var arr: [PrivateSpace][dom] elemType;

  timer.clear();
  timer.start();
  arr[0] = arr[1];
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tarr[0] = arr[1]");;

  timer.clear();
  timer.start();
  arr[0][dom] = arr[1][dom];
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tarr[0][dom] = arr[1][dom]");;

  timer.clear();
  timer.start();
  coforall loc in Locales[0..0] do on loc do arr[0] = arr[1];
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tcoforall loc in Locales[0..0] do on loc do arr[0] = arr[1]");;

  timer.clear();
  timer.start();
  coforall loc in Locales[1..1] do on loc do arr[0] = arr[1];
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tcoforall loc in Locales[1..1] do on loc do arr[0] = arr[1]");;

  timer.clear();
  timer.start();
  coforall loc in Locales[0..0] do on loc do arr[0][dom] = arr[1][dom];
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tcoforall loc in Locales[0..0] do on loc do arr[0][dom] = arr[1][dom]");;

  timer.clear();
  timer.start();
  coforall loc in Locales[1..1] do on loc do arr[0][dom] = arr[1][dom];
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tcoforall loc in Locales[1..1] do on loc do arr[0][dom] = arr[1][dom]");;

}

writeln("**");
writeln("** PrivateSpace 2D copy tests");
writeln("**");

{

  const dom = {0..#k,0..#(n*1024*1024)};
  var arr: [PrivateSpace][dom] elemType;

  timer.clear();
  timer.start();
  arr[0] = arr[1];
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tarr[0] = arr[1]");;

  timer.clear();
  timer.start();
  arr[0][dom] = arr[1][dom];
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tarr[0][dom] = arr[1][dom]");;

  timer.clear();
  timer.start();
  coforall loc in Locales[0..0] do on loc do arr[0] = arr[1];
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tcoforall loc in Locales[0..0] do on loc do arr[0] = arr[1]");;

  timer.clear();
  timer.start();
  coforall loc in Locales[1..1] do on loc do arr[0] = arr[1];
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tcoforall loc in Locales[1..1] do on loc do arr[0] = arr[1]");;

  timer.clear();
  timer.start();
  coforall loc in Locales[0..0] do on loc do arr[0][dom] = arr[1][dom];
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tcoforall loc in Locales[0..0] do on loc do arr[0][dom] = arr[1][dom]");;

  timer.clear();
  timer.start();
  coforall loc in Locales[1..1] do on loc do arr[0][dom] = arr[1][dom];
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tcoforall loc in Locales[1..1] do on loc do arr[0][dom] = arr[1][dom]");;

}

writeln("**");
writeln("** local/remote class arr copy tests");
writeln("**");

{

  const dom = {0..#(n*1024*1024)};
  class RemoteMemory {;
    var n: int;
    var dom = {0..#n};
    var arr: [dom] elemType;
  };

  var localMemory = new RemoteMemory(dom.high);
  var remoteMemory: RemoteMemory;
  on Locales[1] do remoteMemory = new RemoteMemory(dom.high);

  timer.clear();
  timer.start();
  localMemory.arr = remoteMemory.arr;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tlocalMemory.arr = remoteMemory.arr");;

  timer.clear();
  timer.start();
  localMemory.arr[localMemory.dom] = remoteMemory.arr[localMemory.dom];
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tlocalMemory.arr[localMemory.dom] = remoteMemory.arr[localMemory.dom]");;

  timer.clear();
  timer.start();
  forall n in 0..#num_threads do localMemory.arr = remoteMemory.arr;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tforall n in 0..#num_threads do localMemory.arr = remoteMemory.arr");;

  timer.clear();
  timer.start();
  forall n in 0..#num_threads do localMemory.arr[localMemory.dom] = remoteMemory.arr[localMemory.dom];
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tforall n in 0..#num_threads do localMemory.arr[localMemory.dom] = remoteMemory.arr[localMemory.dom]");;

  timer.clear();
  timer.start();
  coforall loc in Locales[0..0] do on loc do localMemory.arr = remoteMemory.arr;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tcoforall loc in Locales[0..0] do on loc do localMemory.arr = remoteMemory.arr");;

  timer.clear();
  timer.start();
  coforall loc in Locales[1..1] do on loc do localMemory.arr = remoteMemory.arr;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tcoforall loc in Locales[1..1] do on loc do localMemory.arr = remoteMemory.arr");;

  timer.clear();
  timer.start();
  coforall loc in Locales[0..0] do on loc do localMemory.arr[localMemory.dom] = remoteMemory.arr[localMemory.dom];
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tcoforall loc in Locales[0..0] do on loc do localMemory.arr[localMemory.dom] = remoteMemory.arr[localMemory.dom]");;

  timer.clear();
  timer.start();
  coforall loc in Locales[1..1] do on loc do localMemory.arr[localMemory.dom] = remoteMemory.arr[localMemory.dom];
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tcoforall loc in Locales[1..1] do on loc do localMemory.arr[localMemory.dom] = remoteMemory.arr[localMemory.dom]");;

  timer.clear();
  timer.start();
  coforall loc in Locales[0..0] do on loc do forall n in 0..#num_threads do localMemory.arr = remoteMemory.arr;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tcoforall loc in Locales[0..0] do on loc do forall n in 0..#num_threads do localMemory.arr = remoteMemory.arr");;

  timer.clear();
  timer.start();
  coforall loc in Locales[1..1] do on loc do forall n in 0..#num_threads do localMemory.arr = remoteMemory.arr;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tcoforall loc in Locales[1..1] do on loc do forall n in 0..#num_threads do localMemory.arr = remoteMemory.arr");;

  timer.clear();
  timer.start();
  coforall loc in Locales[0..0] do on loc do forall n in 0..#num_threads do localMemory.arr[localMemory.dom] = remoteMemory.arr[localMemory.dom];
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tcoforall loc in Locales[0..0] do on loc do forall n in 0..#num_threads do localMemory.arr[localMemory.dom] = remoteMemory.arr[localMemory.dom]");;

  timer.clear();
  timer.start();
  coforall loc in Locales[1..1] do on loc do forall n in 0..#num_threads do localMemory.arr[localMemory.dom] = remoteMemory.arr[localMemory.dom];
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tcoforall loc in Locales[1..1] do on loc do forall n in 0..#num_threads do localMemory.arr[localMemory.dom] = remoteMemory.arr[localMemory.dom]");;

}

writeln("**");
writeln("** local/remote class 2D arr copy tests");
writeln("**");

{

  const dom = {0..#k, 0..#(n*1024*1024)};
  class RemoteMemory {;
    var m: int;
    var n: int;
    var dom = {0..#m, 0..#n};
    var arr: [dom] elemType;
  };

  var localMemory = new RemoteMemory(dom.dim(1).high, dom.dim(2).high);
  var remoteMemory: RemoteMemory;
  on Locales[1] do remoteMemory = new RemoteMemory(dom.dim(1).high, dom.dim(2).high);

  timer.clear();
  timer.start();
  localMemory.arr = remoteMemory.arr;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tlocalMemory.arr = remoteMemory.arr");;

  timer.clear();
  timer.start();
  localMemory.arr[localMemory.dom] = remoteMemory.arr[localMemory.dom];
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tlocalMemory.arr[localMemory.dom] = remoteMemory.arr[localMemory.dom]");;

  timer.clear();
  timer.start();
  forall n in 0..#num_threads do localMemory.arr = remoteMemory.arr;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tforall n in 0..#num_threads do localMemory.arr = remoteMemory.arr");;

  timer.clear();
  timer.start();
  forall n in 0..#num_threads do localMemory.arr[localMemory.dom] = remoteMemory.arr[localMemory.dom];
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tforall n in 0..#num_threads do localMemory.arr[localMemory.dom] = remoteMemory.arr[localMemory.dom]");;

  timer.clear();
  timer.start();
  coforall loc in Locales[0..0] do on loc do localMemory.arr = remoteMemory.arr;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tcoforall loc in Locales[0..0] do on loc do localMemory.arr = remoteMemory.arr");;

  timer.clear();
  timer.start();
  coforall loc in Locales[1..1] do on loc do localMemory.arr = remoteMemory.arr;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tcoforall loc in Locales[1..1] do on loc do localMemory.arr = remoteMemory.arr");;

  timer.clear();
  timer.start();
  coforall loc in Locales[0..0] do on loc do localMemory.arr[localMemory.dom] = remoteMemory.arr[localMemory.dom];
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tcoforall loc in Locales[0..0] do on loc do localMemory.arr[localMemory.dom] = remoteMemory.arr[localMemory.dom]");;

  timer.clear();
  timer.start();
  coforall loc in Locales[1..1] do on loc do localMemory.arr[localMemory.dom] = remoteMemory.arr[localMemory.dom];
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tcoforall loc in Locales[1..1] do on loc do localMemory.arr[localMemory.dom] = remoteMemory.arr[localMemory.dom]");;

  timer.clear();
  timer.start();
  coforall loc in Locales[0..0] do on loc do forall n in 0..#num_threads do localMemory.arr = remoteMemory.arr;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tcoforall loc in Locales[0..0] do on loc do forall n in 0..#num_threads do localMemory.arr = remoteMemory.arr");;

  timer.clear();
  timer.start();
  coforall loc in Locales[1..1] do on loc do forall n in 0..#num_threads do localMemory.arr = remoteMemory.arr;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tcoforall loc in Locales[1..1] do on loc do forall n in 0..#num_threads do localMemory.arr = remoteMemory.arr");;

  timer.clear();
  timer.start();
  coforall loc in Locales[0..0] do on loc do forall n in 0..#num_threads do localMemory.arr[localMemory.dom] = remoteMemory.arr[localMemory.dom];
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tcoforall loc in Locales[0..0] do on loc do forall n in 0..#num_threads do localMemory.arr[localMemory.dom] = remoteMemory.arr[localMemory.dom]");;

  timer.clear();
  timer.start();
  coforall loc in Locales[1..1] do on loc do forall n in 0..#num_threads do localMemory.arr[localMemory.dom] = remoteMemory.arr[localMemory.dom];
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tcoforall loc in Locales[1..1] do on loc do forall n in 0..#num_threads do localMemory.arr[localMemory.dom] = remoteMemory.arr[localMemory.dom]");;

}

writeln("**");
writeln("** local memory assignment tests");
writeln("**");

{

  const dom = {0..#(n*1024*1024)};
  var arr: [dom] elemType;

  timer.clear();
  timer.start();
  arr = 0;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tarr = 0");;

  timer.clear();
  timer.start();
  [i in arr.domain] arr[i] = 0;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\t[i in arr.domain] arr[i] = 0");;

  timer.clear();
  timer.start();
  for i in arr.domain do arr[i] = 0;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tfor i in arr.domain do arr[i] = 0");;

  timer.clear();
  timer.start();
  forall i in arr.domain do arr[i] = 0;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tforall i in arr.domain do arr[i] = 0");;

  timer.clear();
  timer.start();
  for l in arr do l = 0;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tfor l in arr do l = 0");;

  timer.clear();
  timer.start();
  forall l in arr do l = 0;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tforall l in arr do l = 0");;

  timer.clear();
  timer.start();
  forall n in 0..#num_threads do arr = 0;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tforall n in 0..#num_threads do arr = 0");;

  timer.clear();
  timer.start();
  forall n in 0..#num_threads do [i in arr.domain] arr[i] = 0;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tforall n in 0..#num_threads do [i in arr.domain] arr[i] = 0");;

  timer.clear();
  timer.start();
  forall n in 0..#num_threads do for i in arr.domain do arr[i] = 0;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tforall n in 0..#num_threads do for i in arr.domain do arr[i] = 0");;

  timer.clear();
  timer.start();
  forall n in 0..#num_threads do forall i in arr.domain do arr[i] = 0;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tforall n in 0..#num_threads do forall i in arr.domain do arr[i] = 0");;

  timer.clear();
  timer.start();
  forall n in 0..#num_threads do for l in arr do l = 0;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tforall n in 0..#num_threads do for l in arr do l = 0");;

  timer.clear();
  timer.start();
  forall n in 0..#num_threads do forall l in arr do l = 0;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tforall n in 0..#num_threads do forall l in arr do l = 0");;

  timer.clear();
  timer.start();
  coforall loc in Locales[0..0] do on loc do arr = 0;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tcoforall loc in Locales[0..0] do on loc do arr = 0");;

  timer.clear();
  timer.start();
  coforall loc in Locales[0..0] do on loc do [i in arr.domain] arr[i] = 0;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tcoforall loc in Locales[0..0] do on loc do [i in arr.domain] arr[i] = 0");;

  timer.clear();
  timer.start();
  coforall loc in Locales[0..0] do on loc do for i in arr.domain do arr[i] = 0;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tcoforall loc in Locales[0..0] do on loc do for i in arr.domain do arr[i] = 0");;

  timer.clear();
  timer.start();
  coforall loc in Locales[0..0] do on loc do forall i in arr.domain do arr[i] = 0;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tcoforall loc in Locales[0..0] do on loc do forall i in arr.domain do arr[i] = 0");;

  timer.clear();
  timer.start();
  coforall loc in Locales[0..0] do on loc do for l in arr do l = 0;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tcoforall loc in Locales[0..0] do on loc do for l in arr do l = 0");;

  timer.clear();
  timer.start();
  coforall loc in Locales[0..0] do on loc do forall l in arr do l = 0;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tcoforall loc in Locales[0..0] do on loc do forall l in arr do l = 0");;

  timer.clear();
  timer.start();
  coforall loc in Locales[0..0] do on loc do forall n in 0..#num_threads do arr = 0;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tcoforall loc in Locales[0..0] do on loc do forall n in 0..#num_threads do arr = 0");;

  timer.clear();
  timer.start();
  coforall loc in Locales[0..0] do on loc do forall n in 0..#num_threads do [i in arr.domain] arr[i] = 0;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tcoforall loc in Locales[0..0] do on loc do forall n in 0..#num_threads do [i in arr.domain] arr[i] = 0");;

  timer.clear();
  timer.start();
  coforall loc in Locales[0..0] do on loc do forall n in 0..#num_threads do for i in arr.domain do arr[i] = 0;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tcoforall loc in Locales[0..0] do on loc do forall n in 0..#num_threads do for i in arr.domain do arr[i] = 0");;

  timer.clear();
  timer.start();
  coforall loc in Locales[0..0] do on loc do forall n in 0..#num_threads do forall i in arr.domain do arr[i] = 0;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tcoforall loc in Locales[0..0] do on loc do forall n in 0..#num_threads do forall i in arr.domain do arr[i] = 0");;

  timer.clear();
  timer.start();
  coforall loc in Locales[0..0] do on loc do forall n in 0..#num_threads do for l in arr do l = 0;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tcoforall loc in Locales[0..0] do on loc do forall n in 0..#num_threads do for l in arr do l = 0");;

  timer.clear();
  timer.start();
  coforall loc in Locales[0..0] do on loc do forall n in 0..#num_threads do forall l in arr do l = 0;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tcoforall loc in Locales[0..0] do on loc do forall n in 0..#num_threads do forall l in arr do l = 0");;

}

writeln("**");
writeln("** local 2D memory assignment tests");
writeln("**");

{

  const dom = {0..#k,0..#(n*1024*1024)};
  var arr: [dom] elemType;

  timer.clear();
  timer.start();
  arr = 0;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tarr = 0");;

  timer.clear();
  timer.start();
  [i in arr.domain] arr[i] = 0;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\t[i in arr.domain] arr[i] = 0");;

  timer.clear();
  timer.start();
  for i in arr.domain do arr[i] = 0;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tfor i in arr.domain do arr[i] = 0");;

  timer.clear();
  timer.start();
  forall i in arr.domain do arr[i] = 0;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tforall i in arr.domain do arr[i] = 0");;

  timer.clear();
  timer.start();
  for l in arr do l = 0;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tfor l in arr do l = 0");;

  timer.clear();
  timer.start();
  forall l in arr do l = 0;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tforall l in arr do l = 0");;

  timer.clear();
  timer.start();
  forall n in 0..#num_threads do arr = 0;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tforall n in 0..#num_threads do arr = 0");;

  timer.clear();
  timer.start();
  forall n in 0..#num_threads do [i in arr.domain] arr[i] = 0;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tforall n in 0..#num_threads do [i in arr.domain] arr[i] = 0");;

  timer.clear();
  timer.start();
  forall n in 0..#num_threads do for i in arr.domain do arr[i] = 0;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tforall n in 0..#num_threads do for i in arr.domain do arr[i] = 0");;

  timer.clear();
  timer.start();
  forall n in 0..#num_threads do forall i in arr.domain do arr[i] = 0;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tforall n in 0..#num_threads do forall i in arr.domain do arr[i] = 0");;

  timer.clear();
  timer.start();
  forall n in 0..#num_threads do for l in arr do l = 0;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tforall n in 0..#num_threads do for l in arr do l = 0");;

  timer.clear();
  timer.start();
  forall n in 0..#num_threads do forall l in arr do l = 0;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tforall n in 0..#num_threads do forall l in arr do l = 0");;

  timer.clear();
  timer.start();
  coforall loc in Locales[0..0] do on loc do arr = 0;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tcoforall loc in Locales[0..0] do on loc do arr = 0");;

  timer.clear();
  timer.start();
  coforall loc in Locales[0..0] do on loc do [i in arr.domain] arr[i] = 0;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tcoforall loc in Locales[0..0] do on loc do [i in arr.domain] arr[i] = 0");;

  timer.clear();
  timer.start();
  coforall loc in Locales[0..0] do on loc do for i in arr.domain do arr[i] = 0;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tcoforall loc in Locales[0..0] do on loc do for i in arr.domain do arr[i] = 0");;

  timer.clear();
  timer.start();
  coforall loc in Locales[0..0] do on loc do forall i in arr.domain do arr[i] = 0;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tcoforall loc in Locales[0..0] do on loc do forall i in arr.domain do arr[i] = 0");;

  timer.clear();
  timer.start();
  coforall loc in Locales[0..0] do on loc do for l in arr do l = 0;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tcoforall loc in Locales[0..0] do on loc do for l in arr do l = 0");;

  timer.clear();
  timer.start();
  coforall loc in Locales[0..0] do on loc do forall l in arr do l = 0;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tcoforall loc in Locales[0..0] do on loc do forall l in arr do l = 0");;

  timer.clear();
  timer.start();
  coforall loc in Locales[0..0] do on loc do forall n in 0..#num_threads do arr = 0;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tcoforall loc in Locales[0..0] do on loc do forall n in 0..#num_threads do arr = 0");;

  timer.clear();
  timer.start();
  coforall loc in Locales[0..0] do on loc do forall n in 0..#num_threads do [i in arr.domain] arr[i] = 0;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tcoforall loc in Locales[0..0] do on loc do forall n in 0..#num_threads do [i in arr.domain] arr[i] = 0");;

  timer.clear();
  timer.start();
  coforall loc in Locales[0..0] do on loc do forall n in 0..#num_threads do for i in arr.domain do arr[i] = 0;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tcoforall loc in Locales[0..0] do on loc do forall n in 0..#num_threads do for i in arr.domain do arr[i] = 0");;

  timer.clear();
  timer.start();
  coforall loc in Locales[0..0] do on loc do forall n in 0..#num_threads do forall i in arr.domain do arr[i] = 0;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tcoforall loc in Locales[0..0] do on loc do forall n in 0..#num_threads do forall i in arr.domain do arr[i] = 0");;

  timer.clear();
  timer.start();
  coforall loc in Locales[0..0] do on loc do forall n in 0..#num_threads do for l in arr do l = 0;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tcoforall loc in Locales[0..0] do on loc do forall n in 0..#num_threads do for l in arr do l = 0");;

  timer.clear();
  timer.start();
  coforall loc in Locales[0..0] do on loc do forall n in 0..#num_threads do forall l in arr do l = 0;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tcoforall loc in Locales[0..0] do on loc do forall n in 0..#num_threads do forall l in arr do l = 0");;

  timer.clear();
  timer.start();
  [(i,j) in arr.domain] arr[i,j] = 0;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\t[(i,j) in arr.domain] arr[i,j] = 0");;

  timer.clear();
  timer.start();
  for (i,j) in arr.domain do arr[i,j] = 0;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tfor (i,j) in arr.domain do arr[i,j] = 0");;

  timer.clear();
  timer.start();
  forall (i,j) in arr.domain do arr[i,j] = 0;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tforall (i,j) in arr.domain do arr[i,j] = 0");;

  timer.clear();
  timer.start();
  forall n in 0..#num_threads do [(i,j) in arr.domain] arr[i,j] = 0;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tforall n in 0..#num_threads do [(i,j) in arr.domain] arr[i,j] = 0");;

  timer.clear();
  timer.start();
  forall n in 0..#num_threads do for (i,j) in arr.domain do arr[i,j] = 0;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tforall n in 0..#num_threads do for (i,j) in arr.domain do arr[i,j] = 0");;

  timer.clear();
  timer.start();
  forall n in 0..#num_threads do forall (i,j) in arr.domain do arr[i,j] = 0;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tforall n in 0..#num_threads do forall (i,j) in arr.domain do arr[i,j] = 0");;

  timer.clear();
  timer.start();
  coforall loc in Locales[0..0] do on loc do [(i,j) in arr.domain] arr[i,j] = 0;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tcoforall loc in Locales[0..0] do on loc do [(i,j) in arr.domain] arr[i,j] = 0");;

  timer.clear();
  timer.start();
  coforall loc in Locales[0..0] do on loc do for (i,j) in arr.domain do arr[i,j] = 0;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tcoforall loc in Locales[0..0] do on loc do for (i,j) in arr.domain do arr[i,j] = 0");;

  timer.clear();
  timer.start();
  coforall loc in Locales[0..0] do on loc do forall (i,j) in arr.domain do arr[i,j] = 0;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tcoforall loc in Locales[0..0] do on loc do forall (i,j) in arr.domain do arr[i,j] = 0");;

  timer.clear();
  timer.start();
  coforall loc in Locales[0..0] do on loc do forall n in 0..#num_threads do [(i,j) in arr.domain] arr[i,j] = 0;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tcoforall loc in Locales[0..0] do on loc do forall n in 0..#num_threads do [(i,j) in arr.domain] arr[i,j] = 0");;

  timer.clear();
  timer.start();
  coforall loc in Locales[0..0] do on loc do forall n in 0..#num_threads do for (i,j) in arr.domain do arr[i,j] = 0;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tcoforall loc in Locales[0..0] do on loc do forall n in 0..#num_threads do for (i,j) in arr.domain do arr[i,j] = 0");;

  timer.clear();
  timer.start();
  coforall loc in Locales[0..0] do on loc do forall n in 0..#num_threads do forall (i,j) in arr.domain do arr[i,j] = 0;
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tcoforall loc in Locales[0..0] do on loc do forall n in 0..#num_threads do forall (i,j) in arr.domain do arr[i,j] = 0");;

}

writeln("**");
writeln("** Block dmapped memory copy tests");
writeln("**");

{

  var dom = {0..#numLocales, 0..1024};
  const domBlockSpace = dom dmapped Block(boundingBox=dom);
  var arr: [domBlockSpace] elemType;

  timer.clear();
  timer.start();
  arr[0,..] = arr[1,..];
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tarr[0,..] = arr[1,..]");;

  timer.clear();
  timer.start();
  arr[0,dom.dim(2)] = arr[1,dom.dim(2)];
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tarr[0,dom.dim(2)] = arr[1,dom.dim(2)]");;

  timer.clear();
  timer.start();
  [i in dom.dim(2)] arr[0,i] = arr[1,i];
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\t[i in dom.dim(2)] arr[0,i] = arr[1,i]");;

  timer.clear();
  timer.start();
  forall i in dom.dim(2) do arr[0,i] = arr[1,i];
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tforall i in dom.dim(2) do arr[0,i] = arr[1,i]");;

  timer.clear();
  timer.start();
  coforall loc in Locales[0..0] do on loc do forall i in dom.dim(2) do arr[0,i] = arr[1,i];
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tcoforall loc in Locales[0..0] do on loc do forall i in dom.dim(2) do arr[0,i] = arr[1,i]");;

  timer.clear();
  timer.start();
  coforall loc in Locales[1..1] do on loc do forall i in dom.dim(2) do arr[0,i] = arr[1,i];
  timer.stop();
  info(timer.elapsed(TimeUnits.microseconds), ":\tcoforall loc in Locales[1..1] do on loc do forall i in dom.dim(2) do arr[0,i] = arr[1,i]");;

}

writeln("**");
writeln("** DimensionalDist2D dmapped tests");
writeln("**");

{

  var targetLocales: [0..#1, 0..#1] locale = Locales[0];
  targetLocales[1,0] = Locales[1];
  const FooSpace = {0..#1, 0..#n};
  const Foo = FooSpace dmapped DimensionalDist2D(targetLocales, new ReplicatedDim(numLocales=1), new BlockDim(numLocales=1, boundingBox = 0..#n));
  var replB: [Foo] elemType;
}
