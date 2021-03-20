/* Documentation for AStar */
module AStar {
  private use AllLocalesBarriers;
  private use CyclicDist;
  private use DistributedBag;
  private use PeekPoke;
  private use ReplicatedVar;
  private use Search;
  private use IO.FormattedIO;
  private use Time;
  use LinkedLists;

  config const debug = false;
  config const progress = false;

  type idxT = int(64);
  const visitedStateGScore = min(real);

  public class Searcher {
    type eltType;
    const impl: record;
    param _high: idxT = 1 << 30;
    param _low: idxT = 0;
    param startIdx = _low;
    /*
      Initializes an empty Searcher.
      :arg eltType: The type of states for the A* algorithm search space.
      :arg impl: the problem defined as a record. has distance, heuristic, findNeighbors, isGoalState functions
    */
    proc init(type eltType, impl: record) {
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

    iter const _pickScoresAndStateOnLocale(const ref openSet: DistBag(idxT), const ref fScores, loc: locale) {
      for idx in openSet.these() do
        if fScores[idx].locale.id == loc.id then
          yield (fScores[idx], idx);
    }

    proc _getIndexWithLowestFScore(const ref openSet: DistBag(idxT), fScores, loc: locale) {
      const indicesThenFScores = _pickScoresAndStateOnLocale(openSet, fScores, loc);
      for value in indicesThenFScores do
        return (true, (minloc reduce indicesThenFScores)[1]);
      const defaultIdx: idxT;
      return (false, defaultIdx);
    }

    proc _removeStateFromOpenSet(ref openSet: DistBag(idxT), stateIdx: idxT) {
      // Remove the stateIdx from the open set. Open set holds the states we are exploring.
      var next = new DistBag(idxT);
      var ok = true;
      var element: idxT;
      do {
        (ok, element) = openSet.remove();
        if ok && element != stateIdx then
          next.add(element);
        else if ok then
          break;
      } while ok;
      
      (ok, element) = next.remove();
      while ok {
        openSet.add(element);
        (ok, element) = next.remove();
      }
    }
    
    proc _indexNotFound() {
      return (false, min(idxT));
    }
    
    proc _isUnvisitedState(gScores, i) {
      return gScores[i] != visitedStateGScore;
    }
    
    proc _getTopIndex(allStates, hi) {
      var high = allStates.domain.high;
      if hi < high then
        high = hi;
      return high;
    }

    proc _reverseSearchForOpenState(const ref allStates: [?DomA] this.eltType,
                                    allStatesLock$,
                                    const ref gScores,
                                    lookingFor: this.eltType,
                                    hi: idxT) {
      const low = allStates.domain.low;
      const high = _getTopIndex(allStates, hi);
      allStatesLock$.readFE();
      for i in low..high by -1 {
        assert(gScores.domain.contains(i));
        assert(allStates.domain.contains(i));
        if _isUnvisitedState(gScores, i) && allStates[i] == lookingFor {
          allStatesLock$.writeXF(true);
          return (true, i);
        }
      }
      allStatesLock$.writeXF(true);
      return _indexNotFound();
    }

    proc _aquireNewLastIndex(ref size: atomic idxT, inObservedSize: idxT) {
      var observedSize = inObservedSize;
      var foundOrAquired: bool;
      do {
        const next = observedSize + 1;
        foundOrAquired = size.compareAndSwap(observedSize, next);
        observedSize = size.read();
      } while ! foundOrAquired;
      const lastIdx = observedSize - 1;
      return lastIdx;  
    }

    proc _aquireIdxToNewNeigbor(const ref allStates: [?DomA] this.eltType,
                                ref allStatesLock$,
                                const ref gScores,
                                neighbor: this.eltType,
                                sizeFromLastStage: idxT,
                                size: atomic idxT) {
      // Currently, unless using network atomics, all remote atomic operations will result in the calling task effectively migrating to the locale on which the atomic variable was allocated and performing the atomic operations locally.
      // https://chapel-lang.org/docs/technotes/atomics.html
      const (foundOrAquired, idxNeighbor) = _reverseSearchForOpenState(allStates, allStatesLock$, gScores, neighbor, hi = sizeFromLastStage);
      if foundOrAquired {
        if debug then
          writeln("index ", idxNeighbor, " state exists already");
        return idxNeighbor;
      } else {
        const initialSize = size.read();
        const lastIdx = _aquireNewLastIndex(size, initialSize);
        if debug then
          writeln("index ", lastIdx, " created new");
        return lastIdx;
      }
    }

    proc _IsGoalStateAcrossNodes(hasFinished: [rcDomain] bool) {
      var hasReachedGoalAcrossAllLocales: [LocaleSpace] bool;
      rcCollect(hasFinished, hasReachedGoalAcrossAllLocales);
      return (|| reduce hasReachedGoalAcrossAllLocales);
    }


    proc _aggregateLowestStepAndDistanceAcrossNodes(lowestDistances: [rcDomain] real, lowestNextSteps: [rcDomain] idxT) {
      var gScoresAcrossAllNodes: [LocaleSpace] real;
      rcCollect(lowestDistances, gScoresAcrossAllNodes);
      var indicesAcrossAllNodes: [LocaleSpace] idxT;
      rcCollect(lowestNextSteps, indicesAcrossAllNodes);
      // writeln("gScoresAndIndexAcrossAllLocales ", gScoresAcrossAllNodes, " ", indicesAcrossAllNodes);
      var lowestDistance = max(real);
      var lowestNextStep = min(idxT);
      for (distance, nextStepIndex) in zip(gScoresAcrossAllNodes, indicesAcrossAllNodes) {
        if distance <= lowestDistance {
          lowestDistance = distance;
          lowestNextStep = nextStepIndex;
        }
      }
      return (lowestDistance, lowestNextStep);
    }

    proc _aggregateNextStepAcrossNodes(lowestDistances: [rcDomain] real, lowestNextSteps: [rcDomain] idxT, const ref allStates: [?DomA] this.eltType) {
      const (gScore, nextStepIdx) = _aggregateLowestStepAndDistanceAcrossNodes(lowestDistances, lowestNextSteps);
      // writeln("_aggregateNextStepAcrossNodes g-score: ", gScore, " next step index: ", nextStepIdx);
      return allStates[nextStepIdx];
    }

    proc _aggregateLowestDistanceAcrossNodes(lowestDistances: [rcDomain] real, lowestNextSteps: [rcDomain] idxT) {
      const (gScore, nextStepIdx) = _aggregateLowestStepAndDistanceAcrossNodes(lowestDistances, lowestNextSteps);
      return gScore;
    }
    
    proc _findNextStepByLowestDistance(potentialNextSteps: DistBag((real, idxT))) {
      var lowestDistance = max(real);
      var lowestStepFinal: idxT;
      for (tentativeGScore, at) in potentialNextSteps.these() do
        if tentativeGScore < lowestDistance then
          (lowestDistance, lowestStepFinal) = (tentativeGScore, at);
      return (lowestDistance, lowestStepFinal);          
    }

    proc _createAllStates(ALL, ref defaultForType: this.eltType) {
      if isClass(this.eltType) {
        var allStates: [ALL] this.eltType = defaultForType;
        return allStates;
      } else {
        var allStates: [ALL] this.eltType;
        return allStates;
      }
    }

    proc _updateNeighbor(allStates, allStatesLock$, fScores, gScores, idxNeighbor, neighbor, distance, tentativeGScore) {
      allStatesLock$.readFE();
      allStates[idxNeighbor] = neighbor;
      allStatesLock$.writeXF(true);
      
      on gScores[idxNeighbor] do fScores[idxNeighbor] = tentativeGScore + impl.heuristic(neighbor);
      on gScores[idxNeighbor] do if tentativeGScore < gScores[idxNeighbor] then
        gScores[idxNeighbor] = tentativeGScore;     
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
    proc aStar(ref start: this.eltType, ref defaultForType: this.eltType, distanceToStart: real): (real, LinkedList(this.eltType)) {      
      const bboxScores = {_low.._high};
      const ALL: domain(1) dmapped Cyclic(startIdx=bboxScores.low) = bboxScores;
      // For node n, gScore[n] is the cost of the cheapest path from start to n currently known.
      // For node n, fScore[n] = gScore[n] + h(n). fScore[n] represents our current best guess as to
      // how short a path from start to finish can be if it goes through n.
      var fScores: [ALL] real = max(real);
      var gScores: [ALL] real = max(real);
      var size: atomic idxT = 1;
      fScores[startIdx] = impl.heuristic(start);
      gScores[startIdx] = distanceToStart;
      // writeln("start here: ", here, " distance: ", gScores[startIdx]);
                  
      // allStates contains all the neighbors observed. The array is unordered.
      // New values are added at the end according to the current value of `size`.
      var allStates = _createAllStates(ALL, defaultForType);
      allStates[startIdx] = start;
      // openSet contains indices to the states we are currently exploring. These indices can look up in
      // `fScores`, `gScores` and `allStates`.
      var openSet = new DistBag(idxT);
      openSet.add(startIdx);
      // The states we traveled to to get to the end. States are ordered from start to goal state.
      var path: LinkedList(this.eltType) = makeList(start);
      // hasFinished contains a flag indicating if any of the .ocales has found any finishing state
      var hasFinished: [rcDomain] bool = false;
      // contains the smallest distance traveled to the best state explored on the locale
      // during the current iteration
      var lowestDistances: [rcDomain] real;
      var lowestNextSteps: [rcDomain] idxT;

      var lastSizeSeen$: sync idxT = 1;
      var progressPercentageSpent: Timer;
      progressPercentageSpent.start();
      for loc in Locales {
        on loc {
          var it: atomic int = 0;
          const myLocaleSpace: domain(1) = {0..0};
          const myLocale: [myLocaleSpace] locale = loc;
          while ! (_isEmptySearchSpace(openSet) || _IsGoalStateAcrossNodes(hasFinished)) do {
            const (hasValueInThisLocale, idxCurrent) = _getIndexWithLowestFScore(openSet, fScores, loc);
            if ! hasValueInThisLocale {
              rcLocal(lowestDistances) = max(real);
              rcLocal(lowestNextSteps) = min(idxT);
            
              allLocalesBarrier.barrier();
            } else {
              const sizeFromLastStage = size.read();
              
              _removeStateFromOpenSet(openSet, idxCurrent);
              // mark index at negative infinity. gScores[idxCurrent] will never pass the `tentativeGScore < gScores[idxNeighbor]` condition in A-star algorithm.
              const gScore = gScores[idxCurrent];
              gScores[idxCurrent] = visitedStateGScore;
              const current = allStates[idxCurrent];
              const isGoalState = impl.isGoalState(current);
              rcLocal(hasFinished) = isGoalState;
              if isGoalState {
                rcLocal(lowestDistances) = gScores[idxCurrent];
                rcLocal(lowestNextSteps) = idxCurrent;
                allLocalesBarrier.barrier();
              } else {
                var neighbors = new DistBag(idxT, targetLocales = myLocale);
                var potentialNextSteps = new DistBag((real, idxT), targetLocales = myLocale);

                // https://chapel-lang.org/docs/primers/learnChapelInYMinutes.html?highlight=mutex
                var printStateLock$: sync bool;             // the mutex lock for printState(...) function;
                printStateLock$.writeXF(true);              // Set lock$ to full (unlocked)
                var allStatesLock$: sync bool;
                allStatesLock$.writeXF(true);
                coforall neighbor in impl.findNeighbors(current) do {
                  if debug && here.id == 0 {
                    printStateLock$.readFE();                    // Read lock$ (wait)
                    writef("neighbor i: %7.0dr ", (it.fetchAdd(1):real));
                    impl.printState(neighbor);
                    writef("came from           ");
                    impl.printState(current);
                    printStateLock$.writeXF(true);        // Set lock$ to full (signal)
                  }
                  // TODO: figure out why idxNeighbor == 0 and not unique
                  const idxNeighbor = _aquireIdxToNewNeigbor(allStates, allStatesLock$, gScores, neighbor, sizeFromLastStage, size);
                  const distance = impl.distance(current, neighbor);
                  const tentativeGScore = gScore + distance;
                  // writeln("here: ", here, " size: ", sizeFromLastStage, " index neighbor: ", idxNeighbor, " distance: ", distance, " gScore neighbor: ", tentativeGScore);
                  // heuristic(neighbor) is the heuristic distance from neighbor to finish
                  // fScore[neighbor] is the heuristic distance from start to finish.
                  // We know we hare passing through neighbor.
                  _updateNeighbor(allStates, allStatesLock$, fScores, gScores, idxNeighbor, neighbor, distance, tentativeGScore);
                  potentialNextSteps.add((tentativeGScore, idxNeighbor));
                  neighbors.add(idxNeighbor);              
                }

                // update open set
                for idxNeighbor in neighbors.these() do
                  if _isUnvisitedState(gScores, idxNeighbor) && ! openSet.contains(idxNeighbor) then
                    openSet.add(idxNeighbor);

                // save lowest distance for state: current
                // writeln("potentialNextSteps:\n", potentialNextSteps);
                const (lowestDistance, lowestStepFinal) = _findNextStepByLowestDistance(potentialNextSteps);
                // writeln("here: ", here, " lowestDistance: ", lowestDistance, " lowestStepFinal: ", lowestStepFinal);
                rcLocal(lowestDistances) = lowestDistance;
                rcLocal(lowestNextSteps) = lowestStepFinal;

                allLocalesBarrier.barrier();

                on path {
                  const nextStep = _aggregateNextStepAcrossNodes(lowestDistances, lowestNextSteps, allStates);
                  path.append(nextStep);
                }

                if progress {
                  const delta = allStates.domain.high - allStates.domain.low;
                  const currentSize = size.read();
                  const currentPercent = ((currentSize / delta) * 100): int;
                  const l = lastSizeSeen$.readFE();
                  const previousPercent = ((l / delta) * 100): int;
                  if currentPercent != previousPercent {
                    const timeSpent = progressPercentageSpent.elapsed(TimeUnits.seconds): int;
                    writeln("Progress ", currentPercent, " %. Spent ", timeSpent," seconds...");
                    lastSizeSeen$.writeXF(currentSize);
                    progressPercentageSpent.clear(); 
                  } else {
                    lastSizeSeen$.writeXF(l);
                  }
                }     
                // writeln("Continuing aStar to next iteration");
              }
            }
          }
        }
        
        progressPercentageSpent.stop();
        return (_aggregateLowestDistanceAcrossNodes(lowestDistances, lowestNextSteps), path); 
      }

      halt("You reachad end of a* search space without reading any final state. Review your function isGoalState. Make sure that the final state can be reached.");
      return (distanceToStart, path);
    }
  }


  private use ConnectFour;
  private use GameContext;
  private use Player;
  private use Tile;
  proc main() {
    // writeln("Started");
    // writeln("This program is running on ", numLocales, " different locales");
    const connectFour = new ConnectFour(5);
    const board: [BoardDom] Tile;
    var gameContext = new shared GameContext(board, player=Player.Red);
    var defaultGameContext = new shared GameContext();
    var p = makeList(gameContext);
    param g = 0.0;
    var searcher = new Searcher(gameContext.type, connectFour);
    var solution = searcher.aStar(gameContext, defaultGameContext, g);
  
    // writeln("distance ", solution[0]);
    for state in solution[1] do
      writeln(state, "\n");
    writeln("Finished");
  }
}
