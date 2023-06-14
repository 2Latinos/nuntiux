defmodule NuntiuxTest do
  use ExUnit.Case
  doctest Nuntiux

  describe "Nuntiux" do
    test "starts and stops" do
      application = Nuntiux.application()
      # Because mix auto-starts the application
      Nuntiux.stop()

      {:ok, apps} = Nuntiux.start()
      [^application | _other] = apps
      no_modules = []
      {:ok, ^no_modules} = Nuntiux.start()
      Nuntiux.stop()

      {:ok, [^application]} = Nuntiux.start()
      Nuntiux.stop()
    end
  end
end
