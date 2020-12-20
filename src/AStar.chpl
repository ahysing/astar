/* Documentation for AStar */
module AStar {
  private use List;
  private use Sort;
  private use Map;
  private use ConnectFour;
  private use BlockDist;
  use Solution;

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

  public class Searcher {
    /* The type of the states contained in this EStar space. */
    type eltType;
    /* The distance, heuristic, findNeighbors, isGoalState functions */
    forwarding var impl : record;

    // ...AStar/src/AStar.chpl:32: error: Attempting to allocate > max(size_t) bytes of memory
    const startIdx : int(64) = 0;
    const end : int(64) = 1 << 42;
    const bbox = {startIdx..end};
    const ALL : domain(1) dmapped Block(boundingBox=bbox);
    var D : sparse subdomain(ALL);
    var fScore : [D] borrowed ScoredElement?;
    var gScore : [D] borrowed ScoredElement?;
    var allStates : [D] eltType?;
    
    /*
      Initializes an empty Searcher.
      :arg eltType: The type of the states
      :arg impl: the problem defined as a record. has distance, heuristic, findNeighbors, isGoalState functions
    */
    proc init(type eltType, impl : record) {
      this.eltType = eltType;
      this.impl = impl;
      this.complete();
      _checkType(eltType);
    }

    proc _checkType(type eltType) {
      if isGenericType(eltType) {
        compilerWarning("creating a AStar with element type " +
                        eltType:string);
        if isClassType(eltType) && !isGenericType(borrowed eltType) {
          compilerWarning("which now means class type with generic management");
        }
        compilerError("AStar element type cannot currently be generic");
      }
    }

    proc _isEmptySearchSpace(visited) {
        return visited.size == 0;
    }

    iter _backtrace(cameFrom, end) {
      var at = end;
      while cameFrom.contains(at) {
        const next = cameFrom.getValue(at);
        at = next;
        yield next;
      }
    }

    proc _reconstructPath(cameFrom, current) {
      var fullPath = new list(current.type);
      for current in _backtrace(cameFrom, current) do
        fullPath.append(current);
      return fullPath;
    }

    proc _getElementWithLowestFScore(visited) {
      var minFScore = new ScoredElement(elementAt=0, score=max(real));
      var lowestIdx = -1;
      for d in visited do
        if this.fScore[d].score < minFScore.score then
          minFScore = this.fScore[d];
      const lowest = this.allStates[minFScore.elementAt]!;
      return (lowestIdx, lowest);
    }

    /*
      A* search function.
    */
    proc search(start : this.eltType, g : real) : Solution {
      writeln("Searching...");
      this.fScore.clear();
      this.gScore.clear();
      this.allStates.clear();
      this.D.clear();
      var visited : subdomain(this.ALL);
      writeln("visited initialized...");

      var cameFrom = new map(this.eltType, this.eltType);
      writeln("cameFrom initialized...");
      const startIdx = this.ALL.low();
      D.add(startIdx);
      visited.add(startIdx);
      this.allStates[startIdx] = start;
      const f = impl.heuristic(start);
      fScore[startIdx] = new ScoredElement(elementAt=startIdx, score=f);
      gScore[startIdx] = new ScoredElement(elementAt=startIdx, score=g);
      
      // For node n, gScore[n] is the cost of the cheapest path from start to n currently known.
      
      // For node n, fScore[n] = gScore[n] + h(n). fScore[n] represents our current best guess as to
      // how short a path from start to finish can be if it goes through n.
      writeln("Search initialized");
      var it = startIdx;
      while ! _isEmptySearchSpace(visited) do {
        const (i, current) = _getElementWithLowestFScore(visited);
        visited.remove(i);
        if impl.isGoalState(current) then
          return new Solution(distance=gScore[it], path=reconstructPath(cameFrom, current));
        else {
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
            if isNewState || tentativeGScore < this.gScore[itNeighbor] {
              on cameFrom do
                // This path to neighbor is better than any previous one. Record it!
                cameFrom.set(neighbor, current);
              on visited do
                // if neighbor not in openSet then add it.
                if ! visited.contains(itNeighbor) then
                  visited.add(itNeighbor);
              on this.gScore[itNeighbor] {
                this.gScore[itNeighbor] = tentativeGScore;

                // heuristic(neighbor) is the heuristic distance from neighbor to finish
                const h = impl.heuristic(neighbor);

                // fScore[neighbor] is the heuristic distance from start to finish.
                // We know we hare passing through neighbor.
                const f = tentativeGScore + h;
                this.fScore[itNeighbor] = f;
                this.allStates[itNeighbor] = neighbor;
                accumulatedNeigbors.add(1);
              }
            }
          }

          it += accumulatedNeigbors.get();
        }
      }
      // Open set is empty but goal was never reached
      return new Solution(distance=0.0, path=new list(start.type));
    }
  }
}