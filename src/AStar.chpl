/* Documentation for AStar */
module AStar {
  use LinkedLists;
  private use BlockDist;
  private use DistributedBag;
  private use Search;
  private use PeekPoke;

  type scoreIdxT = int(64);
  type stateIdxT = int(64);

  class FScoreScanOp : ReduceScanOp {
    type eltType;
    var value : eltType;
    proc identity         return ((0:scoreIdxT,0:stateIdxT), max(real));
    proc accumulateOntoState(ref state, x: eltType) {
      if x[1] < state[1] then
        state = x;
      else
        state = state;
    }
    proc accumulate(elm)  {
      accumulateOntoState(value, elm);
    }
    proc combine(other : FScoreScanOp(eltType=eltType)) {
      accumulateOntoState(value, other.value);
    }
    proc generate()       return value;
    proc clone()          return new unmanaged FScoreScanOp(eltType=eltType);
  }

  public class Searcher {
    /* The type of the states contained in this EStar space. */
    type eltType;
    var impl : record;

    /*
      Initializes an empty Searcher.
      :arg eltType: The type of the states
      :arg impl: the problem defined as a record. has distance, heuristic, findNeighbors, isGoalState functions
    */
    proc init(type eltType, impl : record) {
      this.eltType = eltType;
      this.impl = impl;
    }

    proc _isEmptySearchSpace(allStates) {
      for value in allStates.these() do
        return false;
      return true;
    }

    proc _pickScoresAndState(idx : (scoreIdxT, stateIdxT), fScores) {
      return (idx, fScores[idx[0]]);
    }

    proc _getElementWithLowestFScore(visited : DistBag((scoreIdxT, stateIdxT)), fScores, allStates) {
      const indicesThenFScores = _pickScoresAndState(visited.these(), fScores);
      const current = FScoreScanOp reduce indicesThenFScores;
      const idx = current[0];
      const element = allStates[idx[1]];
      return (idx, element);
    }

    proc _removePreviousPushBack(ref path : LinkedList(this.eltType), neighbor : this.eltType) {
      while path.contains(neighbor) do
        path.remove(neighbor);
      path.push_back(neighbor);
    }
 
    proc _createSolution(distanceToStart : real, start : this.eltType) {
      var path : LinkedList(this.eltType) = makeList(start);
      return (distanceToStart, path);
    }

    proc _remove(ref visited : DistBag((scoreIdxT, stateIdxT)), value : (scoreIdxT, stateIdxT)) {
      var next = new DistBag((scoreIdxT, stateIdxT));
      var ok = true;
      var element : (scoreIdxT, stateIdxT);
      do {
        (ok, element) = visited.remove();
        if element != value then
          next.add(element);    
      } while ok;
      
      return next;
    }

      /*
        A* search function.
      */
    proc aStar(start : this.eltType, distanceToStart : real) : (real, LinkedList(this.eltType)) {      
      const _low : scoreIdxT = 0;
      const _high : scoreIdxT = 1 << 24;
    
      const startIdx = _low;
      const bbox = {_low.._high};

      const ALL : domain(1) dmapped Block(boundingBox=bbox) = bbox;

      const _lowState : stateIdxT = 0;
      const _highState : stateIdxT = 1 << 24;
      const bboxStates = {_lowState.._highState};
      const ALL_STATES : domain(1) dmapped Block(boundingBox=bboxStates) = bboxStates;

      var fScores : [ALL] real;
      var gScores : [ALL] real = max(real);
      var size : atomic stateIdxT = 1;
      // For node n, gScore[n] is the cost of the cheapest path from start to n currently known.
      
      // For node n, fScore[n] = gScore[n] + h(n). fScore[n] represents our current best guess as to
      // how short a path from start to finish can be if it goes through n.
      fScores[startIdx] = impl.heuristic(start);
      gScores[startIdx] = distanceToStart;

      var allStates : [ALL_STATES] this.eltType;
      var visited = new DistBag((scoreIdxT, stateIdxT));
      visited.add((0, 0));

      var path : LinkedList(this.eltType) = makeList(start);
      
      while ! _isEmptySearchSpace(visited) do {
        const (idx, current) = _getElementWithLowestFScore(visited, fScores, allStates);
        visited = _remove(visited, idx);
        if impl.isGoalState(current) then
          return (gScores[idx[0]], path);
        else {
          for neighbor in impl.findNeighbors(current) do {
            const tentativeGScore = gScores[idx[0]] + impl.distance(current, neighbor);
            var (foundNeighbor, idxNeighbor) = search(allStates, neighbor, sorted = false);
            if ! foundNeighbor {
              idxNeighbor = size.peek();
              size.add(1);
              
              visited.add((idxNeighbor, idxNeighbor));
              // This path to neighbor is better than any previous one. Record it!
              path.push_back(neighbor);
            } else if tentativeGScore < gScores[idxNeighbor] {
              if ! visited.contains((idxNeighbor, idxNeighbor)) then
                visited.add((idxNeighbor, idxNeighbor));
              // This path to neighbor is better than any previous one. Record it!
              _removePreviousPushBack(path, neighbor);
            }

            if foundNeighbor || tentativeGScore < gScores[idxNeighbor] {
              on gScores[idxNeighbor] do
                gScores[idxNeighbor] = tentativeGScore;
              // heuristic(neighbor) is the heuristic distance from neighbor to finish
              // fScore[neighbor] is the heuristic distance from start to finish.
              // We know we hare passing through neighbor.
              on  fScores[idxNeighbor] do
                fScores[idxNeighbor] = tentativeGScore + impl.heuristic(neighbor);
            }
          }
        }
      }
      return _createSolution(distanceToStart, start);
    }
  }
}