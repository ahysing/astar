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
    var fScore;
    var gScore;
    var allStates;
    var mapper;
    forwarding var impl : record;

    /*
      Initializes an empty Searcher.
      :arg eltType: The type of the states
      :arg impl: the problem defined as a record. has distance, heuristic, findNeighbors, isGoalState functions
    */
    proc init(type eltType, mapper : ?t, impl : record) {
      this.eltType = eltType;
      // ...AStar/src/AStar.chpl:32: error: Attempting to allocate > max(size_t) bytes of memory
      var start : int(64) = 0;
      var end : int(64) = 1 << 42;
      const bbox = {start..end};
      const ALL : domain(1) dmapped Block(boundingBox=bbox);
      var D : sparse subdomain(ALL);
      
      var fScore : [D] borrowed ScoredElement?;
      
      var gScore : [D] borrowed ScoredElement?;
      
      var allStates : [D] this.eltType?;
      
      this.fScore = fScore;
      this.gScore = gScore;
      this.allStates = allStates;
      this.mapper = mapper;
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

    iter equalsNeigbor(all, neighbor) {
      for n in all do
        yield n == neighbor;
    }

    proc containsNeighbor(all, neighbor) {
      return (|| reduce equalsNeigbor(all, neighbor));
    }

    proc _getElementWithLowestFScore(visited) : this.eltType {
      const minFScore = (MinScoredElement reduce this.fScore);
      return this.allStates[minFScore.elementAt]!;
    }
    /*
      A* search function.
    */
    proc search(start : this.eltType, g : real) : Solution {
      writeln("Searching...");
      const startIdx = this.mapper.map(start);
      writeln("Added start to domain...");
      
      var visited : subdomain(this.fScore.domain);
      var openSet : [visited] borrowed this.eltType;
      
      writeln("openSet initialized...");
      openSet[startIdx] = start;

      var cameFrom = new map(this.eltType, this.eltType);
      writeln("cameFrom initialized...");
      const f = impl.heuristic(start);
      fScore[startIdx] = new ScoredElement(elementAt=startIdx, score=f);
      gScore[startIdx] = new ScoredElement(elementAt=startIdx, score=g);
      // For node n, gScore[n] is the cost of the cheapest path from start to n currently known.
      
      // For node n, fScore[n] = gScore[n] + h(n). fScore[n] represents our current best guess as to
      // how short a path from start to finish can be if it goes through n.
      writeln("Search initialized");
      var it = 0;
      visited.add(this.mapper.map(start));
      while ! _isEmptySearchSpace(visited) do {
        // This operation can occur in O(1) time if openSet is a min-heap or a priority queue
        const current : this.eltType = _getElementWithLowestFScore(visited);
        if impl.isGoalState(current) then
          return new Solution(distance=gScore[startIdx], path=reconstructPath(cameFrom, current));
        else {
          visited.remove(current);
            // tentativeGScore is the distance from start to the neighbor through current
          for neighbor in impl.findNeighbors(current) do {
            const d = impl.distance(current, neighbor);
            const tentativeGScore = gScore[it] + d;
            if tentativeGScore < gScore[it] {
              gScore[it] = tentativeGScore;

              // heuristic(neighbor) is the heuristic distance from neighbor to finish
              const h = impl.heuristic(neighbor);

              // fScore[neighbor] is the heuristic distance from start to finish.
              // We know we hare passing through neighbor.
              const f = gScore[it] + h;
              const itNeighbor = it + this.mapper.map(neighbor);
              fScore[itNeighbor] = f;

              // This path to neighbor is better than any previous one. Record it!
              cameFrom.set(neighbor, current);
              
              // if neighbor not in openSet then add it.
              if ! visited.contains(neighbor) then
                visited.add(neighbor);
              openSet[it] = f;
            }

            it += 1;
          }
        }
      }
      // Open set is empty but goal was never reached
      return new Solution(distance=0.0, path=new list(start.type));
    }
  }
}