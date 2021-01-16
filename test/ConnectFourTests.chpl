use UnitTest;
use ConnectFour;
use Player;
use State;
use GameContext;
use Tile;


proc test_findNextPlayer_InputIsRed(test: borrowed Test) throws {
  const connectFour = new ConnectFour(1);
  const red = Player.Red;
  const result = connectFour.findNextPlayer(red);
  test.assertEqual(Player.Yellow, result);
}

proc test_findNextPlayer_InputIsYellow(test: borrowed Test) throws {
  const connectFour = new ConnectFour(1);
  const red = Player.Yellow;
  const result = connectFour.findNextPlayer(red);
  test.assertEqual(Player.Red, result);
}

proc test_placeTile_InputIsRed(test: borrowed Test) throws {
  const connectFour = new ConnectFour(1);
  const red = Player.Red;
  const result = connectFour.placeTile(red);
  test.assertEqual(Tile.Red, result);
}

proc test_placeTile_InputIsYellow(test: borrowed Test) throws {
  const connectFour = new ConnectFour(1);
  const red = Player.Yellow;
  const result = connectFour.placeTile(red);
  test.assertEqual(Tile.Yellow, result);
}

proc test_countWindows_WindowsAreHorizontal(test: borrowed Test) throws {
  const connectFour = new ConnectFour(1);
  var board: [BoardDom] Tile;
  for i in 0..3 do
      board[0, i] = Tile.Red;
  for i in 1..4 do
      board[2, i] = Tile.Red;    
  const state = new GameContext(board=board, player=Player.Red);
  
  const result = connectFour.countWindows(state, 4);

  test.assertEqual(2, result);
}

proc test_countWindows_WindowsAreVertical(test: borrowed Test) throws {
  const connectFour = new ConnectFour(1);
  var board: [BoardDom] Tile;
  for i in 0..3 do
      board[i, 0] = Tile.Red;
  for i in 1..4 do
      board[i, 1] = Tile.Red;
  const state = new GameContext(board=board, Player.Red);
  
  const result = connectFour.countWindows(state, 4);

  test.assertEqual(2, result);
}

proc test_countWindows_WindowsAreDiagonalLeftToRight(test: borrowed Test) throws {
  const connectFour = new ConnectFour(1);
  var board: [BoardDom] Tile;
  board[0, 0] = Tile.Red;
  board[1, 1] = Tile.Red;
  board[2, 2] = Tile.Red;
  board[3, 3] = Tile.Red;
  const state = new GameContext(board=board, player=Player.Red);
  
  const result = connectFour.countWindows(state, 4);
  
  test.assertEqual(1, result);
}

proc test_countWindows_WindowsAreDiagonalRightToLeft(test: borrowed Test) throws {
  const connectFour = new ConnectFour(1);
  var board: [BoardDom] Tile;
  board[0, 3] = Tile.Red;
  board[1, 2] = Tile.Red;
  board[2, 1] = Tile.Red;
  board[3, 0] = Tile.Red;
  const state = new GameContext(board=board, player=Player.Red);
    
  const result = connectFour.countWindows(state, 4);
  
  test.assertEqual(1, result);
}

proc test_StateEquals(test: borrowed Test) throws {
  const state = new State();
  const stateTwo = new State();
  test.assertTrue(state == stateTwo);
}

proc test_countWindowsDiagonalLeftToRight_WindowsAreDiagonalLeftToRight(test: borrowed Test) throws {
  const connectFour = new ConnectFour(1);
  var board: [BoardDom] Tile;
  board[0, 0] = Tile.Red;
  board[1, 1] = Tile.Red;
  board[2, 2] = Tile.Red;
  board[3, 3] = Tile.Red;    
  const state = new State(board=board);
  
  const result = connectFour.countWindowsDiagonalLeftToRight(state.board, Tile.Red, 4);
  
  test.assertEqual(1, result);
}

