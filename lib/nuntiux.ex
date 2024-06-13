defmodule Nuntiux do
  @moduledoc """
  This is Nuntiux.
  """

  # The same as found in mix.exs
  @application :nuntiux

  @typedoc """
  The name of a process.
  """
  @type process_name :: atom()
  @typedoc """
  Options to pass to the mocker process:
  * `:passthrough?`: indicates if messages received by the mock process are passed through to
    the mocked process (defaults to `true`)
  * `:history?`: indicates if the mock is to keep a history of messages it receives
    (defaults to `true`)
  """
  @type opts :: Nuntiux.Mocker.opts()
  @typedoc """
  A list of `event()`.
  """
  @type history :: Nuntiux.Mocker.history()
  @typedoc """
  A timestamped message.
  """
  @type event :: Nuntiux.Mocker.event()
  @typedoc """
  An expectation handler: a function that matches on a message and potentially does something
  with it.
  """
  @type expect_fun :: Nuntiux.Mocker.expect_fun()
  @typedoc """
  The name of an expectation.
  """
  @type expect_name :: Nuntiux.Mocker.expect_name()
  @typedoc """
  The identifier of an expectation.
  If the expectation is not named, this is "an almost unique reference", as per `Kernel.make_ref/0`
  """
  @type expect_id :: Nuntiux.Mocker.expect_id()
  @typedoc """
  A map of expectation identifiers to their expectation handlers.
  """
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
    Enum.each(mocked(), &delete/1)
    Application.stop(@application)
  end

  @doc """
  Injects a new mock process in front of the process with the provided name.
  """
  @spec new(process_name, opts) :: ok | error
        when process_name: process_name(),
             opts: opts(),
             ok: :ok,
             error: {:error, :not_found | :already_mocked}
  def new(process_name, opts \\ %{}) do
    case mocked_process(process_name) do
      {:error, :not_mocked} ->
        Nuntiux.Supervisor.start_mock(process_name, opts)

      _pid ->
        {:error, :already_mocked}
    end
  end

  @doc """
  The same as `new/2` but raises a `Nuntiux.Exception` in case of error.
  """
  @spec new!(process_name, opts) :: process_name
        when process_name: process_name(),
             opts: opts()
  def new!(process_name, opts \\ %{}) do
    case new(process_name, opts) do
      {:error, :not_found} ->
        raise(Nuntiux.Exception, message: "Process #{process_name} not found.")

      {:error, :already_mocked} ->
        raise(Nuntiux.Exception, message: "Process #{process_name} is already mocked.")

      :ok ->
        process_name
    end
  end

  @doc """
  Removes a mocking process or expect function.
  If the expect function was not already there, this function still returns 'ok'.
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
  Passes the current message down to the mocked process.
  **Note**: this code should only be used inside an expect fun.
  """
  @spec passthrough() :: ok
        when ok: :ok
  defdelegate passthrough(), to: Nuntiux.Mocker

  @doc """
  Passes a message down to the mocked process.
  **Note**: this code should only be used inside an expect fun.
  """
  @spec passthrough(message) :: ok
        when message: term(),
             ok: :ok
  defdelegate passthrough(message), to: Nuntiux.Mocker

  @doc """
  Returns the PID of the currently mocked process.
  **Note**: this code should only be used inside an expect fun.
  """
  @spec mocked_process() :: pid
        when pid: pid()
  defdelegate mocked_process(), to: Nuntiux.Mocker

  @doc """
  Returns the history of messages received by a mocked process.
  """
  @spec history(process_name) :: history | error
        when process_name: process_name(),
             history: history(),
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
  @spec received?(process_name, message) :: received? | error
        when process_name: process_name(),
             message: term(),
             received?: boolean(),
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
  @spec expect(process_name, expect_name, expect_fun) :: expect_id | error
        when process_name: process_name(),
             expect_name: nil | expect_name(),
             expect_fun: expect_fun(),
             expect_id: expect_id(),
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
  The same as `expect/3` but raises a `Nuntiux.Exception` in case of error.
  """
  @spec expect!(process_name, expect_name, expect_fun) :: process_name
        when process_name: process_name(),
             expect_name: nil | expect_name(),
             expect_fun: expect_fun()

  def expect!(process_name, expect_name \\ nil, expect_fun) do
    case expect(process_name, expect_name, expect_fun) do
      {:error, :not_mocked} ->
        raise(Nuntiux.Exception, message: "Process #{process_name} not mocked.")

      _expect_id ->
        process_name
    end
  end

  @doc """
  Returns the list of expect functions for a process.
  """
  @spec expects(process_name) :: expects | error
        when process_name: process_name(),
             expects: expects(),
             error: {:error, :not_mocked}
  def expects(process_name) do
    if_mocked(
      process_name,
      fn ->
        Nuntiux.Mocker.expects(process_name)
      end
    )
  end

  defmodule Exception do
    @moduledoc """
    For when Nuntiux explicitly raises.
    """
    defexception message: nil, stack: nil
  end
end
