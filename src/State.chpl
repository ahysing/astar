use Tile;

const numRows: int = 6;
const numColumns: int = 7;
const StateDom: domain(2) = {0..(numRows - 1), 0..(numColumns - 1)};

record State {
  var board: [StateDom] Tile;

  proc init() { }

  proc init(board: [StateDom] Tile) {
    this.board = board;
  }
}

// this reverts compiler saying
// internal error: UTI-MIS-0788 chpl version 1.23.0
proc ==(l: State, r: State) {
  return && reduce (l.board == r.board);
}