defmodule Nuntiux do
  @moduledoc """
  This is Nuntiux.
  """

  @application :nuntiux

  @type process_name :: atom()

  @type opts :: Nuntiux.Mocker.opts()
  @type history :: Nuntiux.Mocker.history()
  @type received? :: Nuntiux.Mocker.received?()
  @type event :: Nuntiux.Mocker.event()
  @type expect_fun :: Nuntiux.Mocker.expect_fun()
  @type expect_name :: Nuntiux.Mocker.expect_name()
  @type expect_id :: Nuntiux.Mocker.expect_id()
  @type expects :: Nuntiux.Mocker.expects()

  defmacro if_mocked(process_name, fun) do
    quote bind_quoted: [
            process_name: process_name,
            fun: fun
          ] do
      if process_name in mocked(),
        do: fun.(),
        else: {:error, :not_mocked}
    end
  end

  @doc false
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
    Nuntiux.Supervisor.start_mock(process_name, opts)
  end

  @doc """
  Removes a mocking process or expect function.
  If the expect function was not already there, this function still returns 'ok'.
  If the process is not mocked, an error is returned.
  """
  @spec delete(process_name, expect_id) :: ok | error
        when process_name: process_name(),
             expect_id: nil | expect_id(),
             ok: :ok,
             error: {:error, :not_mocked}
  def delete(process_name, expect_id \\ nil) do
    if_mocked(
      process_name,
      fn ->
        if is_nil(expect_id),
          do: Nuntiux.Supervisor.stop_mock(process_name),
          else: Nuntiux.Mocker.delete(process_name, expect_id)
      end
    )
  end

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
    if_mocked(
      process_name,
      fn ->
        Nuntiux.Mocker.mocked_process(process_name)
      end
    )
  end

  @doc """
  Returns the history of messages received by a mocked process.
  """
  @spec history(process_name) :: ok | error
        when process_name: process_name(),
             ok: history(),
             error: {:error, :not_mocked}
  def history(process_name) do
    if_mocked(
      process_name,
      fn ->
        Nuntiux.Mocker.history(process_name)
      end
    )
  end

  @doc """
  Returns whether a particular message was received already.
  **Note**: it only works with `history?: true`.
  """
  @spec received?(process_name, message) :: ok | error
        when process_name: process_name(),
             message: term(),
             ok: received?(),
             error: {:error, :not_mocked}
  def received?(process_name, message) do
    if_mocked(
      process_name,
      fn ->
        Nuntiux.Mocker.received?(process_name, message)
      end
    )
  end

  @doc """
  Erases the history for a mocked process.
  """
  @spec reset_history(process_name) :: ok | error
        when process_name: process_name(),
             ok: :ok,
             error: {:error, :not_mocked}
  def reset_history(process_name) do
    if_mocked(
      process_name,
      fn ->
        Nuntiux.Mocker.reset_history(process_name)
      end
    )
  end

  @doc """
  Adds a new (*named*?) expect function to a mocked process.
  When a message is received by the process, this function will be run on it.
  If the message doesn't match any clause, nothing will be done.
  If the process is not mocked, an error is returned.
  If the expect function is named, and there was already an expect function with that name,
  it's replaced.
  If the expect function is named, when it is successfully added or replaced, it'll keep the name
  as its identifier. Otherwise, a reference is returned as an identifier.
  """
  @spec expect(process_name, expect_name, expect_fun) :: ok | error
        when process_name: process_name(),
             expect_name: nil | expect_name(),
             expect_fun: expect_fun(),
             ok: expect_id(),
             error: {:error, :not_mocked}
  def expect(process_name, expect_name \\ nil, expect_fun) do
    if_mocked(
      process_name,
      fn ->
        Nuntiux.Mocker.expect(process_name, expect_name, expect_fun)
      end
    )
  end

  @doc """
  Returns the list of expect functions for a process.
  """
  @spec expects(process_name) :: ok | error
        when process_name: process_name(),
             ok: expects(),
             error: {:error, :not_mocked}
  def expects(process_name) do
    if_mocked(
      process_name,
      fn ->
        Nuntiux.Mocker.expects(process_name)
      end
    )
  end
end
