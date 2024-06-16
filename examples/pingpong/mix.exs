defmodule Pingpong.MixProject do
  use Mix.Project

  @version "0.0.1"
  @elixir "~> 1.15"

  def project do
    [
      app: :pingpong,
      deps: [nuntiux: []],
      description: "A Nuntiux usage example",
      elixir: @elixir,
      version: @version
    ]
  end
end
