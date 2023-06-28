defmodule Nuntiux do
  @moduledoc """
  This is Nuntiux.
  """

  @application :nuntiux

  @type opts :: [{:passthrough?, boolean()} | {:history?, boolean()}]
  @type process_name :: atom()

  @type history :: Nuntiux.Mocker.history()
  @type received? :: Nuntiux.Mocker.received?()
  @type event :: Nuntiux.Mocker.event()

  defmacro if_mocked(process_name, fun) do
    quote bind_quoted: [
            process_name: process_name,
            fun: fun
          ] do
      if process_name in mocked(),
        do: fun.(process_name),
        else: {:error, :not_mocked}
    end
  end

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
  Signals if option `passthrough?` is enabled or not.
  """
  @spec passthrough?(opts) :: passthrough?
        when opts: opts(),
             passthrough?: boolean()
  def passthrough?(opts) do
    opts[:passthrough?]
  end

  @doc """
  Signals if option `history?` is enabled or not.
  """
  @spec history?(opts) :: history?
        when opts: opts(),
             history?: boolean()
  def history?(opts) do
    opts[:history?]
  end

  @doc """
  Removes a mocking process.
  """
  @spec delete(process_name) :: ok | error
        when process_name: process_name(),
             ok: :ok,
             error: {:error, :not_mocked}
  defdelegate delete(process_name), to: Nuntiux.Supervisor, as: :stop_mock

  @doc """
  Returns the list of mocked processes.
  """
  @spec mocked() :: process_names
        when process_names: [process_name()]
  defdelegate mocked(), to: Nuntiux.Supervisor

  @doc """
  Returns the PID of a mocked process (the original one with that name).
  """
  @spec mocked_process(process_name) :: ok | error
        when process_name: process_name(),
             ok: pid(),
             error: {:error, :not_mocked}
  def mocked_process(process_name) do
    if_mocked(process_name, &Nuntiux.Mocker.mocked_process/1)
  end

  @doc """
  Returns the history of messages received by a mocked process.
  """
  @spec history(process_name) :: ok | error
        when process_name: process_name(),
             ok: Nuntiux.Mocker.history(),
             error: {:error, :not_mocked}
  def history(process_name) do
    if_mocked(process_name, &Nuntiux.Mocker.history/1)
  end

  @doc """
  Returns whether a particular message was received already.
  **Note**: it only works with `history?: true`.
  """
  @spec received?(process_name, message) :: ok | error
        when process_name: process_name(),
             message: term(),
             ok: Nuntiux.Mocker.received?(),
             error: {:error, :not_mocked}
  def received?(process_name, message) do
    if_mocked(process_name, &Nuntiux.Mocker.received?(&1, message))
  end

  @doc """
  Erases the history for a mocked process.
  """
  @spec reset_history(process_name) :: ok | error
        when process_name: process_name(),
             ok: :ok,
             error: {:error, :not_mocked}
  def reset_history(process_name) do
    if_mocked(process_name, &Nuntiux.Mocker.reset_history/1)
  end
end
