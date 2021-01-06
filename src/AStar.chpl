/* Documentation for AStar */
module AStar {
  use LinkedLists;
  private use ReplicatedVar;
  private use CyclicDist;
  private use DistributedBag;
  private use PeekPoke;
  private use Search;

  type idxT = int(64);

  public class Searcher {
    type eltType;
    const impl : record;
    param _high : idxT = 1 << 8;
    param _low : idxT = 0;
    param startIdx = _low;
      
    /*
      Initializes an empty Searcher.
      :arg eltType: The type of states for the A* algorithm search space.
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

    iter _pickScoresAndStateOnLocale(const ref openSet : DistBag(idxT), const ref fScores, loc : locale) {
      for idx in openSet.these() do
        if fScores[idx].locale.id == loc.id then
          yield (fScores[idx], idx);
    }

    proc _getIndexWithLowestFScore(const ref openSet : DistBag(idxT), fScores, loc : locale) {
      const indicesThenFScores = _pickScoresAndStateOnLocale(openSet, fScores, loc);
      for value in indicesThenFScores {
        const (fScore, idxCurrent) = minloc reduce indicesThenFScores;
        return (true, idxCurrent);
      }
      const defaultIdx : idxT;
      return (false, defaultIdx);
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

    proc _aquireNewLastIndex(ref size : atomic idxT, inObservedSize : idxT) {
      var observedSize = inObservedSize;
      var foundOrAquired : bool;
      do {
        const next = observedSize + 1;
        foundOrAquired = size.compareAndSwap(observedSize, next);
        observedSize = size.read();
      } while ! foundOrAquired;
      const lastIdx = observedSize - 1;
      return lastIdx;  
    }

    proc _aquireIdxToNewNeigbor(ref size : atomic idxT, const ref allStates : [?Dom] this.eltType, neighbor : this.eltType) {
      // Currently, unless using network atomics, all remote atomic operations will result in the calling task effectively migrating to the locale on which the atomic variable was allocated and performing the atomic operations locally.
      // https://chapel-lang.org/docs/technotes/atomics.html
      var foundOrAquired : bool;
      var idxNeighbor, observedSize, lastObservedIdx : idxT;
      const initialSize = size.read();
      const initialLastIdx = initialSize - 1;
      (foundOrAquired, idxNeighbor) = _reverseLinearSearch(allStates, neighbor, hi = initialLastIdx);
      if foundOrAquired {
        return idxNeighbor;
      } else {
        const lastIdx = _aquireNewLastIndex(size, initialSize);
        (foundOrAquired, idxNeighbor) = search(allStates, neighbor, lo = initialLastIdx, hi = lastIdx, sorted = false);
        if foundOrAquired then
          return idxNeighbor;
        else
          return lastIdx;
      }
    }

    proc _aggregateIsGoalStateAcrossNodes(hasFinished : [rcDomain] bool) {
      var hasReachedGoalAcrossAllLocales : [LocaleSpace] bool;
      rcCollect(hasFinished, hasReachedGoalAcrossAllLocales);
      return (|| reduce hasReachedGoalAcrossAllLocales);
    }

    proc _aggregateLowestStepAndDistanceAcrossNodes(distanceAndNextStep : [rcDomain] (real, idxT)) {
      var gScoresAndNextPathsAcrossAllLocales : [LocaleSpace] (real, idxT);
      rcCollect(distanceAndNextStep, gScoresAndNextPathsAcrossAllLocales);
      var lowestDistance = max(real);
      var lowestIndex = min(idxT);
      for (distance, nextStepIndex) in gScoresAndNextPathsAcrossAllLocales {
        if distance < lowestDistance {
          lowestDistance = distance;
          lowestIndex = nextStepIndex;
        }
      }
      return (lowestDistance, lowestIndex);
    }

    proc _aggregateNextStepAcrossNodes(distanceAndNextStep : [rcDomain] (real, idxT), const ref allStates : [?Dom] this.eltType) {
      const (gScore, nextStepIdx) = _aggregateLowestStepAndDistanceAcrossNodes(distanceAndNextStep);
      return allStates[nextStepIdx];
    }

    proc _aggregateLowestDistanceAcrossNodes(distanceAndNextStep : [rcDomain] (real, idxT)) {
      const (gScore, nextStepIdx) = _aggregateLowestStepAndDistanceAcrossNodes(distanceAndNextStep);
      return gScore;
    }

    proc _fillHasFinished(hasFinished : [rcDomain] bool) {
      rcReplicate(hasFinished, false); 
    }
    
    proc _fillDistanceAndNextStep(distanceAndNextStep : [rcDomain] (real, idxT)) {
      const defaultForType : idxT;
      rcReplicate(distanceAndNextStep, (max(real), defaultForType));
    }

    proc _flagFinish(hasFinished : [rcDomain] bool, distanceAndNextStep : [rcDomain] (real, idxT), gScores, idxCurrent : idxT) {
      rcLocal(hasFinished) = true;
      rcLocal(distanceAndNextStep)[0] = gScores[idxCurrent];
      rcLocal(distanceAndNextStep)[1] = idxCurrent;
    }

    proc _findNextStepByLowestDistance(lowestNextSteps : DistBag((real, idxT))) {
      var lowestDistance = max(real);
      var lowestStepFinal : idxT;
      for (tentativeGScore, at) in lowestNextSteps.these() do
        if tentativeGScore < lowestDistance then
          (lowestDistance, lowestStepFinal) = (tentativeGScore, at);
      return (lowestDistance, lowestStepFinal);          
    }

    proc _createBag(loc : locale) {
      const myLocaleSpace : domain(1) = {0..1};
      const myLocales: [myLocaleSpace] locale = loc;
      return new DistBag((real, idxT), targetLocales = myLocales);
    }

    proc _createAllStates(ALL, ref defaultForType : this.eltType) {
      if isClass(this.eltType) {
        var allStates : [ALL] this.eltType = defaultForType;
        return allStates;
      } else {
        var allStates : [ALL] this.eltType;
        return allStates;
      }
    }

     /*
      A* search algorithm (pronounced "A-star search algorithm").
      :arg start: The starting position, or state, in the A* algorithm search space.
      :type start: `eltType`
      :arg distanceToStart: The initial distance traveled to `start`. Usually zero. If some distance was spent before getting to `start`, then this value would be greater than zero.
      :type distanceToStart: `real`
      :returns: A tuple indicating (1) the distance traveled from start to goal and (2) an ordered list of states traveled through from start to goal.
      :rtype: (`real`, `LinkedList(eltType)`)
    */
    proc aStar(ref start : this.eltType, ref defaultForType : this.eltType, distanceToStart : real) : (real, LinkedList(this.eltType)) {      
      const bboxScores = {_low.._high};
      const ALL : domain(1) dmapped Cyclic(startIdx=bboxScores.low) = bboxScores;
      // For node n, gScore[n] is the cost of the cheapest path from start to n currently known.
      // For node n, fScore[n] = gScore[n] + h(n). fScore[n] represents our current best guess as to
      // how short a path from start to finish can be if it goes through n.
      var fScores : [ALL] real;
      var gScores : [ALL] real = max(real);
      var size : atomic idxT = 1;
      fScores[startIdx] = impl.heuristic(start);
      gScores[startIdx] = distanceToStart;
      // allStates contains all the neighbors observed. The array is unordered.
      // New values are added at the end according to the current value of `size`.
      var allStates = _createAllStates(ALL, defaultForType);
      allStates[startIdx] = start;
      // openSet contains indices to the states we are currently exploring. These indices can look up in
      // `fScores`, `gScores` and `allStates`.
      var openSet = new DistBag(idxT);
      openSet.add(startIdx);
      // The states we traveled to to get to the end. States are ordered from start to goal state.
      var path : LinkedList(this.eltType);
      path = makeList(start);
      // hasFinished contains a flag indicating if any of the .ocales has found any finishing state
      var hasFinished : [rcDomain] bool;
      _fillHasFinished(hasFinished);
      // distanceAndNextStep contains the smallest distance traveled to the best state explored on the locale
      // during the current iteration
      var distanceAndNextStep : [rcDomain] (real, idxT);     
      
      
      
      while ! _isEmptySearchSpace(openSet) do {
        _fillDistanceAndNextStep(distanceAndNextStep);
        for loc in Locales {
          on loc {
            const (hasValueInThisLocale, idxCurrent) = _getIndexWithLowestFScore(openSet, fScores, loc);
            if hasValueInThisLocale {
              _removeStateFromOpenSet(openSet, gScores, idxCurrent);

              const current = allStates[idxCurrent];
              if impl.isGoalState(current) then
                _flagFinish(hasFinished, distanceAndNextStep, gScores, idxCurrent);
              else {
                var lowestNextSteps = _createBag(loc);
                coforall neighbor in impl.findNeighbors(current) do {
                  const idxNeighbor = _aquireIdxToNewNeigbor(size, allStates, neighbor);
                  const tentativeGScore = gScores[idxCurrent] + impl.distance(current, neighbor);
                  on gScores[idxNeighbor] {
                    allStates[idxNeighbor] = neighbor;
                    // heuristic(neighbor) is the heuristic distance from neighbor to finish
                    // fScore[neighbor] is the heuristic distance from start to finish.
                    // We know we hare passing through neighbor.
                    fScores[idxNeighbor] = tentativeGScore + impl.heuristic(neighbor);
                    if tentativeGScore < gScores[idxNeighbor] then
                      gScores[idxNeighbor] = tentativeGScore;                   
                  }

                  if ! openSet.contains(idxNeighbor) then
                    openSet.add(idxNeighbor);

                  lowestNextSteps.add((tentativeGScore, idxNeighbor));
                }
                const (lowestDistance, lowestStepFinal) = _findNextStepByLowestDistance(lowestNextSteps);
                rcLocal(distanceAndNextStep)[0] = lowestDistance;
                rcLocal(distanceAndNextStep)[1] = lowestStepFinal;
              }
            }
          }
        }

        if _aggregateIsGoalStateAcrossNodes(hasFinished) then
          return (_aggregateLowestDistanceAcrossNodes(distanceAndNextStep), path);        
        path.append(_aggregateNextStepAcrossNodes(distanceAndNextStep, allStates));
        openSet.balance();
      }

      return (distanceToStart, path);
    }
  }


  private use ConnectFour;
  private use GameContext;
  private use Player;
  private use Tile;
  proc main() {
    writeln("Started");
    writeln("This program is running on ", numLocales, " locales");
    const connectFour = new ConnectFour(5);
    const board : [BoardDom] Tile;
    var gameContext = new shared GameContext(board, player=Player.Red);
    var defaultGameContext = new shared GameContext();
    var p = makeList(gameContext);
    param g = 0.0;
    var searcher = new Searcher(gameContext.type, connectFour);
    var solution = searcher.aStar(gameContext, defaultGameContext, g);
  
    writeln("distance", solution[0]);
    for state in solution[1] do
      writeln("State", state);
    writeln("Finished");
  }
}