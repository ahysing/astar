use UnitTest;
use ConnectFour;
use Player;
use State;

proc test_StateEquals(test: borrowed Test) throws {
  const state = new State();
  const stateTwo = new State();
  test.assertTrue(state == stateTwo);
}

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
  var board : [DLocal] Tile;
  for i in 0..3 do
      board[0, i] = Tile.Red;
  for i in 1..4 do
      board[2, i] = Tile.Red;    
  const state = new State(board=board);
  
  const result = connectFour.countWindows(state, Player.Red, 4);

  test.assertEqual(2, result);
}

proc test_countWindows_WindowsAreVertical(test: borrowed Test) throws {
  const connectFour = new ConnectFour(1);
  var board : [DLocal] Tile;
  for i in 0..3 do
      board[i, 0] = Tile.Red;
  for i in 1..4 do
      board[i, 1] = Tile.Red;
  const state = new State(board=board);
  
  const result = connectFour.countWindows(state, Player.Red, 4);

  test.assertEqual(2, result);
}

proc test_countWindowsDiagonalLeftToRight_WindowsAreDiagonalLeftToRight(test: borrowed Test) throws {
  const connectFour = new ConnectFour(1);
  var board : [DLocal] Tile;
  board[0, 0] = Tile.Red;
  board[1, 1] = Tile.Red;
  board[2, 2] = Tile.Red;
  board[3, 3] = Tile.Red;    
  const state = new State(board=board);
  
  const result = connectFour.countWindowsDiagonalLeftToRight(state.board, Tile.Red, 4);
  
  test.assertEqual(1, result);
}

proc test_countWindows_WindowsAreDiagonalLeftToRight(test: borrowed Test) throws {
  const connectFour = new ConnectFour(1);
  var board : [DLocal] Tile;
  board[0, 0] = Tile.Red;
  board[1, 1] = Tile.Red;
  board[2, 2] = Tile.Red;
  board[3, 3] = Tile.Red;    
  const state = new State(board=board);
  
  const result = connectFour.countWindows(state, Player.Red, 4);
  
  test.assertEqual(1, result);
}

proc test_countWindows_WindowsAreDiagonalRightToLeft(test: borrowed Test) throws {
  const connectFour = new ConnectFour(1);
  var board : [DLocal] Tile;
  board[0, 3] = Tile.Red;
  board[1, 2] = Tile.Red;
  board[2, 1] = Tile.Red;
  board[3, 0] = Tile.Red;   
  const state = new State(board=board);
  
  const result = connectFour.countWindows(state, Player.Red, 4);
  
  test.assertEqual(1, result);
}

proc test_isGoalState_RedPlayerIsWinning(test: borrowed Test) throws {
  var board : [DLocal] Tile;
  board[0, 0] = Tile.Red;
  board[0, 1] = Tile.Red;
  board[0, 2] = Tile.Red;
  board[0, 3] = Tile.Red;  
  const state = new State(board=board);
  const connectFour = new ConnectFour(1);
  test.assertTrue(connectFour.isGoalState(state));
}

proc test_isGoalState_YellowPlayerIsWinning(test: borrowed Test) throws {
  var board : [DLocal] Tile;
  board[0, 0] = Tile.Yellow;
  board[0, 1] = Tile.Yellow;
  board[0, 2] = Tile.Yellow;
  board[0, 3] = Tile.Yellow;  
  const state = new State(board=board);
  const connectFour = new ConnectFour(1);
  test.assertTrue(connectFour.isGoalState(state));
}

proc test_isGoalState_NoPlayerIsWinning(test: borrowed Test) throws {
  var board : [DLocal] Tile;
  board[0, 0] = Tile.Yellow;
  board[0, 1] = Tile.Yellow;
  board[0, 2] = Tile.Yellow;
  const state = new State(board=board);
  const connectFour = new ConnectFour(1);
  test.assertFalse(connectFour.isGoalState(state));
}

UnitTest.main();
