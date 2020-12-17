use State only State, Tile;

record StateMapper {
  proc demap(i : int(64)) : State {
    var state = new State();
    var byte = i;
    const lowCol = state.board.domain.low(0);
    const highCol = state.board.domain.high(0);
    var columnLengths : [lowCol..highCol] int(8);
    const numColumns = highCol - lowCol;
    for i in lowCol..highCol {
      columnLengths[i] = byte & 7;
      byte /= 8;
    }

    for j in lowCol..highCol {
      for h in 0..columnLength[j] {
        if byte & 1 == 1 then
          state.board[i, j] = Tile.Red;
        byte /= 2;
      }
    }

    return state;
  }

  proc map(state : State) : int(64) {
    var byte: int = 0;  
    var columnLengths : [0..6] int(8);
    for d in state.board.domain do
      if state.board[d] != Tile.Unset then
        columnLengths[d[0]] += 1;

    for d in state.board.domain {
      const tile = state.board[d];
      if tile == Tile.Red then
        byte = (byte * 2) + 1;
      else if tile == Tile.Yellow then
        byte = (byte * 2) + 0;
    }

    for columnLength in columnLengths do
      byte = (byte | columnLength) * 8;

    return byte;
  }
}
