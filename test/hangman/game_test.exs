defmodule Hangman.GameTest do
  use ExUnit.Case, async: true

  alias Hangman.Game

  doctest Game

  setup_all do
    games = %{
      ad_lib: Game.new(),
      random: Game.new("Random word"),
      wibble: Game.new("Direct word", "wibble"),
      a_to_z?: fn <<code>> = _letter -> code in ?a..?z end
    }

    # [["w"], ["i"], ["b"], ["b"], ["l"], ["e"]]
    letters_missed! = ~W(w i b b l e) |> Enum.map(&[&1])

    moves = %{
      winning: [
        # guess, state, left, revealed letters, used
        {"w", :good_guess, 7, ~W(w _ _ _ _ _), ~W(w)},
        {"i", :good_guess, 7, ~W(w i _ _ _ _), ~W(w i)},
        {"b", :good_guess, 7, ~W(w i b b _ _), ~W(w i b)},
        {"l", :good_guess, 7, ~W(w i b b l _), ~W(w i b l)},
        {"z", :bad_guess, 06, ~W(w i b b l _), ~W(w i b l z)},
        {"e", :won, 0x000006, ~W(w i b b l e), ~W(w i b l e z)}
      ],
      losing: [
        # guess, state, left, revealed letters, used
        {"m", :bad_guess, 6, ~W(_ _ _ _ _ _), ~W(m)},
        {"n", :bad_guess, 5, ~W(_ _ _ _ _ _), ~W(m n)},
        {"o", :bad_guess, 4, ~W(_ _ _ _ _ _), ~W(m n o)},
        {"p", :bad_guess, 3, ~W(_ _ _ _ _ _), ~W(m n o p)},
        {"q", :bad_guess, 2, ~W(_ _ _ _ _ _), ~W(m n o p q)},
        {"r", :bad_guess, 1, ~W(_ _ _ _ _ _), ~W(m n o p q r)},
        {"s", :lost, 0x0000, letters_missed!, ~W(m n o p q r s)}
      ],
      tester: fn moves, game ->
        Enum.reduce(moves, game, fn {guess, state, left, letters, used}, game ->
          game = Game.make_move(game, guess)
          assert game.game_state == state
          assert game.turns_left == left
          assert game.used == MapSet.new(used)
          assert Game.tally(game).letters == letters
          game
        end)
      end
    }

    %{games: games, moves: moves}
  end

  describe "Game.new/0" do
    test "returns a struct", %{games: games} do
      assert games.ad_lib.game_state == :initializing
      assert games.ad_lib.turns_left == 7
      assert length(games.ad_lib.letters) > 0
      assert Enum.all?(games.ad_lib.letters, &(&1 =~ ~r/[a-z]/))
      assert is_struct(games.ad_lib, Game)
    end
  end

  describe "Game.new/1" do
    test "returns a struct", %{games: games} do
      assert games.random.game_state == :initializing
      assert games.random.turns_left == 7
      assert length(games.random.letters) > 0
      assert Enum.all?(games.random.letters, &(&1 =~ ~r/[a-z]/))
      assert Enum.all?(games.random.letters, games.a_to_z?)
      assert is_struct(games.random, Game)
    end
  end

  describe "Game.new/2" do
    test "returns a struct", %{games: games} do
      assert games.wibble.game_state == :initializing
      assert games.wibble.turns_left == 7
      assert games.wibble.letters == ~W[w i b b l e]
      assert is_struct(games.wibble, Game)
    end
  end

  describe "Game.make_move/2" do
    test "game static once won or lost", %{games: games} do
      for state <- [:won, :lost] do
        game = %Game{games.random | game_state: state}
        assert ^game = Game.make_move(game, "x")
      end
    end

    test "first guess of a letter: not already used", %{games: games} do
      game = Game.make_move(games.random, "x")
      refute game.game_state == :already_used
    end

    test "second guess of a letter: already used", %{games: games} do
      game = Game.make_move(games.random, "x")
      refute game.game_state == :already_used
      game = Game.make_move(game, "x")
      assert game.game_state == :already_used
    end

    test "a good guess is recognized", %{games: games} do
      game = Game.make_move(games.wibble, "w")
      assert game.game_state == :good_guess
      assert game.turns_left == 7
    end

    test "a bad guess is recognized", %{games: games} do
      game = Game.make_move(games.wibble, "x")
      assert game.game_state == :bad_guess
      assert game.turns_left == 6
    end

    test "a guessed word is a won game", %{games: games, moves: moves} do
      assert %Game{game_state: :won} =
               moves.tester.(moves.winning, games.wibble)
    end

    test "a lost game is recognized", %{games: games, moves: moves} do
      assert %Game{game_state: :lost} =
               moves.tester.(moves.losing, games.wibble)
    end
  end
end
