/* Documentation for AStar */
module AStar {
  private use List;
  private use Sort;
  private use Map;
  private use ConnectFour;
  private use FScoreComparator;
  private use BlockDist;
  use Visit;
  use Solution;

  public class Searcher {
    /* The type of the states contained in this EStar space. */
    type eltType;
    /* The distance, heuristic, findNeighbors, isGoalState functions */
    var fScore;
    var gScore;
    var mapper;
    forwarding var impl : record;
    var D;
    /*
      Initializes an empty Searcher.
      :arg eltType: The type of the states
      :arg impl: the problem defined as a record. has distance, heuristic, findNeighbors, isGoalState functions
    */
    proc init(type eltType, mapper : ?t, impl : record) {
      this.eltType = eltType;
      var D : domain(1) dmapped Block(boundingBox={min(int(64))..max(int(64))}, rank=1);
      var fScore : [D] real = max(real);
      var gScore : [D] real = max(real);
      this.fScore = fScore;
      this.gScore = gScore;
      this.mapper = mapper;
      this.impl = impl;
      this.D = D;
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

    proc _isEmptySearchSpace(openSetSize) {
      return openSetSize == 0;
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

    /*
      A* search function.
    */
    proc search(start, f : real, g : real) : Solution {
      writeln("Searching...");
      const startIdx = this.mapper.map(start);
      writeln("Added start to domain...");
      
      var openSet : [this.D] real;
      writeln("openSet initialized...");
      openSet[startIdx] = f;
      var openSetSize = 1;

      var cameFrom = new map(this.eltType, this.eltType);
      writeln("cameFrom initialized...");
      
      fScore[startIdx] = f;
      gScore[startIdx] = g;
      // For node n, gScore[n] is the cost of the cheapest path from start to n currently known.
      
      // For node n, fScore[n] = gScore[n] + h(n). fScore[n] represents our current best guess as to
      // how short a path from start to finish can be if it goes through n.
      writeln("Search initialized");
      while ! _isEmptySearchSpace(openSetSize) do {
        // This operation can occur in O(1) time if openSet is a min-heap or a priority queue
        var current : this.eltType;
        for n in openSet.domain do
          current = this.mapper.demap(n);
          break;
        openSetSize -= 1;

        if impl.isGoalState(current) then
          return new Solution(distance=gScore[current], path=reconstructPath(cameFrom, current));
        else {
            // d(current,neighbor) is the weight of the edge from current to neighbor
            // tentative_gScore is the distance from start to the neighbor through current
          for neighbor in impl.findNeighbors(current) do {
            const d = impl.distance(current, neighbor);
            const tentative_gScore = gScore[current] + d;
            if tentative_gScore < gScore[neighbor] {
              gScore[neighbor] = tentative_gScore;
              const f = gScore[neighbor] + impl.heuristic(neighbor);
              fScore[neighbor] = f;
              // This path to neighbor is better than any previous one. Record it!
              cameFrom.set(neighbor, current);
              
              // if neighbor not in openSet then add it.
              if ! this.D.contains(neighbor) then
                this.D.add(neighbor);
              openSet[neighbor] = f;
              sort(openSet);
              openSetSize += 1;
            }
          }
        }
      }
      // Open set is empty but goal was never reached
      return new Solution(distance=0.0, path=new list(start.type));
    }
  }
}