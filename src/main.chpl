private use AStar;
private use ConnectFour;
private use GameContext;
private use State;

module AStar {      
  proc main() {
    writeln("Started");
    writeln("This program is running on ", numLocales, " locales");
    const connectFour = new ConnectFour(5);
    const gameContext = new GameContext(player=Player.Red);
    var searcher = new Searcher(GameContext, connectFour);
    const g = 0.0;    
    var solution = searcher.aStar(gameContext.borrowed(), g);
    writeln("distance", solution.distance);
    for state in solution.path do
    writeln("Player", state.player);
    writeln("Finished");
  }
}
