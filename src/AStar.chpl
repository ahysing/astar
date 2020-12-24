/* Documentation for AStar */
module AStar {
  use LinkedLists;
  private use BlockDist;
  use DistributedDeque;
  use DistributedBag;

  record _Noop {
  }

  class MinFScore: ReduceScanOp {
    var eltType;
    var value: (2*int(64), record, real) = ((0,0), new _Noop(), max(real));
    proc identity         return ((0,0), new _Noop(), max(real));
    proc accumulate(elm)  {
      // value = value + elm;
      if elm[2] < value[2] then
        value = elm;
    }
    proc accumulateOntoState(ref state, elm) {
      // state = state + elm;
      if elm[2] < state[2] then
        state = elm;
    }
    proc combine(other) {
      // value = value + other.value;
      if other[2] < other[2] then
        other = other;
    }
    proc generate()       return value;
    proc clone()          return new unmanaged MinFScore();
  }

  public class Searcher {
    /* The type of the states contained in this EStar space. */
    type eltType;
    var impl : record;
    // ...AStar/src/AStar.chpl:32: error: Attempting to allocate > max(size_t) bytes of memory
    const allStatesFirst;

    /*
      Initializes an empty Searcher.
      :arg eltType: The type of the states
      :arg impl: the problem defined as a record. has distance, heuristic, findNeighbors, isGoalState functions
    */
    proc init(type eltType, impl : record) {
      this.eltType = eltType;
      this.impl = impl;
      this.allStatesFirst = new DistBag(this.eltType);

    }

    proc _isEmptySearchSpace(allStates) {
      return allStates.getSize() == 0;
    }

    proc _pickScoresAndState(idx : 2*int(64), fScore, allStates) {
      return (idx, allStates[idx[1]], fScore[idx[0]]);
    }

    proc _getElementWithLowestFScore(ref visited : DistBag(2*int(64)), ref fScores, ref allStates) {
      var indicesStatesFScores = _pickScoresAndState(visited.these(), fScores, allStates);
      var current = ((0,0), new _Noop(), max(real)); // (MinFScore() reduce indicesStatesFScores);
      forall indicesStateFScore in indicesStatesFScores do
        if indicesStateFScore[2] > current[2] then
          current = indicesStateFScore;
      return (current[0], current[1]);
    }

    proc _insertUnique(solution, neighbor : this.eltType) {
    }
  
    proc createSolution(start : this.eltType, distanceToStart : real) {
      var path = new LinkedList(this.eltType);
      path.push_front(start);
      return (distanceToStart, path);
    }
      /*
        A* sea rch function.
      */
    proc aStar(start : this.eltType, distanceToStart : real) : (real, LinkedList(this.eltType)) {
      var solution = createSolution(start, distanceToStart);
      
      writeln("visited initialized...");
      const _low : int(64) = 0;
      const _high : int(64) = 1 << 42;
    
      const startIdx = _low;
      const bbox = {_low.._high};

      const ALL : domain(1) dmapped Block(boundingBox=bbox) = bbox;

      var fScores : [ALL] real;
      var gScores : [ALL] real;
      var size : int(64) = 1;
      const f = impl.heuristic(start);
      // For node n, gScore[n] is the cost of the cheapest path from start to n currently known.
      
      // For node n, fScore[n] = gScore[n] + h(n). fScore[n] represents our current best guess as to
      // how short a path from start to finish can be if it goes through n.
      fScores[startIdx] = f;
      gScores[startIdx] = distanceToStart;

      var allStates : [ALL] this.eltType;
      var visited = new DistBag(2*int(64));
      visited.add((0, 0));
      while ! _isEmptySearchSpace(visited) do {
        const (idx, current) = _getElementWithLowestFScore(visited, fScores, allStates);
        visited.remove(idx);
        if impl.isGoalState(current) then
          return (gScore[idx[0]], 0.0);
        else {
          for neighbor in impl.findNeighbors(current) do {
            const d = impl.distance(current, neighbor);
            const tentativeGScore = gScore[idx[0]] + d;
            var itNeighbor : atomic int(64) = size;
            forall i in startIdx..size do
              if allStates[i] == neighbor then
                itNeighbor = allStates;
            if itNeighbor == size then
              size += 1;
            if tentativeGScore < gScore[itNeighbor] {
              // This path to neighbor is better than any previous one. Record it!
              //_insertUnique(distance, neighbor);
              if ! visited.contains((itNeighbor, itNeighbor)) then
                visited.add((itNeighbor, itNeighbor));
              on gScore[itNeighbor] {
                gScore[itNeighbor] = tentativeGScore;
                // heuristic(neighbor) is the heuristic distance from neighbor to finish
                const h = impl.heuristic(neighbor);

                // fScore[neighbor] is the heuristic distance from start to finish.
                // We know we hare passing through neighbor.
                const f = tentativeGScore + h;
                fScore[itNeighbor] = f;
              }
            }
          }
        }
        /*
        if impl.isGoalState(current) {
          var idxG = idx[2];
          distance = gScore[idxG];
          return (distance, path);
        } else {
            // tentativeGScore is the distance from start to the neighbor through current
          var accumulatedNeigbors : int;
          for neighbor in impl.findNeighbors(current) do {
            accumulatedNeigbors += 1;
            const j = accumulatedNeigbors;
            const d = impl.distance(current, neighbor);
            const tentativeGScore = gScore[it] + d;
            const itNeighbor = it + j;
            const isNewState = ! this.D.contains(itNeighbor);
            if isNewState then
              this.D.add(itNeighbor);
            if isNewState || tentativeGScore < gScore[itNeighbor] {
                // This path to neighbor is better than any previous one. Record it!
              //_insertUnique(distance, neighbor);
              on visited do
                // if neighbor not in openSet then add it.
                if ! visited.contains(itNeighbor) then
                  visited.add(itNeighbor);
              on gScore[itNeighbor] {
                gScore[itNeighbor] = tentativeGScore;

                // heuristic(neighbor) is the heuristic distance from neighbor to finish
                const h = impl.heuristic(neighbor);

                // fScore[neighbor] is the heuristic distance from start to finish.
                // We know we hare passing through neighbor.
                const f = tentativeGScore + h;
                fScore[itNeighbor] = f;
              }
            }
          }
          it += accumulatedNeigbors;
        }

          */
      }


      
      return solution;
    }
  }
}