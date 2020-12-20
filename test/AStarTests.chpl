use UnitTest;
use AStar;
use Heap;

class Foo {
  proc init() { }
}

record Impl {
  proc init() { }
}

proc test_init_Searcher(test: borrowed Test) throws {
  const foo = new Foo();
  const impl = new Impl();
  const searcher = new Searcher(foo.type, impl);
  test.assertTrue(true);
}

UnitTest.main();
