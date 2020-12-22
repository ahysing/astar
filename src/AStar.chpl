/* Documentation for AStar */
module AStar {
  private use List;
  private use LinkedLists;
  private use Sort;
  private use Map;
  private use ConnectFour;
  private use BlockDist;
  private use DistributedDeque;

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
    type eltType;
    const at : eltType;
    var next : owned NextStep(eltType)? = nil;
    
    proc init(type eltType, at : eltType) {
      this.eltType = eltType;
      this.at = at;
      this.next = nil;
    }
  }

  class SolutionFactory {
    type eltType;
    proc init(type eltType) {
      this.eltType = eltType;
    }

    proc create(start : this.eltType) {
      return new Solution(this.eltType, start);
    }
  }

  class Solution {
    type eltType = int;
    var distance : real;
    var cameFrom : owned NextStep(eltType)?;

    proc init() {
      this.eltType = object;
      this.distance = 0.0:real;
      this.cameFrom = nil;
    }

    proc init(type eltType, start : eltType) {
      this.eltType = eltType;
      this.distance = 0.0:real;
      var cameFrom = new owned NextStep(this.eltType, start);
      this.cameFrom = cameFrom;
    }
  }

  public class Searcher {
    /* The type of the states contained in this EStar space. */
    type eltType;
    /* The distance, heuristic, findNeighbors, isGoalState functions */
    forwarding var impl : record;
    const solutionFactory : SolutionFactory;
    // ...AStar/src/AStar.chpl:32: error: Attempting to allocate > max(size_t) bytes of memory
    param _low : int(64) = 0;
    param _high : int(64) = 1 << 42;
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

    proc _getElementWithLowestFScore(visited, fScore, allStatesFirst : DistDeque(this.eltType), allStatesSecond : DistDeque(this.eltType)) {
      var lowestIdx : visited.idxType;
      var lowestScore = max(real);
      var (_, lowestValue) : (bool, this.eltType) = allStatesFirst.pop();
      
      // TODO
      for d in visited do
        lowestIdx = d;
      return (lowestIdx, lowestValue);
    }

    proc _clearAllBuffers() {
      this.D.clear();
    }

    proc _insertUnique(ref solution : Solution(this.eltType), neighbor : this.eltType) {
    }

    /*
      A* sea rch function.
    */
    proc aStar(start : this.eltType, g : real) : Solution {
      writeln("Searching...");
      var allStatesFirst = new DistDeque(this.eltType, cap=(_high-_low));
      var allStatesSecond = new DistDeque(this.eltType, cap=(_high-_low));

      var solution = this.solutionFactory.create(start);
      _clearAllBuffers();

      var visited : domain(int(64));
      writeln("visited initialized...");
      const startIdx = this.ALL.low;
      this.D.add(startIdx);
      visited.add(startIdx);

      var fScore : [this.D] real;
      var gScore : [this.D] real;

      const f = impl.heuristic(start);
      fScore[startIdx] = f;
      gScore[startIdx] = g;
      
      // For node n, gScore[n] is the cost of the cheapest path from start to n currently known.
      
      // For node n, fScore[n] = gScore[n] + h(n). fScore[n] represents our current best guess as to
      // how short a path from start to finish can be if it goes through n.
      writeln("Search initialized");
      var it = startIdx;
      while ! _isEmptySearchSpace(visited) do {
        const (i, current) = _getElementWithLowestFScore(visited, fScore, allStatesFirst, allStatesSecond);
        visited.remove(i);
        if impl.isGoalState(current) {
          solution.distance = gScore[it];
          return solution;
        } else {
            // tentativeGScore is the distance from start to the neighbor through current
          var accumulatedNeigbors : atomic int;
          for neighbor in impl.findNeighbors(current) do {
            const j = accumulatedNeigbors.fetchAdd(1) + 1;
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
              }
            }
          }

          const step = accumulatedNeigbors.fetchAdd(0:int(64));
          it += step;
        }
      }
      // Open set is empty but goal was never reached
      return solution;
    }
  }
}