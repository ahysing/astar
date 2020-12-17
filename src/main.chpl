use AStar;
use StateMapper;
use State;
use GameContext;
use ConnectFour;

module AStar {      
  proc main() {
    writeln("Started");
    writeln("This program is running on ", numLocales, " locales");
    const connectFour = new ConnectFour(5);
    const startState = new State();
    const stateMapper = new StateMapper();
    var searcher = new Searcher(State, stateMapper, connectFour);
    const f = 0.0;
    const g = 0.0;    
    var solution = searcher.search(startState, f, g);
    writeln("distance", solution.distance);
    for state in solution.path do
    writeln("Player", state.player);
    writeln("Finished");
  }
}
