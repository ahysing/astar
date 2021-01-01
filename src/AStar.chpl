/* Documentation for AStar */
module AStar {
  use LinkedLists;
  private use CyclicDist;
  private use DistributedBag;
  private use PeekPoke;
  type idxT = int(64);

  public class Searcher {
    /* The type of the states contained in this EStar space. */
    type eltType;
    const impl : record;
    const _high : idxT = 1 << 8;
      
      
    /*
      Initializes an empty Searcher.
      :arg eltType: The type of the states
      :arg impl: the problem defined as a record. has distance, heuristic, findNeighbors, isGoalState functions
    */
    proc init(type eltType, impl : record) {
      this.eltType = eltType;
      this.impl = impl;
    }

    proc _isEmptySearchSpace(const ref openSet) {
      // DistBag.getSize()  Obtain the number of elements held in all bags across all nodes.
      if openSet.getSize() != 0 {
        var (hasAny, value) = openSet.remove();
        if hasAny then
          openSet.add(value);
        return hasAny == false;
      }
      return true;
    }

    proc _pickScoresAndState(idx : idxT, const ref fScores) {
      return (fScores[idx], idx);
    }

    proc _getElementWithLowestFScore(const ref openSet : DistBag(idxT), fScores, allStates) {
      const indicesThenFScores = _pickScoresAndState(openSet.these(), fScores);
      const (_, idx) = minloc reduce indicesThenFScores;
      const element = allStates[idx];
      return (idx, element);
    }

    proc _pushBackWithLowestGScore(ref path : LinkedList(this.eltType), nextPotentialPaths : domain((real, this.eltType))) {
      if nextPotentialPaths.size != 0 {
        var nextPath : this.eltType;
        var minGScore = max(real);
        for (potensialGScore, potensialPath) in nextPotentialPaths {
          if potensialGScore <= minGScore {
            minGScore = potensialGScore;
            nextPath = potensialPath;
          }
        }
        
        while path.contains(nextPath) do
          path.remove(nextPath);
        path.push_back(nextPath);
      }
    }
 
    proc _createSolution(distanceToStart : real, start : this.eltType) {
      var solutionPath : LinkedList(this.eltType) = makeList(start);
      return (distanceToStart, solutionPath);
    }

    proc _remove(ref openSet : DistBag(idxT), stateIdx : idxT) {
      var next = new DistBag(idxT);
      var ok = true;
      var element : idxT;
      do {
        (ok, element) = openSet.remove();
        if element != stateIdx then
          next.add(element);
        else
          break;
      } while ok;
      
      do {
        (ok, element) = next.remove();
        openSet.add(element);
      } while ok;
    }

    proc _removeStateFromOpenSet(ref openSet : DistBag(idxT), gScores, stateIdx : idxT) {
      // Remove the stateIdx from the open set. Open set holds the states we are exploring.
      _remove(openSet, stateIdx);
      // mark index at negative infinity. gScores for this index will never pass the less than condition in A-star algorithm.
      gScores[stateIdx] = min(real); 
    }
    
    proc _reverseLinearSearch(const ref allStates : [?Dom] this.eltType, lookingFor : this.eltType, hi : idxT) {
      for i in 0..hi by -1 do
        if allStates[i] == lookingFor then
          return (true, i);
      return (false, hi + 1);
    }

    /*
      A* search algorithm ( pronounced "A-star search algorithm").
    */
    proc aStar(start : this.eltType, distanceToStart : real) : (real, LinkedList(this.eltType)) {      
      param _low : idxT = 0;
      const startIdx = _low;
      const bboxScores = {_low.._high};
      const ALL : domain(1) dmapped Cyclic(startIdx=bboxScores.low) = bboxScores;

      var fScores : [ALL] real;
      var gScores : [ALL] real = max(real);
      var size : atomic idxT = 1;
      // For node n, gScore[n] is the cost of the cheapest path from start to n currently known.
      
      // For node n, fScore[n] = gScore[n] + h(n). fScore[n] represents our current best guess as to
      // how short a path from start to finish can be if it goes through n.
      fScores[startIdx] = impl.heuristic(start);
      gScores[startIdx] = distanceToStart;

      var allStates : [ALL] this.eltType;
      var openSet = new DistBag(idxT);
      openSet.add(startIdx);

      var path : LinkedList(this.eltType) = makeList(start);
            
      while ! _isEmptySearchSpace(openSet) do {
        const (idx, current) = _getElementWithLowestFScore(openSet, fScores, allStates);
        if impl.isGoalState(current) then
          return (gScores[idx], path);
        else {
          _removeStateFromOpenSet(openSet, gScores, idx);
          
          var nextPotentialPaths : domain((real, this.eltType));
          const stateSizeNow = size.peek();
          assert(ALL.contains(stateSizeNow));
          coforall neighbor in impl.findNeighbors(current) do {
            const (foundNeighbor, idxNeighbor) = _reverseLinearSearch(allStates, neighbor, hi = stateSizeNow - 1);
            if foundNeighbor {
              on gScores[idxNeighbor] {
                const tentativeGScore = gScores[idx] + impl.distance(current, neighbor);
                if tentativeGScore < gScores[idxNeighbor] {
                  gScores[idxNeighbor] = tentativeGScore;
                  // heuristic(neighbor) is the heuristic distance from neighbor to finish
                  // fScore[neighbor] is the heuristic distance from start to finish.
                  // We know we hare passing through neighbor.
                  fScores[idxNeighbor] = tentativeGScore + impl.heuristic(neighbor);

                  nextPotentialPaths.add((tentativeGScore, neighbor));
                  if ! openSet.contains(idxNeighbor) {
                    openSet.add(idxNeighbor);
                  }
                }
              }
            } else if ! foundNeighbor {
              const nextIdx = stateSizeNow;
              on gScores[nextIdx] {
                const tentativeGScore = gScores[idx] + impl.distance(current, neighbor);

                gScores[nextIdx] = tentativeGScore;
                // heuristic(neighbor) is the heuristic distance from neighbor to finish
                // fScore[neighbor] is the heuristic distance from start to finish.
                // We know we hare passing through neighbor.
                fScores[nextIdx] = tentativeGScore + impl.heuristic(neighbor);
            
                nextPotentialPaths.add((tentativeGScore, neighbor));
                openSet.add(nextIdx);
                size.add(1);
              }
            }
          }
          // This path to neighbor is better than any previous one. Record it!
          _pushBackWithLowestGScore(path, nextPotentialPaths);
          if stateSizeNow % 3 == 0 then
            openSet.balance();
        }
      }

      return (distanceToStart, path);
    }
  }
}