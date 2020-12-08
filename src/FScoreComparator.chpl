record FScoreComparator {
  var fScore;
  proc init(fScore) {
    this.fScore = fScore;
  }
}

proc FScoreComparator.key(i) {
  var D = this.fScore.domain;
  if D.contains(i) then
    return this.fScore[i];
  else
    return max(real);
}
