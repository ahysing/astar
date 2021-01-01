use UnitTest;
use AStar;
use DistributedBag;
use LinkedLists;

private use BlockDist;
record Impl {
  proc init() { }
}

record CounterImpl {
  proc isGoalState(context : Int) {
    return context.value == 10;
  }

  iter findNeighbors(context : Int) {
    const next = context.value + 1;
    yield new Int(next);
  }

  proc heuristic(context : Int) {
    return (10 - context.value);
  }

  proc distance(a : Int, b : Int) {
    return a.value - b.value;
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

proc test_Int_Equals(test: borrowed Test) throws {
  const one = new Int(1);
  const oneAgain = new Int(1);

  test.assertEqual(one, oneAgain);
}

proc test_Int_NotEquals(test: borrowed Test) throws {
  const one = new Int(1);
  const two = new Int(2);

  test.assertNotEqual(one, two);
}


proc test_CounterImpl_FindNeigbors(test: borrowed Test) throws {
  const impl = new CounterImpl();
  const one = new Int(1);
  var hasIterated = false;
  for result in impl.findNeighbors(one) {
    test.assertEqual(new Int(2), result);
    hasIterated = true;
  }
  test.assertTrue(hasIterated);
}

proc test_CounterImpl_IsGoalState(test: borrowed Test) throws {
  const impl = new CounterImpl();
  const ten = new Int(10);
  
  test.assertTrue(impl.isGoalState(ten));

  const eleven = new Int(11);
  test.assertFalse(impl.isGoalState(eleven));
}




proc test_remove_inputContainsFirst(test: borrowed Test) throws {
  const impl = new CounterImpl();
  const searcher = new Searcher(Int, impl);
  var bag = new DistBag(int(64));
  bag.add(0);
  bag.add(1);
  
  searcher._remove(bag, 2);

  test.assertTrue(bag.contains(0));
}

proc test_remove_inputContainsSecond(test: borrowed Test) throws {
  const impl = new CounterImpl();
  const searcher = new Searcher(Int, impl);
  var bag = new DistBag(int(64));
  bag.add(0);
  bag.add(1);
  
  searcher._remove(bag, 2);

  test.assertTrue(bag.contains(1));
}

proc test_remove_inputRemainsSameSize(test: borrowed Test) throws {
  const impl = new CounterImpl();
  const searcher = new Searcher(Int, impl);
  var bag = new DistBag(int(64));
  bag.add(0);
  bag.add(1);
  
  searcher._remove(bag, 2);

  test.assertTrue(bag.contains(0));
  test.assertTrue(bag.contains(1));
  test.assertFalse(bag.contains(2));
}


proc test_remove_resultLacksRemovedElement(test: borrowed Test) throws {
  const impl = new CounterImpl();
  const searcher = new Searcher(Int, impl);
  var bag = new DistBag(int(64));
  bag.add(0);
  bag.add(0);
  bag.add(1);
  
  searcher._remove(bag, 1);

  test.assertTrue(bag.contains(0));
  test.assertFalse(bag.contains(1));
}

proc test_removeStateFromOpenSet_SetsGScoreIndexToMinusInfinity(test: borrowed Test) throws {
  var gScores : [0..2] real = max(real);
  var openSet = new DistBag(int);
  const idx = 1;
  openSet.add(idx);
  const impl = new CounterImpl();
  const searcher = new Searcher(Int, impl);

  
  searcher._removeStateFromOpenSet(openSet, gScores, idx);


  test.assertEqual(min(real), gScores[idx]);
  test.assertEqual(false, openSet.contains(idx));
}

proc test_removeStateFromOpenSet(test: borrowed Test) throws {
  var gScores : [0..2] real;
  var openSet = new DistBag(int);
  const idx = 1;
  openSet.add(0);
  openSet.add(1);
  openSet.add(2);
  openSet.add(3);
  const impl = new CounterImpl();
  const searcher = new Searcher(Int, impl);


  searcher._removeStateFromOpenSet(openSet, gScores, idx);


  test.assertEqual(false, openSet.contains(idx));
  test.assertEqual(true, openSet.contains(0));
  test.assertEqual(true, openSet.contains(2));
  test.assertEqual(true, openSet.contains(3));
}

proc test__isEmptySearchSpace_inputIsEmpty(test: borrowed Test) throws {
  const impl = new CounterImpl();
  const searcher = new Searcher(Int, impl);
  var bag = new DistBag(int(64));
  test.assertTrue(searcher._isEmptySearchSpace(bag));
}
proc test__isEmptySearchSpace_inputIsEmpty_OtherBagisNotEmpty(test: borrowed Test) throws {
  const impl = new CounterImpl();
  const searcher = new Searcher(Int, impl);
  var bag = new DistBag(int(64));

  var bagWithSideEffect = new DistBag(int(64));
  bagWithSideEffect.add(1);
  bagWithSideEffect.add(2);
  
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
/*
proc test_aStar_inputIsCountOneToTen_OutputIsDistanceNine(test: borrowed Test) throws {
  const impl = new CounterImpl();
  const searcher = new Searcher(Int, impl);
  var start = new Int();
  const g = 0.0:real;
  var (distance,_) = searcher.aStar(start, g);
  test.assertEqual(9.0, distance);
}
*/
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
  allStates[0] = new Int(10);
  allStates[1] = new Int(11);
  allStates[2] = new Int(12);
  var visited = new DistBag(int(64));
  visited.add(0);
  visited.add(1);
  visited.add(2);

  const impl = new CounterImpl();
  const searcher = new Searcher(Int, impl);


  var result = searcher._getElementWithLowestFScore(visited, fScores, allStates);

  const expectedIdx = 1;
  test.assertEqual(expectedIdx, result[0]);
  const expectedValue = 11;
  test.assertEqual(expectedValue, result[1].value);
}

proc test_reverseLinearSearch_InputIsZeroOne(test: borrowed Test) throws {
  const impl = new CounterImpl();
  const searcher = new Searcher(int, impl);

  const allStates : [0..1] int = {0..1};
  const lookingFor = 1;
  const high = 1;
  
  var (found, idx) = searcher._reverseLinearSearch(allStates, lookingFor, high);

  test.assertTrue(found);
  test.assertEqual(lookingFor, idx);
}

proc test_reverseLinearSearch(test: borrowed Test) throws {
  const impl = new CounterImpl();
  const searcher = new Searcher(int, impl);

  const allStates : [0..20] int = {0..20};
  const lookingFor = 8;
  const high = 10;
  
  var (found, idx) = searcher._reverseLinearSearch(allStates, lookingFor, high);

  test.assertTrue(found);
  test.assertEqual(lookingFor, idx);
}

proc test_reverseLinearSearch_inputIsOusideOfRange(test: borrowed Test) throws {
  const impl = new CounterImpl();
  const searcher = new Searcher(int, impl);

  const allStates : [0..20] int = {0..20};
  const lookingFor = 11;
  const high = 10;
  
  var (found, idx) = searcher._reverseLinearSearch(allStates, lookingFor, high);

  test.assertFalse(found);
}

proc test__pushBackWithLowestGScore(test: borrowed Test) throws {
  var path = new LinkedList(int);
  const impl = new CounterImpl();
  const searcher = new Searcher(int, impl);

  const foo = 0;
  const bar = 42;
  var nextPotentialPaths : domain((real, int)) = { (200.0, foo), (1.0, bar), (1000.0, foo) };
  searcher._pushBackWithLowestGScore(path, nextPotentialPaths);

  test.assertEqual(1, path.size);
  test.assertEqual(42, path.pop_front());
}

UnitTest.main();
