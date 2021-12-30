defmodule Hangman.Game do
  @moduledoc """
  A game struct and functions for the _Hangman Game_.

  The game struct contains the fields `game_name`, `turns_left`, `game_state`,
  `letters` and `used` representing the characteristics of a game in the
  _Hangman Game_.

  ##### Based on the course [Elixir for Programmers](https://codestool.coding-gnome.com/courses/elixir-for-programmers) by Dave Thomas.
  """

  alias __MODULE__
  alias Hangman.Dictionary

  @enforce_keys [:game_name, :letters]
  defstruct game_name: "",
            turns_left: 7,
            game_state: :initializing,
            letters: [],
            used: MapSet.new()

  @typedoc "Letter between a and z"
  @type letter :: String.codepoint()
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
  @opaque t :: %Game{
            game_name: name,
            turns_left: turns_left,
            game_state: state,
            letters: [letter],
            used: used
          }
  @typedoc "A tally struct for the Hangman Game"
  @type tally :: %{
          game_state: state,
          turns_left: turns_left,
          letters: [letter | charlist],
          guesses: [letter]
        }
  @type turns_left :: 0..7
  @type used :: MapSet.t(letter)

  @doc """
  Returns a game struct given a `game_name` and a `word` to be guessed.

  ## Examples

      iex> alias Hangman.Game
      iex> Game.new("Mr Smith").game_state
      :initializing
  """
  @spec new(name, String.t()) :: t
  def new(game_name, word \\ Dictionary.random_word()) do
    %Game{game_name: game_name, letters: String.codepoints(word)}
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
  """
  @spec random_name :: name
  def random_name do
    length = Enum.random(4..10)

    :crypto.strong_rand_bytes(length)
    |> Base.url_encode64()
    # Starting at 0 with length "length"...
    |> binary_part(0, length)
  end

  @doc """
  Makes a move by guessing a letter.

  ## Examples

      iex> alias Hangman.Game
      iex> game = Game.random_name() |> Game.new()
      iex> Game.make_move(game, "a").game_state in [:good_guess, :bad_guess]
      true
  """
  @spec make_move(t, guess :: letter) :: t
  def make_move(%Game{game_state: state} = game, _) when state in [:won, :lost],
    do: game

  # Guess not validated here; should be done in client interface...
  def make_move(%Game{used: used} = game, guess),
    do: make_move(game, guess, MapSet.member?(used, guess))

  @doc """
  Returns a tally struct externalizing `game`.

  ## Examples

      iex> alias Hangman.Game
      iex> game = Game.random_name() |> Game.new()
      iex> game = Game.make_move(game, "a")
      iex> Game.tally(game).turns_left in 6..7
      true
  """
  @spec tally(t) :: tally
  def tally(%Game{game_state: game_state, turns_left: turns_left} = game) do
    %{
      game_state: game_state,
      turns_left: turns_left,
      letters: reveal_guessed(game_state, game.letters, game.used),
      guesses: MapSet.to_list(game.used)
    }
  end

  ## Private functions

  @spec reveal_guessed(state, [letter], used) :: [letter | charlist]
  defp reveal_guessed(:lost = _game_state, letters, used),
    do: letters |> Enum.map(&if MapSet.member?(used, &1), do: &1, else: '#{&1}')

  defp reveal_guessed(_game_state, letters, used),
    do: letters |> Enum.map(&if MapSet.member?(used, &1), do: &1, else: "_")

  @spec make_move(t, letter, boolean) :: t
  defp make_move(game, _guess, _already_used = true),
    do: put_in(game.game_state, :already_used)

  defp make_move(game, guess, _never_used) do
    update_in(game.used, &MapSet.put(&1, guess))
    |> score_guess(guess in game.letters)
  end

  @spec score_guess(t, boolean) :: t
  defp score_guess(game, _good_guess = true) do
    state =
      if MapSet.new(game.letters) |> MapSet.subset?(game.used),
        do: :won,
        else: :good_guess

    put_in(game.game_state, state)
  end

  defp score_guess(%Game{turns_left: 1} = game, _bad_guess),
    do: %Game{game | game_state: :lost, turns_left: 0}

  defp score_guess(%Game{turns_left: 0} = game, _bad_guess), do: game

  defp score_guess(%Game{turns_left: turns_left} = game, _bad_guess),
    do: %Game{game | game_state: :bad_guess, turns_left: turns_left - 1}
end
