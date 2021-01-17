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
  return && reduce (a.board == b.board);
}

inline proc <(a: GameContext, b: GameContext): bool {
  return (&& reduce (a.board < b.board));
}
