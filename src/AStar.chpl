/* Documentation for AStar */
module AStar {
  use LinkedLists;
  private use BlockDist;
  private use DistributedBag;
  private use Search;
  private use PeekPoke;

  type idxT = int(64);

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

    proc _pickScoresAndState(idx : idxT, fScores) {
      return (fScores[idx], idx);
    }

    proc _getElementWithLowestFScore(visited : DistBag(idxT), fScores, allStates) {
      const indicesThenFScores = _pickScoresAndState(visited.these(), fScores);
      const (_, idx) = minloc reduce indicesThenFScores;
      const element = allStates[idx];
      return (idx, element);
    }

    proc _removePreviousPathPushBack(ref path : LinkedList(this.eltType), neighbor : this.eltType) {
      while path.contains(neighbor) do
        path.remove(neighbor);
      path.push_back(neighbor);
    }
 
    proc _createSolution(distanceToStart : real, start : this.eltType) {
      var path : LinkedList(this.eltType) = makeList(start);
      return (distanceToStart, path);
    }

    proc _remove(ref visited : DistBag(idxT), value : idxT) {
      var next = new DistBag(idxT);
      var ok = true;
      var element : idxT;
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
      const _low : idxT = 0;
      const _high : idxT = 1 << 24;
      const startIdx = _low;
      const bboxScores = {_low.._high};
      const ALL : domain(1) dmapped Block(boundingBox=bboxScores) = bboxScores;

      var fScores : [ALL] real;
      var gScores : [ALL] real = max(real);
      var size : atomic idxT = 1;
      // For node n, gScore[n] is the cost of the cheapest path from start to n currently known.
      
      // For node n, fScore[n] = gScore[n] + h(n). fScore[n] represents our current best guess as to
      // how short a path from start to finish can be if it goes through n.
      fScores[startIdx] = impl.heuristic(start);
      gScores[startIdx] = distanceToStart;

      var allStates : [ALL] this.eltType;
      var visited = new DistBag(idxT);
      visited.add(startIdx);

      var path : LinkedList(this.eltType) = makeList(start);
      
      while ! _isEmptySearchSpace(visited) do {
        const (idx, current) = _getElementWithLowestFScore(visited, fScores, allStates);
        if impl.isGoalState(current) then
          return (gScores[idx], path);
        else {
          visited = _remove(visited, idx);
          var allNebours = new LinkedList(this.eltType);
          for neighbor in  impl.findNeighbors(current) do
            allNebours.push_back(neighbor);
          for neighbor in allNebours do {
            const tentativeGScore = gScores[idx] + impl.distance(current, neighbor);
            const (foundNeighbor, idxNeighbor) = search(allStates, neighbor, sorted = false);
            if ! foundNeighbor {
              const nextIdx = size.peek();

              gScores[nextIdx] = tentativeGScore;
              // heuristic(neighbor) is the heuristic distance from neighbor to finish
              // fScore[neighbor] is the heuristic distance from start to finish.
              // We know we hare passing through neighbor.
              on  fScores[nextIdx] do
                fScores[nextIdx] = tentativeGScore + impl.heuristic(neighbor);
           
              visited.add(nextIdx);
              size.add(1);
              // This path to neighbor is better than any previous one. Record it!
              path.push_back(neighbor);
            } else if tentativeGScore < gScores[idxNeighbor] {
              gScores[idxNeighbor] = tentativeGScore;
              // heuristic(neighbor) is the heuristic distance from neighbor to finish
              // fScore[neighbor] is the heuristic distance from start to finish.
              // We know we hare passing through neighbor.
              on  fScores[idxNeighbor] do
                fScores[idxNeighbor] = tentativeGScore + impl.heuristic(neighbor);

              if ! visited.contains(idxNeighbor) {
                visited.add(idxNeighbor);
                size.add(1);
              }
              // This path to neighbor is better than any previous one. Record it!
              _removePreviousPathPushBack(path, neighbor);
            }
          }
        }
      }
      return _createSolution(distanceToStart, start);
    }
  }
}