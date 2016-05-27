
indent = 0

def r(raw):
    print raw

def x(text, i = -1):
    global indent
    i = indent if i == -1 else i
    if i > 0:
        x(text if len(text) == 0 else "  {}".format(text), i - 1)
    else:
        r(text if len(text) == 0 else "{};".format(text))

def w(text, i = -1):
    x("writeln(\"{}\")".format(text));

def startSection(description):
    global indent
    x("")
    w("**")
    w("** {}".format(description))
    w("**")
    x("")
    r("{")
    x("")
    indent += 1

def stopSection():
    global indent
    indent -= 1
    r("}")

def c(clause):
    x("timer.clear()")
    x("timer.start()")
    x(clause)
    x("timer.stop()")
    x("info({}, \":\\t{}\");".format("timer.elapsed(TimeUnits.microseconds)", clause));
    x("")

def startClass(name):
    global indent
    x("class {} {}".format(name, '{'))
    indent += 1

def stopClass():
    global indent
    indent -=1
    x("}")
    x("")

def allthreads(cmd):
    return "forall n in 0..#num_threads do {}".format(cmd)

def coforall(cmd, locale = 0):
    return "coforall loc in Locales[{}..{}] do on loc do {}".format(locale, locale, cmd)


x("use BlockDist")
x("use Logging")
x("use PrivateDist")
x("use DimensionalDist2D, BlockDim, BlockCycDim, ReplicatedDim")
x("use Time")
x("")
x("type elemType = real")
x("")
x("config const n = 16")
x("config const k = 1")
x("config const num_threads = here.maxTaskPar")
x("")
x("var timer: Timer")

def privateDistCommonCopyTests():
    # c("[i in dom] arr[0][i] = arr[1][i]");
    tests = [
        "arr[0] = arr[1]",
        "arr[0][dom] = arr[1][dom]"
    ]
    for cmd in tests:
        c(cmd)
    for cmd in tests:
        c(coforall(cmd))
        c(coforall(cmd, 1))

startSection("PrivateSpace copy tests")
x("const dom = {0..#(n*1024*1024)}")
x("var arr: [PrivateSpace][dom] elemType")
x("")
privateDistCommonCopyTests()
stopSection()

startSection("PrivateSpace 2D copy tests")
x("const dom = {0..#k,0..#(n*1024*1024)}")
x("var arr: [PrivateSpace][dom] elemType")
x("")
privateDistCommonCopyTests()
stopSection()

def localRemoteCommonCopyTests():
    # c("for (a,b) in zip(localMemory.arr, remoteMemory.arr) do a = b")
    # too slow to use
    # c("[i in localMemory.dom] localMemory.arr[i] = remoteMemory.arr[i]")
    # c("coforall loc in Locales[0..0] do on loc do [i in localMemory.dom] localMemory.arr[i] = remoteMemory.arr[i]")
    # c("coforall loc in Locales[1..1] do on loc do [i in localMemory.dom] localMemory.arr[i] = remoteMemory.arr[i]")
    # c("coforall loc in Locales[0..0] do on loc do for (a,b) in zip(localMemory.arr, remoteMemory.arr) do a = b")
    # c("coforall loc in Locales[1..1] do on loc do for (a,b) in zip(localMemory.arr, remoteMemory.arr) do a = b")
    tests = [
        "localMemory.arr = remoteMemory.arr",
        "localMemory.arr[localMemory.dom] = remoteMemory.arr[localMemory.dom]"
    ]
    for cmd in tests:
        c(cmd)
    for cmd in tests:
        c(allthreads(cmd))
    for cmd in tests:
        c(coforall(cmd))
        c(coforall(cmd,1))
    for cmd in tests:
        c(coforall(allthreads(cmd)))
        c(coforall(allthreads(cmd),1),)

startSection("local/remote class arr copy tests")
x("const dom = {0..#(n*1024*1024)}")
startClass("RemoteMemory")
x("var n: int")
x("var dom = {0..#n}")
x("var arr: [dom] elemType")
stopClass()
x("var localMemory = new RemoteMemory(dom.high)")
x("var remoteMemory: RemoteMemory")
x("on Locales[1] do remoteMemory = new RemoteMemory(dom.high)")
# x("writeln(localMemory.arr.domain, \" \", remoteMemory.arr.domain)")
x("")
localRemoteCommonCopyTests()
stopSection()

