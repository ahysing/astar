use UnitTest;
use AStar;
use Heap;

class Foo {
  proc init() { }
}

record Impl {
  proc init() { }
}

record CounterImpl {
  proc isGoalState(context : Int) {
    return context.value == 10;
  }

  proc numberOfNeighborsNext() {
    return 1;
  }

  proc heuristic(context : Int) {
    return (10 - context.value);
  }

  proc distance(a : Int, b : Int) {
    return abs(a.value-b.value);
  }
}

proc test_init_Searcher(test: borrowed Test) throws {
  const foo = new Foo();
  const impl = new Impl();

  const searcher = new Searcher(foo.type, impl);

  test.assertTrue(true);
}

class Int {
  var value : int;
}

proc test_aStar(test: borrowed Test) throws {
  const impl = new CounterImpl();
  const searcher = new Searcher(Int, impl);
  var start = new Int(1);
  const g = 0.0:real;

  var result = searcher.aStar(start, g);
  test.assertTrue(true);
}

proc test_aStar_inputIsCountOneToTen_OutputIsDistanceNine(test: borrowed Test) throws {
  const impl = new CounterImpl();
  const searcher = new Searcher(Int, impl);
  var start = new Int(1);
  const g = 0.0:real;

  var result = searcher.aStar(start, g);
  test.assertEquals(9, result.distance);
}

UnitTest.main();
