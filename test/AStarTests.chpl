use UnitTest;
use AStar;

record Impl {
  proc init() { }
}

record CounterImpl {
  proc isGoalState(context : Int) {
    return context.value == 10;
  }

  iter findNeighbors(context : Int) {
    yield new Int(context.value + 1);
  }

  proc heuristic(context : Int) {
    return (10 - context.value);
  }

  proc distance(a : Int, b : Int) {
    return abs(a.value-b.value);
  }
}

proc test_init_Searcher(test: borrowed Test) throws {
  const foo = new Int();
  const impl = new Impl();

  const searcher = new Searcher(foo.type, impl);

  test.assertTrue(true);
}

record Int {
  var value : int = 0;
}

proc ==(l: Int, r: Int) {
  return (l.value == r.value);
}

proc test_aStar(test: borrowed Test) throws {
  const impl = new CounterImpl();
  const searcher = new Searcher(Int, impl);
  var start = new Int();
  const g = 0.0:real;
  var result = searcher.aStar(start, g);
  test.assertTrue(true);
}

proc test_aStar_inputIsCountOneToTen_OutputIsDistanceNine(test: borrowed Test) throws {
  const impl = new CounterImpl();
  const searcher = new Searcher(Int, impl);
  var start = new Int();
  const g = 0.0:real;
  var (distance,_) = searcher.aStar(start, g);
  test.assertEqual(9.0, distance);
}

UnitTest.main();
