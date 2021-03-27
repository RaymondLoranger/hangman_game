defmodule Hangman.GameTest do
  use ExUnit.Case
  doctest Hangman.Game

  test "greets the world" do
    assert Hangman.Game.hello() == :world
  end
end
