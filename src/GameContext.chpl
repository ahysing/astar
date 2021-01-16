use Player;
use Tile;

const numRows: int = 6;
const numColumns: int = 7;
const BoardDom: domain(2) = {0..(numRows - 1), 0..(numColumns - 1)};

class GameContext {
  var board: [BoardDom] Tile;
  var player: Player;
  proc init() {
    this.player = Player.Yellow;
  }

  proc init(board: [BoardDom] Tile, player: Player) {
    this.board = board;
    this.player = player;
  }
}

inline proc ==(a: GameContext, b: GameContext): bool {
  return (&& reduce (a.board == b.board)) && a.player == b.player;
}

inline proc <(a: GameContext, b: GameContext): bool {
  if (&& reduce (a.board == b.board)) then
    if a.player == Player.Red && b.player != Player.Red then
      return true;
    else if a.player != Player.Red && b.player == Player.Red then
      return false;
    else
      return false;
  else
    return (&& reduce (a.board < b.board));
}