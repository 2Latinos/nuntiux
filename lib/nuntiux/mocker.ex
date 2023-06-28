defmodule Nuntiux.Mocker do
  @moduledoc """
  A process that mocks another one.
  """

  @type opts :: [{:passthrough?, boolean()} | {:history?, boolean()}]
  @type history :: [event()]
  @type received? :: boolean()
  @type event :: %{timestamp: integer(), message: term()}
  @type expect_fun :: (... -> term())
  @type expect_name :: atom()
  @type expect_id :: reference() | expect_name()
  @type expects :: %{expect_id() => expect_fun()}

  @typep state :: %{
           process_name: Nuntiux.process_name(),
           process_pid: pid(),
           process_monitor: reference(),
           history: history(),
           opts: opts(),
           expects: expects()
         }
  @typep request_call ::
           :history
           | {:received?, message :: term()}
           | :expects
  @typep result_call ::
           history()
           | received?()
           | expects()
  @typep request_cast ::
           :reset_history
           | {:delete, expect_id()}
           | {:expect, expect_id(), expect_fun()}

  @mocked_process_key :"#{__MODULE__}.mocked_process"
  @default_history []
  @default_opts [{:passthrough?, true}, {:history?, true}]
  @default_expects %{}
  @default_state %{
    history: @default_history,
    opts: @default_opts,
    expects: @default_expects
  }

  @doc false
  @spec start_link(process_name, opts) :: ok | ignore
        when process_name: Nuntiux.process_name(),
             opts: opts(),
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
  @spec expect(process_name, expect_name, expect_fun) :: ok
        when process_name: Nuntiux.process_name(),
             expect_name: nil | expect_name(),
             expect_fun: expect_fun(),
             ok: expect_id()
  def expect(process_name, expect_name, expect_fun) do
    expect_id =
      if is_nil(expect_name),
        do: make_ref(),
        else: expect_name

    request = {:expect, expect_id, expect_fun}
    cast(process_name, request)
    expect_id
  end

  @doc false
  @spec expects(process_name) :: ok
        when process_name: Nuntiux.process_name(),
             ok: expects()
  def expects(process_name) do
    request = :expects
    call(process_name, request)
  end

  @doc false
  @spec delete(process_name, expect_id) :: ok
        when process_name: Nuntiux.process_name(),
             expect_id: nil | expect_id(),
             ok: :ok
  def delete(process_name, expect_id \\ nil) do
    if is_nil(expect_id) do
      process_pid = mocked_process(process_name)
      reregister(process_name, process_pid)
    else
      request = {:delete, expect_id}
      cast(process_name, request)
    end
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
    request = :reset_history
    cast(process_name, request)
  end

  @doc false
  @spec init(process_name, process_pid, opts) :: no_return
        when process_name: Nuntiux.process_name(),
             process_pid: pid(),
             opts: opts(),
             no_return: no_return()
  def init(process_name, process_pid, opts) do
    mocker_pid = self()
    process_monitor = Process.monitor(process_pid)
    reregister(process_name, mocker_pid, process_pid)
    :proc_lib.init_ack({:ok, mocker_pid})

    opts = Keyword.merge(@default_opts, opts)

    state =
      Map.merge(@default_state, %{
        process_name: process_name,
        process_pid: process_pid,
        process_monitor: process_monitor,
        opts: opts
      })

    loop(state)
  end

  @spec call(process_name, request) :: ok
        when process_name: Nuntiux.process_name(),
             request: request_call(),
             ok: result_call()
  defp call(process_name, request) do
    label = :"$nuntiux.call"
    {:ok, result} = :gen.call(process_name, label, request)
    result
  end

  @spec cast(process_name, request) :: ok
        when process_name: Nuntiux.process_name(),
             request: request_cast(),
             ok: :ok
  defp cast(process_name, request) do
    label = :"$nuntiux.cast"
    send(process_name, {label, request})
    :ok
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
          handled_call = handle_call(request, state)
          :gen.reply(from, handled_call)
          state

        {:"$nuntiux.cast", request} ->
          handle_cast(request, state)

        message ->
          handle_message(message, state)
      end

    loop(next_state)
  end

  @spec handle_call(request, state) :: ok
        when request: request_call(),
             ok: result_call()
  defp handle_call(request, state) do
    case request do
      :history -> Enum.reverse(state.history)
      {:received?, message} -> Enum.any?(state.history, &(&1.message == message))
      :expects -> state.expects
    end
  end

  @spec handle_cast(request, state) :: ok
        when request: request_cast(),
             state: state(),
             ok: state
  defp handle_cast(request, state) do
    case request do
      :reset_history ->
        %{state | history: []}

      {:delete, expect_id} ->
        %{state | expects: Map.delete(state.expects, expect_id)}

      {:expect, expect_id, expect_fun} ->
        %{state | expects: Map.put(state.expects, expect_id, expect_fun)}
    end
  end

  @spec passthrough?(opts) :: passthrough?
        when opts: opts(),
             passthrough?: boolean()
  defp passthrough?(opts) do
    opts[:passthrough?]
  end

  @spec history?(opts) :: history?
        when opts: opts(),
             history?: boolean()
  defp history?(opts) do
    opts[:history?]
  end

  @spec handle_message(message, state) :: state
        when message: term(),
             state: state()
  defp handle_message(message, state) do
    expects_ran = maybe_run_expects(message, state.expects)
    expects_ran or maybe_passthrough(message, state)
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

  @spec maybe_run_expects(message, expects) :: ok
        when message: term(),
             expects: expects(),
             ok: boolean()
  defp maybe_run_expects(message, expects) do
    Enum.reduce(
      expects,
      _expects_ran = false,
      fn
        {_expect_id, _expect_fun}, true = _done ->
          true

        {_expect_id, expect_fun}, false ->
          try do
            expect_fun.(message)
            true
          catch
            :error, :function_clause ->
              false
          end
      end
    )
  end

  @spec maybe_passthrough(message, state) :: message | ignore
        when message: term(),
             state: state(),
             ignore: :ignore
  defp maybe_passthrough(message, state) do
    opts = state.opts
    process_pid = state.process_pid

    if passthrough?(opts),
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

    if history?(opts) do
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
