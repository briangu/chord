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

const dom = {0..#(n*1024*1024)};
var priv_arr: [PrivateSpace][dom] elemType;

const dom2 = {0..#k,0..#(n*1024*1024)};
var priv_arr2: [PrivateSpace][dom2] elemType;

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
writeln("localMemory.arr[localMemory2.dom] = remoteMemory2.arr[localMemory.dom]: ", timer.elapsed(TimeUnits.microseconds));
