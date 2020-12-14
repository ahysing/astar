/* Documentation for AStar */
module AStar {
  private use List;
  private use HashedDist;
  private use Heap;
  private use Map;
  private use ConnectFour;
  private use FScoreComparator;
  
  enum Visit {
    Unexplored,
    Open,
    Closed
  }

  class Solution {
    var distance : real;
    var path : list;
  }

  public class Searcher {
    /* The type of the states contained in this EStar space. */
    type eltType;
    
    /* The distance, heuristic, findNeighbors, isGoalState functions */
    forwarding var impl : record;
    /*
      Initializes an empty Searcher.
      :arg eltType: The type of the states
      :arg impl: the problem defined as a record. has distance, heuristic, findNeighbors, isGoalState functions
    */
    proc init(type eltType, impl : record) {
      this.eltType = eltType;
      this.impl = impl;
      this.complete();
    }

    pragma "no doc"
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

    proc isEmptySearchSpace(openSet) {
      return openSet.isEmpty();
    }

    iter _backtrace(cameFrom, end) {
      var at = end;
      while cameFrom.contains(at) {
        const next = cameFrom.getValue(at);
        at = next;
        yield next;
      }
    }

    proc reconstructPath(cameFrom, current) {
      var fullPath = new list(current.type);
      for current in _backtrace(cameFrom, current) do
        fullPath.append(current);
      return fullPath;
    }

    proc _nextWithLowestFScore(openSet : heap) {
      var next = openSet.top();
      return next;
    }
    /*
      A* search function.
    */
    proc search(start : record, f : real, g : real) : Solution {
      writeln("Searching...");
      const D: domain(this.eltType) dmapped Hashed(idxType=this.eltType);
      writeln("D initialized...");
      var fScore : [D] real; // TODO: Fix this line.
      fScore[start] = f;
      writeln("fScore initialized...");
      var gScore : [D] real;
      gScore[start] = g;
      writeln("gScore initialized...");
      var openSet = new heap(start.type, parSafe=true, comparator=new FScoreComparator(fScore=fScore));
      openSet.push(start);
      writeln("openSet initialized...");
      var cameFrom = new map(start.type, start.type);
      writeln("cameFrom initialized...");
      // For node n, gScore[n] is the cost of the cheapest path from start to n currently known.
      
      // For node n, fScore[n] = gScore[n] + h(n). fScore[n] represents our current best guess as to
      // how short a path from start to finish can be if it goes through n.
      writeln("Search initialized");
      while ! isEmptySearchSpace(openSet) do {
        // This operation can occur in O(1) time if openSet is a min-heap or a priority queue
        const current : State = _nextWithLowestFScore(openSet);
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
              fScore[neighbor] = gScore[neighbor] + impl.heuristic(neighbor);
              // This path to neighbor is better than any previous one. Record it!
              cameFrom.set(neighbor, current);
              
              // if neighbor not in openSet then add it.
              for n in openSet.consume() do
                if n == neighbor then
                  break;
              openSet.push(neighbor);
            }
          }
        }
      }
      // Open set is empty but goal was never reached
      return new Solution(distance=0.0, path=new list(start.type));
    }
  }
  
  proc main() {
    writeln("Started");
    writeln("This program is running on ", numLocales, " locales");
    const connectFour = new ConnectFour(5);
    const startState = new State();
    var searcher = new Searcher(startState.type, connectFour);
    const f = 0.0;
    const g = 0.0;    
    var solution = searcher.search(startState, f, g);
    writeln("distance", solution.distance);
    for state in solution.path do
      writeln("Player", state.player);
    writeln("Finished");
  }
}
