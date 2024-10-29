defmodule Hangman.Game do
  @moduledoc """
  A game struct and functions for the _Hangman Game_.

  The game struct contains the fields `game_name`, `game_state`, `turns_left`,
  `letters` and `used` representing the properties of a game in the _Hangman
  Game_.

  ##### Based on the course [Elixir for Programmers](https://codestool.coding-gnome.com/courses/elixir-for-programmers) by Dave Thomas.
  """

  alias __MODULE__

  @words ~W[smithereens splintered shattered deliquescent flabbergast]

  @enforce_keys [:game_name, :letters]
  defstruct game_name: "",
            game_state: :initializing,
            turns_left: 7,
            letters: [],
            used: MapSet.new()

  @typedoc "Letter from `a` to `z`"
  @type letter :: <<_::8>>
  @typedoc "Game name"
  @type name :: String.t()
  @typedoc "Game state"
  @type state ::
          :initializing
          | :good_guess
          | :bad_guess
          | :already_used
          | :lost
          | :won
  @typedoc "A game struct for the Hangman Game"
  @type t :: %Game{
          game_name: name,
          game_state: state,
          turns_left: turns_left,
          letters: [letter],
          used: used
        }
  @typedoc "A tally map for the Hangman Game"
  @type tally :: %{
          game_state: state,
          turns_left: turns_left,
          letters: [letter | underline | [letter]],
          guesses: [letter]
        }
  @typedoc "Turns left from 7 to 0"
  @type turns_left :: 0..7
  @typedoc "Underline: `_`"
  @type underline :: <<_::8>>
  @typedoc "A set of used (guessed) letters"
  @type used :: MapSet.t(letter)

  @doc """
  Creates a game struct from a `game_name` and a `word` to be guessed. The
  default value for `game_name` is provided by function `random_name/0` and for
  `word` by function `random_word/0`.

  ## Examples

      iex> alias Hangman.Game
      iex> game = Game.new()
      iex> game_name_length = String.length(game.game_name)
      iex> {game.game_state, game.turns_left, game_name_length in 4..10}
      {:initializing, 7, true}

      iex> alias Hangman.Game
      iex> game = Game.new("Mr Smith")
      iex> {game.game_state, game.turns_left, game.game_name, game.used}
      {:initializing, 7, "Mr Smith", MapSet.new([])}

      iex> alias Hangman.Game
      iex> game = Game.new("Wibble", "wibble")
      iex> {game.turns_left, game.game_name, game.letters, game.used}
      {7, "Wibble", ~W[w i b b l e], MapSet.new([])}
  """
  @spec new(name, String.t()) :: t
  def new(game_name \\ random_name(), word \\ random_word()),
    do: %Game{game_name: game_name, letters: String.codepoints(word)}

  @doc """
  Returns a random name of 4 to 10 characters.

  ## Examples

      iex> alias Hangman.Game
      iex> for _ <- 0..99, uniq: true do
      iex>   length = Game.random_name() |> String.length()
      iex>   length in 4..10
      iex> end
      [true]

      iex> alias Hangman.Game
      iex> for _ <- 0..99, uniq: true do
      iex>   Game.random_name() =~ ~r/^[a-zA-Z0-9_-]{4,10}$/
      iex> end
      [true]
  """
  @spec random_name :: name
  def random_name do
    length = Enum.random(4..10)

    :crypto.strong_rand_bytes(length)
    |> Base.url_encode64(padding: false)
    # Starting at 0 with length "length"...
    |> binary_part(0, length)
  end

  @doc """
  Makes a move by guessing a letter.

  ## Examples

      iex> alias Hangman.Game
      iex> game = Game.new()
      iex> Game.make_move(game, "a").game_state in [:good_guess, :bad_guess]
      true
  """
  @spec make_move(t, guess :: letter) :: t
  def make_move(%Game{game_state: state} = game, _) when state in [:won, :lost],
    do: game

  def make_move(%Game{used: used} = game, <<byte>> = guess) when byte in ?a..?z,
    do: make_move(game, guess, MapSet.member?(used, guess))

  @doc """
  Returns a tally map externalizing `game`.

  ## Examples

      iex> alias Hangman.Game
      iex> game = Game.random_name() |> Game.new("anaconda")
      iex> game = Game.make_move(game, "a")
      iex> game = Game.make_move(game, "n")
      iex> tally = Game.tally(game)
      iex> {tally.game_state, tally.turns_left, tally.letters, tally.guesses}
      {:good_guess, 7, ~W[a n a _ _ n _ a], ~W[a n]}
  """
  @spec tally(t) :: tally
  def tally(%Game{game_state: game_state, turns_left: turns_left} = game) do
    %{
      game_state: game_state,
      turns_left: turns_left,
      letters: reveal_guessed_letters(game_state, game.letters, game.used),
      guesses: MapSet.to_list(game.used)
    }
  end

  @doc """
  Resigns `game`.

  ## Examples

      iex> alias Hangman.Game
      iex> game = Game.random_name() |> Game.new("anaconda")
      iex> game = Game.make_move(game, "a")
      iex> game = Game.make_move(game, "n")
      iex> lost_game = Game.resign(game)
      iex> tally = Game.tally(lost_game)
      iex> {tally.game_state, tally.turns_left, tally.letters, tally.guesses}
      {:lost, 7, ["a", "n", "a", ["c"], ["o"], "n", ["d"], "a"], ~W[a n]}
  """
  @spec resign(t) :: t
  def resign(game), do: put_in(game.game_state, :lost)

  ## Private functions

  @spec reveal_guessed_letters(state, [letter], used) ::
          [letter | underline | [letter]]
  defp reveal_guessed_letters(_game_state = :lost, letters, used),
    do: letters |> Enum.map(&if MapSet.member?(used, &1), do: &1, else: [&1])

  defp reveal_guessed_letters(_game_state, letters, used),
    do: letters |> Enum.map(&if MapSet.member?(used, &1), do: &1, else: "_")

  @spec make_move(t, letter, boolean) :: t
  defp make_move(game, _guess, _already_used? = true),
    do: put_in(game.game_state, :already_used)

  defp make_move(game, guess, _already_used?) do
    update_in(game.used, &MapSet.put(&1, guess))
    |> score_guess(guess in game.letters)
  end

  @spec score_guess(t, boolean) :: t
  defp score_guess(game, _good_guess? = true) do
    MapSet.new(game.letters)
    |> MapSet.subset?(game.used)
    |> if(do: :won, else: :good_guess)
    |> then(&put_in(game.game_state, &1))
  end

  defp score_guess(%Game{turns_left: 1} = game, _good_guess?),
    do: %Game{game | game_state: :lost, turns_left: 0}

  defp score_guess(%Game{turns_left: turns_left} = game, _good_guess?),
    do: %Game{game | game_state: :bad_guess, turns_left: turns_left - 1}

  @spec random_word :: String.t()
  defp random_word, do: Enum.random(@words)
end
