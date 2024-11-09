defmodule Hangman.GameTest do
  use ExUnit.Case, async: true

  alias Hangman.Game

  doctest Game

  setup_all do
    wibble = Game.new("wibble")
    letters_reveal! = [["w"], ["i"], "b", "b", ["l"], ["e"]]

    moves = %{
      winning: [
        # guess, state,   left, revealed letters, used
        {"w", :good_guess, 007, ~W(w _ _ _ _ _), ~W(w)},
        {"i", :good_guess, 007, ~W(w i _ _ _ _), ~W(w i)},
        {"i", :already_used, 7, ~W(w i _ _ _ _), ~W(w i)},
        {"b", :good_guess, 007, ~W(w i b b _ _), ~W(w i b)},
        {"l", :good_guess, 007, ~W(w i b b l _), ~W(w i b l)},
        {"z", :bad_guess, 0006, ~W(w i b b l _), ~W(w i b l z)},
        {"e", :won, 0x00000006, ~W(w i b b l e), ~W(w i b l z e)}
      ],
      losing: [
        # guess, state, left, revealed letters, used
        {"m", :bad_guess, 06, ~W(_ _ _ _ _ _), ~W(m)},
        {"n", :bad_guess, 05, ~W(_ _ _ _ _ _), ~W(m n)},
        {"o", :bad_guess, 04, ~W(_ _ _ _ _ _), ~W(m n o)},
        {"p", :bad_guess, 03, ~W(_ _ _ _ _ _), ~W(m n o p)},
        {"q", :bad_guess, 02, ~W(_ _ _ _ _ _), ~W(m n o p q)},
        {"b", :good_guess, 2, ~W(_ _ b b _ _), ~W(m n o p q b)},
        {"r", :bad_guess, 01, ~W(_ _ b b _ _), ~W(m n o p q b r)},
        {"s", :lost, 0b00000, letters_reveal!, ~W(m n o p q b r s)}
      ],
      tester: fn moves, game ->
        Enum.reduce(moves, game, fn {guess, state, left, reveal, used}, game ->
          game = Game.make_move(game, guess)
          assert game.game_state == state
          assert game.turns_left == left
          assert Game.tally(game).letters == reveal
          assert game.used == MapSet.new(used)
          assert MapSet.equal?(game.used, MapSet.new(used))
          game
        end)
      end
    }

    %{game: wibble, moves: moves}
  end

  describe "Game.new/1" do
    test "returns a struct", %{game: wibble} do
      assert wibble.game_state == :initializing
      assert wibble.turns_left == 7
      assert wibble.letters == ~W(w i b b l e)
      assert is_struct(wibble, Game)
    end
  end

  describe "Game.make_move/2" do
    test "game static once won or lost", %{game: wibble} do
      for state <- [:won, :lost] do
        game = %Game{wibble | game_state: state}
        assert ^game = Game.make_move(game, "x")
      end
    end

    test "first guess of a letter: not already used", %{game: wibble} do
      game = Game.make_move(wibble, "x")
      refute game.game_state == :already_used
    end

    test "second guess of a letter: already used", %{game: wibble} do
      game = Game.make_move(wibble, "x")
      refute game.game_state == :already_used
      game = Game.make_move(game, "x")
      assert game.game_state == :already_used
    end

    test "a good guess is recognized", %{game: wibble} do
      game = Game.make_move(wibble, "w")
      assert game.game_state == :good_guess
      assert game.turns_left == 7
    end

    test "a bad guess is recognized", %{game: wibble} do
      game = Game.make_move(wibble, "x")
      assert game.game_state == :bad_guess
      assert game.turns_left == 6
    end

    test "a guessed word is a won game", %{game: wibble, moves: moves} do
      assert %Game{game_state: :won} = moves.tester.(moves.winning, wibble)
    end

    test "a lost game is recognized", %{game: wibble, moves: moves} do
      assert %Game{game_state: :lost} = moves.tester.(moves.losing, wibble)
    end
  end
end
