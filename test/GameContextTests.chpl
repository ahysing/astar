use UnitTest;
use GameContext;
use Tile;
use Player;

proc test_GameContext_Constructor(test: borrowed Test) throws {
  var gameContext = new owned GameContext();
  test.assertTrue(gameContext.player == Player.Yellow || gameContext.player == Player.Red);
}

proc isRedOrYellow(tile: Tile) {
  return tile == Tile.Red || tile == Tile.Yellow;
}

const numRows: int = 6;
const numColumns: int = 7;
const StateDom: domain(2) = {0..(numRows - 1), 0..(numColumns - 1)};
proc test_GameContext_ConstructorWithParameters(test: borrowed Test) throws {
  var board: [StateDom] Tile;
  for (i, j) in board.domain do
    if i % 2 == 1 || j % 2 == 1 then
      board[(i, j)] = Tile.Red;
    else
      board[(i, j)] = Tile.Yellow;

  var gameContext = new owned GameContext(board=board, player=Player.Red);
  test.assertTrue(&& reduce isRedOrYellow(gameContext.board));
}

proc test_GameContext_ConstructorWithParameters_OutputPlayerIsRed(test: borrowed Test) throws {
  var board: [StateDom] Tile;
  var gameContext = new owned GameContext(board=board, player=Player.Red);
  test.assertEqual(Player.Red, gameContext.player);
}

proc test_GameContext_ConstructorWithParameters_OutputPlayerIsYellow(test: borrowed Test) throws {
  var board: [StateDom] Tile;
  var gameContext = new owned GameContext(board=board, player=Player.Yellow);
  test.assertEqual(Player.Yellow, gameContext.player);
}

UnitTest.main();
