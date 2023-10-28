defmodule Nuntiux.Exception do
  @moduledoc """
  For when Nuntiux explicitly raises, in the `!` functions.
  """
  defexception [:message]
end