startSection("local/remote class 2D arr copy tests")
x("const dom = {0..#k, 0..#(n*1024*1024)}")
startClass("RemoteMemory")
x("var m: int")
x("var n: int")
x("var dom = {0..#m, 0..#n}")
x("var arr: [dom] elemType")
stopClass()
x("var localMemory = new RemoteMemory(dom.dim(1).high, dom.dim(2).high)")
x("var remoteMemory: RemoteMemory")
x("on Locales[1] do remoteMemory = new RemoteMemory(dom.dim(1).high, dom.dim(2).high)")
# x("writeln(localMemory.arr.domain, \" \", remoteMemory.arr.domain)")
x("")
localRemoteCommonCopyTests()
stopSection()

def assignmentCommonTests():
    # simple tests
    tests = [
        "arr = 0",
        "[i in arr.domain] arr[i] = 0",
        "for i in arr.domain do arr[i] = 0",
        "forall i in arr.domain do arr[i] = 0",
        "for l in arr do l = 0",
        "forall l in arr do l = 0"
    ]
    for cmd in tests:
        c(cmd)
    # simulate running a simulation on each thread
    for cmd in tests:
        c(allthreads(cmd))
    for cmd in tests:
        c(coforall(cmd))
    # simulate multi-locale and each locale running a simulation on each thread
    for cmd in tests:
        c(coforall(allthreads(cmd)))

startSection("local memory assignment tests")
x("const dom = {0..#(n*1024*1024)}")
x("var arr: [dom] elemType")
x("")
assignmentCommonTests()
stopSection()

def assignment2DTests():
    tests = [
        "[(i,j) in arr.domain] arr[i,j] = 0",
        "for (i,j) in arr.domain do arr[i,j] = 0",
        "forall (i,j) in arr.domain do arr[i,j] = 0"
    ]
    for cmd in tests:
        c(cmd)
    for cmd in tests:
        c(allthreads(cmd))
    for cmd in tests:
        c(coforall(cmd))
    for cmd in tests:
        c(coforall(allthreads(cmd)))

startSection("local 2D memory assignment tests")
x("const dom = {0..#k,0..#(n*1024*1024)}")
x("var arr: [dom] elemType")
x("")
assignmentCommonTests()
assignment2DTests()
# c("[(i,j) in arr.domain] arr[i,j] = 0")
# c("for (i,j) in arr.domain do arr[i,j] = 0")
# c("forall (i,j) in arr.domain do arr[i,j] = 0")
# c("forall n in 0..#num_threads do [(i,j) in arr.domain] arr[i,j] = 0")
# c("forall n in 0..#num_threads do forall (i,j) in arr.domain do arr[i,j] = 0")
# c("forall n in 0..#num_threads do for (i,j) in arr.domain do arr[i,j] = 0")
# c("coforall loc in Locales[0..0] do on loc do forall n in 0..#num_threads do for (i,j) in arr.domain do arr[i,j] = 0")
# c("coforall loc in Locales[0..0] do on loc do forall n in 0..#num_threads do forall (i,j) in arr.domain do arr[i,j] = 0")
stopSection()

startSection("Block dmapped memory copy tests")
x("var dom = {0..#numLocales, 0..1024}")
x("const domBlockSpace = dom dmapped Block(boundingBox=dom)")
x("var arr: [domBlockSpace] elemType")
x("")
# x("forall s in arr do s = here.id: elemType")
c("arr[0,..] = arr[1,..]")
c("arr[0,dom.dim(2)] = arr[1,dom.dim(2)]")
c("[i in dom.dim(2)] arr[0,i] = arr[1,i]")
c("forall i in dom.dim(2) do arr[0,i] = arr[1,i]")
c("coforall loc in Locales[0..0] do on loc do forall i in dom.dim(2) do arr[0,i] = arr[1,i]")
c("coforall loc in Locales[1..1] do on loc do forall i in dom.dim(2) do arr[0,i] = arr[1,i]")
stopSection()

startSection("DimensionalDist2D dmapped tests")
x("var targetLocales: [0..#1, 0..#1] locale = Locales[0]")
x("targetLocales[1,0] = Locales[1]")
x("const FooSpace = {0..#1, 0..#n}")
x("const Foo = FooSpace dmapped DimensionalDist2D(targetLocales, new ReplicatedDim(numLocales=1), new BlockDim(numLocales=1, boundingBox = 0..#n))")
x("var replB: [Foo] elemType")
stopSection();
