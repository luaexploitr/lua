# why am i making this.

import flask
import stockfish

engine = stockfish.Stockfish(path = "./stockfish-windows-x86-64-universal.exe")

App = flask.Flask( import_name = __name__)

@App.route("/api/status", methods = ["GET"])
def Status():
    return "Up!", 200

@App.route("/api/stockfish", methods = ["POST"])
def CalculateMove():
    try:
        moves = [ move.strip() for move in flask.request.get_json().get("moves")]
        moves = [ move for move in moves if move != "" ]
        elo   = flask.request.get_json().get("elo")
        depth = flask.request.get_json().get("depth")

        print("Elo:", elo, "Depth:", depth)
        print(moves)

        engine.set_elo_rating(elo)
        engine.set_depth(depth)

        if (len(moves) != 0):
            engine.make_moves_from_start(moves)
        else:
            engine.set_fen_position("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
    
        return engine.get_best_move(), 200
    except Exception as exception:
        print("Error occurred:", exception)
        return "Unknown error occurred...", 500
        
App.run(
    host         = "127.0.0.1",
    port         = 5500,
    use_reloader = True
)
