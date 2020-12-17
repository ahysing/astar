use Player;
private use State only DLocal, Tile;

record GameContext {
  var board : [DLocal] Tile;
  var player : Player;
  proc init() { }

  proc init(board : [DLocal] Tile, player : Player) {
    this.board = board;
    this.player = player;
  }
}