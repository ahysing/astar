use Barriers;
use List;
use AStar only Searcher, Visit;
use Player;
use Tile;

const numRows : int = 6;
const numColumns : int = 7;
const DLocal : domain(2) = {0..numRows, 0..numColumns};

record State {
  var board : [DLocal] Tile;
  var player : Player;

  proc init() { }

  proc init(board : [DLocal] Tile, player : Player) {
    this.board = board;
    this.player = player;
  }
}

proc ==(l: State, r: State) {
  // This function solves known issue https://github.com/chapel-lang/chapel/issues/7615
  // Compiler fails to generate default comparison between records with array fields
    return (l.player == r.player &&
        (&& reduce (l.board == r.board)));
}

record ConnectFour {
  var depth : int;
  proc init(depth) {
    this.depth = depth;
  }

  proc isGoalState(state : State) {
    var isGoal : atomic bool = false;
    cobegin {
      {
        var nextState = new State(board=state.board, player=Player.Red);
        if countWindows(nextState, 4) then
          isGoal.testAndSet();
      }
      {
        var nextState = new State(board=state.board, player=Player.Yellow);
        if countWindows(nextState, 4) then
          isGoal.testAndSet();
      }
    }

    return isGoal.read();
  }

  proc findNextPlayer(player : Player) : Player {
    if player == Player.Red then
      return Player.Yellow;
    if player == Player.Yellow then
      return Player.Red;
    else
      return Player.Red;
  }

  proc placeTile(player : Player) : Tile {
    if player == Player.Red then
      return Tile.Red;
    if player == Player.Yellow then
      return Tile.Yellow;
    else
      return Tile.Red;
  }

  proc createNextState(state : State, at : 2*int) {
    var nextBoard = state.board;
    nextBoard[at] = placeTile(state.player);
    const nextPlayer = findNextPlayer(state.player);
    const nextState = new State(player=nextPlayer, board=nextBoard);
    return nextState;
  }

  iter findNeighbors(state) {
    for (i, j) in DLocal do
      if i == 0 && state.board[i, j] == Tile.Unset then
        yield createNextState(state, (i, j));
      else if  i > 0 && state.board[i, j] == Tile.Unset && state.board[i - 1, j] != Tile.Unset then
        yield createNextState(state, (i, j));
  }

  proc _minimax(state : State, depth : int, maximizingPlayer : bool, player : Player, conf) : real {
    if depth == 0 || isGoalState(state) then
      return heuristic(state);
    else if maximizingPlayer {
      var value = min(real);
      for col in findNeighbors(state) do
        value = max(value, _minimax(dropPiece(state, col, player, conf), depth - 1, false, player, conf));
      return value;
    }
    else {
      var value = min(real);
      for col in findNeighbors(state) do
        value = min(value, _minimax(dropPiece(state, col, findNextPlayer(player), conf), depth - 1, true, player, conf));
      return value;
    }
  }

  proc countWindowsHorizontal(board, tile, windowSize: int) {
    const vertical = DLocal.dim[0];
    const horizontal = DLocal.dim[1];

    var result = 0;
    for i in vertical {
      var tilesInLine : int = 0;
      for j in horizontal {
          if board[i, j] == tile then
            tilesInLine += 1;
          else
            tilesInLine = 0;

        if tilesInLine == windowSize {
          tilesInLine = 0;
          result += 1;
        }
      }
    }
    return result;
  }

  proc countWindowsVertical(board, tile: Tile, windowSize: int) {
    const vertical = DLocal.dim[0];
    const horizontal = DLocal.dim[1];
    var result = 0;
    for i in horizontal {
      var tilesInLine : int = 0;
      for j in vertical {
          if board[j, i] == tile then
            tilesInLine += 1;
          else
            tilesInLine = 0;

        if tilesInLine == windowSize {
          tilesInLine = 0;
          result += 1;
        }
      }
    }
    return result;
  }

  proc moveAlong(in_at, delta : 2*int) {
    var at = in_at;
    var next = at;
    while DLocal.contains(next) {
      at = next;
      next = at + delta;
    }

    return at;
  }

  proc moveDiagonalLeft(at_in : 2*int, initial : 2*int) {
    const delta = (-1, -1);
    const at = at_in + initial;
    return moveAlong(at, delta);
  }

  proc countWindowsDiagonalLeftToRight (board, tile: Tile, windowSize: int) {
    var at = (DLocal.high[0] - 1, DLocal.low[1]);
    var result = 0;
    var tilesInLine = 0;
    while DLocal.contains(at) {
      if board[at] == tile then
        tilesInLine += 1;
      else
        tilesInLine = 0;
      
      if tilesInLine == windowSize {
        tilesInLine = 0;
        result += 1;
      }

      at += (1, 1);

      if at[1] >= DLocal.high[1] { // falling of the right edge
        at = moveDiagonalLeft(at, (-2, -1));
        tilesInLine = 0;
      } else if at[0] >= DLocal.high[0] { // falling of the bottom edge
        at = moveDiagonalLeft(at, (-1, 0));
        tilesInLine = 0;
      }
    }

    return result;
  }

  proc moveDiagonalRight(at_in : 2*int, initial : 2*int) {
    const delta = (-1, 1);
    const at = at_in + initial;
    return moveAlong(at, delta);
  }

  proc countWindowsDiagonalRightToLeft (board, tile: Tile, windowSize: int) {
    var at = (DLocal.high[0] - 1, DLocal.high[1] - 1);
    var result = 0;
    var tilesInLine = 0;
    while DLocal.contains(at) {
      if board[at] == tile then
        tilesInLine += 1;
      else
        tilesInLine = 0;
      
      if tilesInLine == windowSize {
        tilesInLine = 0;
        result += 1;
      }

      at += (1, -1);

      if at[1] < DLocal.low[1] { // falling off left edge
        at = moveDiagonalRight(at, (-2, 1));
        tilesInLine = 0;
      } else if at[0] >= DLocal.high[0] { // falling off bottom edge
        at = moveDiagonalRight(at, (-1, 0));
        tilesInLine = 0;
      }
    }

    return result;
  }

  proc countWindows(state : State, windowSize : int) {
    const board = state.board;
    const tile = placeTile(state.player);
    var result = 0;
    // horizontal
    result += countWindowsHorizontal(board, tile, windowSize);
    // vertical
    result += countWindowsVertical(board, tile, windowSize);
    // Diagonal Left to Right
    result += countWindowsDiagonalLeftToRight(board, tile, windowSize);
    // Diagonal Right to Left
    result += countWindowsDiagonalRightToLeft(board, tile, windowSize);
    return result;
  }

  proc heuristic(state : State) {
    const numThrees = countWindows(state, 3);
    const numFours = countWindows(state, 4);
    const opponent = findNextPlayer(state.player);
    const stateOpponent = new State(board=state.board, player=opponent);
    const numThreesOpponent = countWindows(stateOpponent, 3);
    const numFoursOpponent = countWindows(stateOpponent, 4);
    return numThrees - (100 * numThreesOpponent) - (10000 * numFoursOpponent) + (1000000 * numFours);
  }

  proc distance(a : State, b : State) {
    return 1:real;
  }
}
