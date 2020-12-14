use UnitTest;
use AStar;

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

UnitTest.main();
