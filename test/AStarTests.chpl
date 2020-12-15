use UnitTest;
use AStar;
use Heap;

class Foo {
}

record Impl {
}

proc test_init_Searcher(test: borrowed Test) throws {
  const foo = new Foo();
  const impl = new Impl();
  const searcher = new Searcher(foo.type, impl);
  test.assertTrue(true);
}

proc test_containsNeighbor_InputContainsNeigbor(test: borrowed Test) throws {
  const foo = new Foo();
  const impl = new Impl();
  const searcher = new Searcher(foo.type, impl);
  const n : int = 1;
  var all = new heap(int);
  all.push(2);
  all.push(1);

  const result = searcher.containsNeighbor(all, n);

  test.assertTrue(result);
}

proc test_containsNeighbor_InputLacksNeigbor(test: borrowed Test) throws {
  const foo = new Foo();
  const impl = new Impl();
  const searcher = new Searcher(foo.type, impl);
  const n : int = 1;
  var all = new heap(int);
  all.push(2);
  all.push(3);

  const result = searcher.containsNeighbor(all, n);

  test.assertFalse(result);
}

UnitTest.main();
