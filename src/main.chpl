private use AStar;
private use ConnectFour;
private use GameContext;
private use State;
private use StateMapper;

module AStar {      
  proc main() {
    writeln("Started");
    writeln("This program is running on ", numLocales, " locales");
    const connectFour = new ConnectFour(5);
    const gameContext = new GameContext(player=Player.Red);
    const stateMapper = new StateMapper();
    var searcher = new Searcher(GameContext, connectFour);
    const g = 0.0;    
    var solution = searcher.search(gameContext, g);
    writeln("distance", solution.distance);
    for state in solution.path do
    writeln("Player", state.player);
    writeln("Finished");
  }
}
