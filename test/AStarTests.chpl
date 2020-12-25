use UnitTest;
use AStar;
use DistributedBag;

private use BlockDist;
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

proc test_remove_inputContainsFirst(test: borrowed Test) throws {
  const impl = new CounterImpl();
  const searcher = new Searcher(Int, impl);
  var bag = new DistBag(int(64));
  bag.add(0);
  bag.add(1);
  
  var result = searcher._remove(bag, 2);

  test.assertTrue(result.contains(0));
}

proc test_remove_inputContainsSecond(test: borrowed Test) throws {
  const impl = new CounterImpl();
  const searcher = new Searcher(Int, impl);
  var bag = new DistBag(int(64));
  bag.add(0);
  bag.add(1);
  
  var result = searcher._remove(bag, 2);

  test.assertTrue(result.contains(1));
}

proc test_remove_inputRemainsSameSize(test: borrowed Test) throws {
  const impl = new CounterImpl();
  const searcher = new Searcher(Int, impl);
  var bag = new DistBag(int(64));
  bag.add(0);
  bag.add(1);
  
  var result = searcher._remove(bag, 2);

  test.assertTrue(result.contains(0));
  test.assertTrue(result.contains(1));
  test.assertFalse(result.contains(2));
}


proc test_remove_resultLacksRemovedElement(test: borrowed Test) throws {
  const impl = new CounterImpl();
  const searcher = new Searcher(Int, impl);
  var bag = new DistBag(int(64));
  bag.add(0);
  bag.add(0);
  bag.add(1);
  
  var result = searcher._remove(bag, 1);

  test.assertTrue(result.contains(0));
  test.assertFalse(result.contains(1));
}

proc test__isEmptySearchSpace_inputIsEmpty(test: borrowed Test) throws {
  const impl = new CounterImpl();
  const searcher = new Searcher(Int, impl);
  var bag = new DistBag(int(64));
  test.assertTrue(searcher._isEmptySearchSpace(bag));
}

proc test__isEmptySearchSpace_inputHasOneElement(test: borrowed Test) throws {
  const impl = new CounterImpl();
  const searcher = new Searcher(Int, impl);
  var bag = new DistBag(int(64));
  bag.add(0);
  test.assertFalse(searcher._isEmptySearchSpace(bag));
}

proc test__isEmptySearchSpace_inputIsEmptyAgain(test: borrowed Test) throws {
  const impl = new CounterImpl();
  const searcher = new Searcher(Int, impl);
  var bag = new DistBag(int(64));
  bag.add(0);
  bag.remove();
  test.assertTrue(searcher._isEmptySearchSpace(bag));
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

proc test__pickScoresAndState(test: borrowed Test) throws {
  const impl = new CounterImpl();
  const searcher = new Searcher(Int, impl);
  
  var D : domain(1) dmapped Block(boundingBox={0..2}) = {0..2};
  var fScores : [D] real;
  fScores[0] = max(real);
  fScores[1] = 1.0;
  fScores[2] = max(real);
  
  var visited = new DistBag(int(64));

  visited.add(1);
  visited.add(2);

  var result = searcher._pickScoresAndState(visited.these(), fScores);
  var counter = 0;
  for r in result do
    counter += 1;
  test.assertEqual(2, counter);
}

proc test_getElementWithLowestFScore(test: borrowed Test) throws {
  var D : domain(1) dmapped Block(boundingBox={0..2}) = {0..2};
  var fScores : [D] real;
  fScores[0] = max(real);
  fScores[1] = 1.0;
  fScores[2] = max(real);
  var allStates : [D] Int;
  allStates[0] = new Int(0);
  allStates[1] = new Int(1);
  allStates[2] = new Int(2);
  var visited = new DistBag(int(64));
  visited.add(0);
  visited.add(1);
  visited.add(2);


  const impl = new CounterImpl();
  const searcher = new Searcher(Int, impl);
  
  var result = searcher._getElementWithLowestFScore(visited, fScores, allStates);
  test.assertEqual(1, result[0]);
  test.assertEqual(1, result[1].value);
}

UnitTest.main();
