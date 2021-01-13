use AStar only Searcher;
use GameContext;
use LinkedLists;
use List;
use Player;
use Tile;

record ConnectFour {
  var depth: int;
  proc init(depth) {
    this.depth = depth;
  }

  proc init=(other: ConnectFour) {
    this.depth = other.depth;
  }

  proc isGoalState(context: GameContext) {
    var isGoal: atomic bool = false;
    cobegin {
      {
        var nextState = new GameContext(board=context.board, player=Player.Red);
        if countWindows(nextState, 4) then
          isGoal.testAndSet();
      }
      {
        var nextState = new GameContext(board=context.board, player=Player.Yellow);
        if countWindows(nextState, 4) then
          isGoal.testAndSet();
      }
    }

    return isGoal.read();
  }

  proc findNextPlayer(player: Player): Player {
    if player == Player.Red then
      return Player.Yellow;
    if player == Player.Yellow then
      return Player.Red;
    else
      return Player.Red;
  }

  proc placeTile(player: Player): Tile {
    if player == Player.Red then
      return Tile.Red;
    if player == Player.Yellow then
      return Tile.Yellow;
    else
      return Tile.Red;
  }

  proc _createNextState(context: GameContext, placeAt: 2*int): GameContext {
    var nextBoard = context.board;
    nextBoard[placeAt] = placeTile(context.player);
    const nextPlayer = findNextPlayer(context.player);
    const nextState = new shared GameContext(player=nextPlayer, board=nextBoard);
    return nextState;
  }

  iter const findNeighbors(context: GameContext) {
    const vertical = context.board.domain.dim[0];
    const horizontal = context.board.domain.dim[1];
    var values = new LinkedList(shared GameContext);
    var hasAny = false;
    for i in vertical {
      for j in horizontal {
        if context.board[i, j] != Tile.Unset && context.board.domain.contains((i - 1, j)) {
          values.append(_createNextState(context, (i - 1, j)));
          hasAny = true;
          writeln("Adding ", (i - 1, j));
          break;
        }
      }
    }

    if ! hasAny {
      for j in horizontal {
        values.append(_createNextState(context, (context.board.domain.low[0], j)));
        writeln("Adding initial ", (context.board.domain.low[0], j));
      }
    }

    for value in values.these() do
      yield value;
  }

  proc _minimax(context: GameContext, depth: int, maximizingPlayer: bool, player: Player, conf): real {
    if depth == 0 || isGoalState(context) then
      return heuristic(context);
    else if maximizingPlayer {
      var value = min(real);
      for col in findNeighbors(context) do
        value = max(value, _minimax(dropPiece(conf, col, player, conf), depth - 1, false, player, conf));
      return value;
    }
    else {
      var value = min(real);
      for col in findNeighbors(context) do
        value = min(value, _minimax(dropPiece(context, col, findNextPlayer(player), conf), depth - 1, true, player, conf));
      return value;
    }
  }

  proc countWindowsHorizontal(board, tile: Tile, windowSize: int) {
    const vertical = board.domain.dim[0];
    const horizontal = board.domain.dim[1];

    var result = 0;
    for i in vertical {
      var tilesInLine: int = 0;
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
    const vertical = board.domain.dim[0];
    const horizontal = board.domain.dim[1];
    var result = 0;
    for i in horizontal {
      var tilesInLine: int = 0;
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

  proc moveAlong(currentDomain, in_at: 2*int, delta: 2*int) {
    var at = in_at;
    var next = at;
    while currentDomain.contains(next) {
      at = next;
      next = at + delta;
    }

    return at;
  }

  proc moveDiagonalLeft(currentDomain, at_in: 2*int, initial: 2*int) {
    const delta = (-1, -1);
    const at = at_in + initial;
    return moveAlong(currentDomain, at, delta);
  }

  proc countWindowsDiagonalLeftToRight (board, tile: Tile, windowSize: int) {
    var at = (board.domain.high[0] - 1, board.domain.low[1]);
    var result = 0;
    var tilesInLine = 0;
    while board.domain.contains(at) {
      if board[at] == tile then
        tilesInLine += 1;
      else
        tilesInLine = 0;
      
      if tilesInLine == windowSize {
        tilesInLine = 0;
        result += 1;
      }

      at += (1, 1);

      if at[1] >= board.domain.high[1] { // falling of the right edge
        at = moveDiagonalLeft(board.domain, at, (-2, -1));
        tilesInLine = 0;
      } else if at[0] >= board.domain.high[0] { // falling of the bottom edge
        at = moveDiagonalLeft(board.domain, at, (-1, 0));
        tilesInLine = 0;
      }
    }

    return result;
  }

  proc moveDiagonalRight(currentDomain, at_in: 2*int, initial: 2*int) {
    const delta = (-1, 1);
    const at = at_in + initial;
    return moveAlong(currentDomain, at, delta);
  }

  proc countWindowsDiagonalRightToLeft (board, tile: Tile, windowSize: int) {
    var at = (board.domain.high[0] - 1, board.domain.high[1] - 1);
    var result = 0;
    var tilesInLine = 0;
    while board.domain.contains(at) {
      if board[at] == tile then
        tilesInLine += 1;
      else
        tilesInLine = 0;
      
      if tilesInLine == windowSize {
        tilesInLine = 0;
        result += 1;
      }

      at += (1, -1);

      if at[1] < board.domain.low[1] { // falling off left edge
        at = moveDiagonalRight(board.domain, at, (-2, 1));
        tilesInLine = 0;
      } else if at[0] >= board.domain.high[0] { // falling off bottom edge
        at = moveDiagonalRight(board.domain, at, (-1, 0));
        tilesInLine = 0;
      }
    }

    return result;
  }

  proc countWindows(context: GameContext, windowSize: int) {
    const board = context.board;
    const playersTurn = context.player;
    const tile = placeTile(playersTurn);
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

  proc heuristic(context: GameContext): real {
    const numThrees = countWindows(context, 3);
    const numFours = countWindows(context, 4);
    const opponentP = findNextPlayer(context.player);
    const opponent = new GameContext(board=context.board, player=opponentP);
    const numThreesOpponent = countWindows(opponent, 3);
    const numFoursOpponent = countWindows(opponent, 4);
    return max(-numThrees + (100 * numThreesOpponent) + (10000 * numFoursOpponent) - (1000000 * numFours), 0.0): real;
  }

  proc distance(a: GameContext, b: GameContext) {
    var distance = 0;
    for idx in a.board.domain do
      if a.board[idx] != b.board[idx] then
        distance += 1;
    return distance:real;
  }
}
