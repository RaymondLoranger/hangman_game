# ┌──────────────────────────────────────────────────────────────┐
# │ Based on the course "Elixir for Programmers" by Dave Thomas. │
# └──────────────────────────────────────────────────────────────┘
defmodule Hangman.Game do
  @moduledoc """
  A game struct and functions for the _Hangman Game_.

  The game struct contains the fields `game_name`, `game_state`, `turns_left`,
  `letters` and `used` representing the properties of a game in the _Hangman
  Game_.

  ##### Based on the course [Elixir for Programmers](https://codestool.coding-gnome.com/courses/elixir-for-programmers) by Dave Thomas.
  """

  alias __MODULE__

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
  @typedoc "A word with letters from `a` to `z`"
  @type word :: String.t()

  @doc """
  Creates a game struct from a `word` to be guessed and a `game_name`.
  The default value for `game_name` is provided by function `random_name/0`.

  Using function `Hangman.Dictionary.random_word/0` of app `:hangman_dictionary`
  to provide the default value for `word` would cause app `:hangman_dictionary`
  to run on each client node as opposed to only on the engine node (see function
  `Hangman.Engine.GameServer.init/1` of app `:hangman_engine`).

  ## Examples

      iex> alias Hangman.Game
      iex> %Game{game_name: name} = game = Game.new("wibble", "Wibble")
      iex> {name, game.game_state, game.turns_left, game.letters, game.used}
      {"Wibble", :initializing, 7, ~W[w i b b l e], MapSet.new([])}

      iex> alias Hangman.Game
      iex> Game.new("José")
      ** (ArgumentError) some characters of 'José' not a-z
  """
  @spec new(word, name) :: t
  def new(word, game_name \\ random_name()) when is_binary(word) do
    letters = String.codepoints(word)

    case Enum.all?(letters, fn <<byte>> -> byte in ?a..?z end) do
      true -> %Game{game_name: game_name, letters: letters}
      false -> raise ArgumentError, "some characters of '#{word}' not a-z"
    end
  end

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
      iex> game = Game.new("wibble")
      iex> Game.make_move(game, "a").game_state
      :bad_guess

      iex> alias Hangman.Game
      iex> game = Game.new("wibble")
      iex> Game.make_move(game, "B")
      ** (ArgumentError) guess 'B' not a-z
  """
  @spec make_move(t, guess :: letter) :: t
  def make_move(%Game{game_state: state} = game, _) when state in [:won, :lost],
    do: game

  def make_move(%Game{used: used} = game, <<byte>> = guess) when byte in ?a..?z,
    do: make_move(game, guess, MapSet.member?(used, guess))

  def make_move(_game, guess),
    do: raise(ArgumentError, "guess '#{guess}' not a-z")

  @doc """
  Returns a tally map externalizing `game`.

  ## Examples

      iex> alias Hangman.Game
      iex> game = Game.new("anaconda")
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
      iex> game = Game.new("anaconda")
      iex> game = Game.make_move(game, "a")
      iex> game = Game.make_move(game, "n")
      iex> lost_game = Game.resign(game)
      iex> tally = Game.tally(lost_game)
      iex> {tally.game_state, tally.turns_left, tally.letters, tally.guesses}
      {:lost, 7, ["a", "n", "a", ["c"], ["o"], "n", ["d"], "a"], ~W[a n]}
  """
  @spec resign(t) :: t
  def resign(%Game{} = game), do: put_in(game.game_state, :lost)

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
end
