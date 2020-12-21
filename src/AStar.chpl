/* Documentation for AStar */
module AStar {
  private use List;
  private use LinkedLists;
  private use Sort;
  private use Map;
  private use ConnectFour;
  private use BlockDist;

  class ScoredElement {
    var elementAt : int(64);
    var score : real;

    proc init() {
    }

    proc init(elementAt : int(64), score : real) {
      this.elementAt = elementAt;
      this.score = score;
    }
  }

  class MinScoredElement: ReduceScanOp {
    var  value: ScoredElement;
    proc identity return new ScoredElement(elementAt=0, score=max(real));
    proc accumulate(elm)  { 
      if elm.score < value.score then
        value = elm;
    }
    proc accumulateOntoState(ref state, elm) { 
      if state.score < value.score then
        value = elm;
    }
    proc combine(other) { 
      if other.score < value.score then
        value = other;
    }
    proc generate() return value;
    proc clone() return new unmanaged MinScoredElement();
  }

  class NextStep {
    var at;
    var next : owned NextStep?;
    proc init() {
      this.at = nil;
      this.next = nil;
    }
  }

  class SolutionFactory {
    type eltType;
    proc init(type eltType) {
      this.eltType = eltType;
    }

    proc create(start : this.eltType) {
      var cameFrom  = new NextStep();
      cameFrom.at = start;
      return new Solution(this.eltType, cameFrom);
    }
  }

  class Solution {
    type eltType;
    var distance : real;
    var cameFrom : NextStep;

    proc init(type eltType, cameFrom) {
      this.eltType = eltType;
      this.distance = 0.0:real;
      this.cameFrom = cameFrom;
    }
  }

  public class Searcher {
    /* The type of the states contained in this EStar space. */
    type eltType;
    /* The distance, heuristic, findNeighbors, isGoalState functions */
    forwarding var impl : record;
    var solutionFactory : SolutionFactory;
    // ...AStar/src/AStar.chpl:32: error: Attempting to allocate > max(size_t) bytes of memory
    const _low : int(64) = 0;
    const _high : int(64) = 1 << 42;
    const bbox = {_low.._high};
    const ALL : domain(1) dmapped Block(boundingBox=bbox);
    var D : sparse subdomain(ALL);
    /*
      Initializes an empty Searcher.
      :arg eltType: The type of the states
      :arg impl: the problem defined as a record. has distance, heuristic, findNeighbors, isGoalState functions
    */
    proc init(type eltType, impl : record) {
      this.eltType = eltType;
      this.impl = impl;
      this.solutionFactory = new SolutionFactory(this.eltType);
      this.complete();
    }

    proc _isEmptySearchSpace(visited) {
        return visited.size == 0;
    }

    proc _getElementWithLowestFScore(visited, allStates) {
      var lowestIdx = visited.low;
      var lowestScore = max(real);
      for d in visited do
        if fScore[d] < lowestScore then
          lowestIdx = d;
      return (lowestIdx, allStates[lowestIdx]);
    }

    proc _clearAllBuffers() {
      this.D.clear();
    }

    proc _insertUnique(ref solution : Solution(this.eltType), neighbor : this.eltType) {
    }

    /*
      A* sea rch function.
    */
    proc aStar(start : borrowed this.eltType, g : real) : Solution {
      writeln("Searching...");
      var solution = this.solutionFactory.create(start);
      _clearAllBuffers();

      var visited : subdomain(this.ALL);
      writeln("visited initialized...");
      var cameFromIt = 0;
      solution.cameFrom.add(cameFromIt);
      solution.cameFrom[cameFromIt] = start;
      writeln("cameFrom initialized...");
      const startIdx = this.ALL.low();
      D.add(startIdx);
      visited.add(startIdx);

      var allStates : [this.D] this.eltType?;
      var fScore : [this.D] real;
      var gScore : [this.D] real;

      allStates[startIdx] = start;
      const f = impl.heuristic(start);
      fScore[startIdx] = f;
      gScore[startIdx] = g;
      
      // For node n, gScore[n] is the cost of the cheapest path from start to n currently known.
      
      // For node n, fScore[n] = gScore[n] + h(n). fScore[n] represents our current best guess as to
      // how short a path from start to finish can be if it goes through n.
      writeln("Search initialized");
      var it = startIdx;
      while ! _isEmptySearchSpace(visited) do {
        const (i, current) = _getElementWithLowestFScore(visited);
        visited.remove(i);
        if impl.isGoalState(current) {
          solution.distance = gScore[it];
          return solution;
        } else {
            // tentativeGScore is the distance from start to the neighbor through current
          const numNeighbors = impl.numberOfNeighborsNext();
          var accumulatedNeigbors : atomic int;
          for (j, neighbor) in zip(impl.findNeighbors(current), 0..numNeighbors) do {
            const d = impl.distance(current, neighbor);
            const tentativeGScore = gScore[it] + d;
            const itNeighbor = it + j;
            const isNewState = ! this.D.contains(itNeighbor);
            if isNewState then
              this.D.add(itNeighbor);
            if isNewState || tentativeGScore < gScore[itNeighbor] {
                // This path to neighbor is better than any previous one. Record it!
              _insertUnique(solution, neighbor);
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
                allStates[itNeighbor] = neighbor;
                accumulatedNeigbors.add(1);
              }
            }
          }

          it += accumulatedNeigbors.get();
        }
      }
      // Open set is empty but goal was never reached
      return new Solution(distance=0.0, path=nil);
    }
  }
}