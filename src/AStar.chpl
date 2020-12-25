/* Documentation for AStar */
module AStar {
  use LinkedLists;
  private use BlockDist;
  private use DistributedBag;

  class FScoreScanOp : ReduceScanOp {
    type eltType;
    var value : eltType;
    proc identity         return ((0:int(64),0:int(64)), max(real));
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
      return allStates.getSize() == 0;
    }

    proc _pickScoresAndState(idx : 2*int(64), fScores) {
      return (idx, fScores[idx[0]]);
    }

    proc _getElementWithLowestFScore(ref visited : DistBag(2*int(64)), ref fScores, ref allStates) {
      const indicesStatesFScores = _pickScoresAndState(visited.these(), fScores);
      const current = FScoreScanOp reduce indicesStatesFScores;
      const idx = current[0];
      const element = allStates[idx[1]];
      return (idx, element);
    }

    proc _insertUnique(ref path : LinkedList(this.eltType), neighbor : this.eltType) {
      path.remove(neighbor);
      while path.contains(neighbor) do
        path.remove(neighbor);
      path.push_back(neighbor);
    }
  
    proc _createSolution(distanceToStart : real, start : this.eltType) {
      var path = new LinkedList(this.eltType);
      path.push_front(start);
      return (distanceToStart, path);
    }

    proc _remove(visited : DistBag(2*int(64)), value : 2*int(64)) {
      var next = new DistBag(2*int(64));
      var (ok, element) = visited.remove();
      while ok {
        if element != value then
          next.add(element);    
        const (n_ok, n_element) = visited.remove();
        ok = n_ok;
        element = n_element;
      }

      return next;
    }

    proc _isNeighbor(i : int(64), allStates, neighbor : this.eltType) {
      if allStates[i] == neighbor then
        return i;
      else
        return max(i.type);
    }

      /*
        A* search function.
      */
    proc aStar(start : this.eltType, distanceToStart : real) : (real, LinkedList(this.eltType)) {      
      writeln("visited initialized...");
      const _low : int(64) = 0;
      const _high : int(64) = 1 << 24;
    
      const startIdx = _low;
      const bbox = {_low.._high};

      const ALL : domain(1) dmapped Block(boundingBox=bbox) = bbox;

      var fScores : [ALL] real;
      var gScores : [ALL] real = max(real);
      var size : int(64) = 1;
      // For node n, gScore[n] is the cost of the cheapest path from start to n currently known.
      
      // For node n, fScore[n] = gScore[n] + h(n). fScore[n] represents our current best guess as to
      // how short a path from start to finish can be if it goes through n.
      fScores[startIdx] = impl.heuristic(start);
      gScores[startIdx] = distanceToStart;

      var allStates : [ALL] this.eltType;
      var visited = new DistBag(2*int(64));
      visited.add((0, 0));

      var path = new LinkedList(this.eltType);
      path.push_front(start);
      
      while ! _isEmptySearchSpace(visited) do {
        const (idx, current) = _getElementWithLowestFScore(visited, fScores, allStates);
        visited = _remove(visited, idx);
        if impl.isGoalState(current) then
          return (gScores[idx[0]], path);
        else {
          for neighbor in impl.findNeighbors(current) do {
            const tentativeGScore = gScores[idx[0]] + impl.distance(current, neighbor);
            var idxNeighbor = (& reduce _isNeighbor(startIdx..size, allStates, neighbor));
            var added = idxNeighbor >= size || tentativeGScore < gScores[idxNeighbor];
            if idxNeighbor >= size {
              idxNeighbor = size;
              size += 1;
              visited.add((idxNeighbor, idxNeighbor));
              path.push_back(neighbor);
            } else if tentativeGScore < gScores[idxNeighbor] {
              // This path to neighbor is better than any previous one. Record it!
              _insertUnique(path, neighbor);
              if ! visited.contains((idxNeighbor, idxNeighbor)) then
                visited.add((idxNeighbor, idxNeighbor));
              //path.push_back(neighbor);
            }

            if added {
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