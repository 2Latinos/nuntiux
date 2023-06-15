defmodule Nuntiux do
  @moduledoc """
  This is Nuntiux.
  """

  @application :nuntiux

  @opaque opts :: [{:passthrough?, boolean()} | {:history?, boolean()}]

  @type process_name :: atom()

  @doc """
  Returns the application identifier.
  """
  @spec application() :: application
        when application: unquote(@application)
  def application do
    @application
  end

  @doc """
  Starts the application.
  """
  @spec start() :: ok
        when ok: {:ok, [module()]}
  def start do
    Application.ensure_all_started(@application)
  end

  @doc """
  Stops the application.
  """
  @spec stop() :: ok
        when ok: :ok
  def stop do
    Application.stop(@application)
  end
end
