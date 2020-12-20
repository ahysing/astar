use Tile;

const numRows : int = 6;
const numColumns : int = 7;
const DLocal : domain(2) = {0..numRows, 0..numColumns};

public enum Tile {
  Unset,
  Red,
  Yellow
}

record State {
  var board : [DLocal] Tile;

  proc init() { }

  proc init(board : [DLocal] Tile) {
    this.board = board;
  }
}

// this reverts compiler saying
// internal error: UTI-MIS-0788 chpl version 1.23.0
proc ==(l: State, r: State) {
  return && reduce (l.board == r.board);
}