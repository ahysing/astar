use List;
use AStar only Searcher, Visit;
use Player;
use Tile;

const numRows : int = 6;
const numColumns : int = 7;
const DLocal : domain(2) = {0..numColumns, 0..numRows};

record State {
  var player : Player;
  var board : [DLocal] Tile;

  proc init() {
  }

  proc init(player : Player, board) {
    this.player = player;
    this.board = board;
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
    
    const board = state.board;
    const vertical = DLocal.dim[0];
    const horizontal = DLocal.dim[1];
    const lowH = DLocal.low[1];
    const highH = DLocal.high[1];

    // vertical
    forall i in vertical {
      var numberOfRed : int;
      var numberOfYellow : int;
      for j in horizontal do
        if board[i, j] == Tile.Red then
          numberOfRed += 1;
        else if board[i, j] == Tile.Yellow then
          numberOfYellow += 1;
      
      if numberOfYellow >= 4 || numberOfRed >= 4 then
        isGoal.testAndSet();
    }

    // vertical
    forall i in horizontal {
      var numberOfRed : int;
      var numberOfYellow : int;
      for j in vertical do
        if board[i, j] == Tile.Red then
          numberOfRed += 1;
        else if board[i, j] == Tile.Yellow then
          numberOfYellow += 1;

      if numberOfYellow >= 4 || numberOfRed >= 4 then
        isGoal.testAndSet();
    }

    
    // diagonal left to right
    forall i in vertical {
      var numberOfRed : int;
      var numberOfYellow : int;
      for j in lowH..(highH - 4) do
        if board[i, j + i] == Tile.Red then
          numberOfRed += 1;
        else if board[i, j + i] == Tile.Yellow then
          numberOfYellow += 1;
      
      if numberOfYellow >= 4 || numberOfRed >= 4 then
        isGoal.testAndSet();
    }

    // diagonal right to left
    forall i in vertical {
      var numberOfRed : int;
      var numberOfYellow : int;
      for j in (lowH + 4)..highH do
        if board[i, j - i] == Tile.Red then
          numberOfRed += 1;
        else if board[i, j - i] == Tile.Yellow then
          numberOfYellow += 1;
      
      if numberOfYellow >= 4 || numberOfRed >= 4 then
        isGoal.testAndSet();
    }

    return isGoal.read();
  }

  proc _minimax(state : State, depth : int, maximizingPlayer : bool, player : Player, conf) : real {
    var validMoves = new list(State);
    if depth == 0 || isGoalState(state) then
      return heuristic(state);
    else if maximizingPlayer {
      var value = min(real);
      for col in validMoves {
        var child = dropPiece(state, col, player, conf);
        value = max(value, _minimax(child, depth - 1, false, player, conf));
      }

      return value;
    }
    else {
      var value = min(real);
      for col in validMoves {
        var child = dropPiece(state, col, findNextPlayer(player), conf);
        value = min(value, _minimax(child, depth - 1, true, player, conf));
      }

      return value;
    }
  }

  proc countWindows(state : State, numRows : int) {
    const board = state.board;
    const tile = placeTile(state.player);
    const vertical = DLocal.dim[0];
    const horizontal = DLocal.dim[1];
    var result = 0;
    // vertical
    for i in vertical {
      var numberOf : int = 0;
      for j in horizontal {
        if board[i, j] == tile then
          numberOf += 1;
          
        if numberOf == numRows {
          numberOf = 0;
          result += 1;
        }
      }
    }

    for i in horizontal {
      var numberOf : int = 0;
      for j in vertical {
        if board[j, i] == tile then
          numberOf += 1;

        if numberOf == numRows {
          numberOf = 0;
          result += 1;
        }
      }
    }


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
      if state.board[i, j] == Tile.Unset && i == 0 then
        yield createNextState(state, (i, j));
      else if state.board[i, j] == Tile.Unset && state.board[i - 1, j] != Tile.Unset then
        yield createNextState(state, (i, j));
  }
}
