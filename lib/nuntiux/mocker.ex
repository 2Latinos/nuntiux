defmodule Nuntiux.Mocker do
  @moduledoc """
  A process that mocks another one.
  """

  @type history :: [event()]
  @type received? :: boolean()
  @type event :: %{timestamp: integer(), message: term()}

  @typep state :: %{
           process_name: Nuntiux.process_name(),
           process_pid: pid(),
           process_monitor: reference(),
           history: [Nuntiux.event()],
           opts: Nuntiux.opts()
         }
  @typep request :: :history | {:received?, message :: term()}

  @mocked_process_key :"#{__MODULE__}.mocked_process"

  @doc false
  @spec start_link(process_name, opts) :: ok | ignore
        when process_name: Nuntiux.process_name(),
             opts: Nuntiux.opts(),
             ok: {:ok, pid()},
             ignore: :ignore
  def start_link(process_name, opts) do
    case Process.whereis(process_name) do
      nil ->
        :ignore

      process_pid ->
        module = __MODULE__
        function = :init
        args = [process_name, process_pid, opts]
        :proc_lib.start_link(module, function, args)
    end
  end

  @doc false
  @spec delete(process_name) :: ok
        when process_name: Nuntiux.process_name(),
             ok: :ok
  def delete(process_name) do
    process_pid = mocked_process(process_name)
    reregister(process_name, process_pid)
  end

  @doc false
  @spec mocked_process(process_name) :: pid
        when process_name: Nuntiux.process_name(),
             pid: pid()
  def mocked_process(process_name) do
    {:dictionary, dict} =
      process_name
      |> Process.whereis()
      |> Process.info(:dictionary)

    Keyword.get(dict, @mocked_process_key)
  end

  @doc false
  @spec history(process_name) :: ok
        when process_name: Nuntiux.process_name(),
             ok: history()
  def history(process_name) do
    request = :history
    call(process_name, request)
  end

  @doc false
  @spec received?(process_name, message) :: ok
        when process_name: Nuntiux.process_name(),
             message: term(),
             ok: received?()
  def received?(process_name, message) do
    request = {:received?, message}
    call(process_name, request)
  end

  @doc false
  @spec reset_history(process_name) :: ok
        when process_name: Nuntiux.process_name(),
             ok: :ok
  def reset_history(process_name) do
    label = :"$nuntiux.cast"
    request = :reset_history
    send(process_name, {label, request})
    :ok
  end

  @doc false
  @spec init(process_name, process_pid, opts) :: no_return
        when process_name: Nuntiux.process_name(),
             process_pid: pid(),
             opts: Nuntiux.opts(),
             no_return: no_return()
  def init(process_name, process_pid, opts) do
    mocker_pid = self()
    process_monitor = Process.monitor(process_pid)
    reregister(process_name, mocker_pid, process_pid)
    :proc_lib.init_ack({:ok, mocker_pid})

    loop(%{
      process_name: process_name,
      process_pid: process_pid,
      process_monitor: process_monitor,
      history: [],
      opts: opts
    })
  end

  @spec call(process_name, request) :: ok
        when process_name: Nuntiux.process_name(),
             request: request(),
             ok: history() | received?()
  defp call(process_name, request) do
    label = :"$nuntiux.call"
    {:ok, result} = :gen.call(process_name, label, request)
    result
  end

  @spec loop(state) :: no_return
        when state: state(),
             no_return: no_return()
  defp loop(state) do
    process_monitor = state.process_monitor
    process_pid = state.process_pid

    next_state =
      receive do
        {:DOWN, ^process_monitor, :process, ^process_pid, reason} ->
          exit(reason)

        {:"$nuntiux.call", from, request} ->
          :gen.reply(from, handle_call(request, state))
          state

        {:"$nuntiux.cast", :reset_history} ->
          %{state | history: []}

        message ->
          handle_message(message, state)
      end

    loop(next_state)
  end

  @spec handle_call(request, state) :: ok
        when request: request(),
             ok: history() | received?()
  def handle_call(request, state) do
    history = state.history

    case request do
      :history -> Enum.reverse(history)
      {:received?, message} -> Enum.any?(history, &(&1.message == message))
    end
  end

  @spec handle_message(message, state) :: state
        when message: term(),
             state: state()
  defp handle_message(message, state) do
    maybe_passthrough(message, state)
    maybe_add_event(message, state)
  end

  @spec reregister(process_name, target_pid, source_pid) :: ok
        when process_name: Nuntiux.process_name(),
             target_pid: pid(),
             source_pid: pid() | nil,
             ok: :ok
  defp reregister(process_name, target_pid, source_pid \\ nil) do
    Process.unregister(process_name)
    Process.register(target_pid, process_name)
    if is_pid(source_pid), do: Process.put(@mocked_process_key, source_pid)
    :ok
  end

  @spec maybe_passthrough(message, state) :: message | ignore
        when message: term(),
             state: state(),
             ignore: :ignore
  defp maybe_passthrough(message, state) do
    opts = state.opts
    process_pid = state.process_pid

    if Nuntiux.passthrough?(opts),
      do: send(process_pid, message),
      else: :ignore

    # We don't pass messages through, we just ignore them.
    :ignore
  end

  @spec maybe_add_event(message, state) :: state
        when message: term(),
             state: state()
  defp maybe_add_event(message, state) do
    opts = state.opts

    if Nuntiux.history?(opts) do
      {_current_value, state} =
        Map.get_and_update(state, :history, fn history ->
          timestamp = System.system_time()
          {history, [%{timestamp: timestamp, message: message} | history]}
        end)

      state
    else
      state
    end
  end
end
