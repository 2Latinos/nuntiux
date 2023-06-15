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

  @doc """
  Injects a new mock process in front of the process with the provided name.
  Returns an error if there is no process registered under that name.
  """
  @spec new(process_name, opts) :: ok | error
        when process_name: process_name(),
             opts: opts(),
             ok: :ok,
             error: {:error, :not_found}
  def new(process_name, opts \\ []) do
    default_opts = [{:passthrough?, true}, {:history?, true}]
    opts = Keyword.merge(default_opts, opts)
    Nuntiux.Supervisor.start_mock(process_name, opts)
  end

  @doc """
  Signals if option `passthrough` is enabled or not.
  """
  @spec passthrough?(opts) :: passthrough?
        when opts: opts(),
             passthrough?: boolean()
  def passthrough?(opts) do
    opts[:passthrough?]
  end
end