proc test_isGoalState_RedPlayerIsWinning(test: borrowed Test) throws {
  var board: [BoardDom] Tile;
  board[0, 0] = Tile.Red;
  board[0, 1] = Tile.Red;
  board[0, 2] = Tile.Red;
  board[0, 3] = Tile.Red;  
  const state = new GameContext(board=board, player=Player.Red);
  const connectFour = new ConnectFour(1);
  test.assertTrue(connectFour.isGoalState(state));
}

proc test_isGoalState_YellowPlayerIsWinning(test: borrowed Test) throws {
  var board: [BoardDom] Tile;
  board[0, 0] = Tile.Yellow;
  board[0, 1] = Tile.Yellow;
  board[0, 2] = Tile.Yellow;
  board[0, 3] = Tile.Yellow;  
  const state = new GameContext(board=board, player=Player.Yellow);
  const connectFour = new ConnectFour(1);
  test.assertTrue(connectFour.isGoalState(state));
}

proc test_isGoalState_NoPlayerIsWinning(test: borrowed Test) throws {
  var board: [BoardDom] Tile;
  board[0, 0] = Tile.Yellow;
  board[0, 1] = Tile.Yellow;
  board[0, 2] = Tile.Yellow;
  const state = new GameContext(board=board, player=Player.Yellow);
  const connectFour = new ConnectFour(1);
  test.assertFalse(connectFour.isGoalState(state));
}

proc oneIfNotUnplaced(tile: Tile) {
  if tile != Tile.Unset then return 1;
  else return 0;
}

proc test__createNextState_outputPlayerIsNotEqualToInputPlayer(test: borrowed Test) throws {
  const connectFour = new ConnectFour(1);
  var start: [BoardDom] Tile;
  var gameContext = new GameContext(board=start, player=Player.Yellow);
  var result = connectFour._createNextState(gameContext, (0, 0));
  test.assertNotEqual(result.player, gameContext.player);
}

proc test__createNextState_outputBoardIsNotEqualToInputBoard(test: borrowed Test) throws {
  const connectFour = new ConnectFour(1);
  var start: [BoardDom] Tile;
  var gameContext = new GameContext(board=start, player=Player.Yellow);
  var result = connectFour._createNextState(gameContext, (0, 0));
  test.assertNotEqual(result.board, gameContext.board);
}

proc test_findNeighbors_numberOfNeigborsIs7(test: borrowed Test) throws {
  const connectFour = new ConnectFour(1);
  var start: [BoardDom] Tile;
  var gameContext = new GameContext(board=start, player=Player.Yellow);
  var it = 0;

  for neighbor in connectFour.findNeighbors(gameContext) {
    it += 1;
  }

  test.assertEqual(7, it);
}

proc test_findNeighbors(test: borrowed Test) throws {
  const connectFour = new ConnectFour(1);
  var start: [BoardDom] Tile;
  var gameContext = new GameContext(board=start, player=Player.Yellow);
  
  for neighbor in connectFour.findNeighbors(gameContext) {
    var values: [BoardDom] int;
    var i = 0;
    for d in neighbor.board.domain {
      values[d] = oneIfNotUnplaced(neighbor.board[d]);
      i += 1;
    }

    test.assertEqual(1, (+ reduce values));
  }
}

proc test_BoardDim_ColumnsStartsAtIndex0(test: borrowed Test) throws {
  const connectFour = new ConnectFour(1);
  var start: [BoardDom] Tile;
  test.assertEqual(0, start.domain.low(1));
}

proc test_BoardDim_ColumnsEndsAtIndex6(test: borrowed Test) throws {
  const connectFour = new ConnectFour(1);
  var start: [BoardDom] Tile;
  test.assertEqual(6, start.domain.high(1));
}

proc test_boardHas42Spots(test: borrowed Test) throws {
  const board: [BoardDom] Tile;
  var size = 0;  
  for d in board.domain {
    size += 1;
  }

  param expectedSize = 6 * 7;
  test.assertEqual(expectedSize, size);
}

UnitTest.main();
