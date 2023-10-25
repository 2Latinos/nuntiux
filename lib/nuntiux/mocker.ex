defmodule Nuntiux.Mocker do
  @moduledoc """
  A process that mocks another one.
  """

  @type opts :: %{
          optional(:passthrough?) => boolean(),
          optional(:history?) => boolean()
        }
  @type history :: [event()]
  @type event :: %{
          timestamp: integer(),
          message: term(),
          mocked?: boolean(),
          passed_through?: boolean()
        }
  @type expect_fun :: (message: term() -> expect_fun_result())
  @type expect_name :: atom()
  @type expect_id :: reference() | expect_name()
  @type expects :: %{expect_id() => expect_fun()}

  @default_history []
  @default_opts %{
    passthrough?: true,
    history?: true
  }
  @default_expects %{}
  @default_state %{
    history: @default_history,
    opts: @default_opts,
    expects: @default_expects
  }

  @label_mocked_process :"#{__MODULE__}.mocked_process"
  @label_call :"#{__MODULE__}.call"
  @label_cast :"#{__MODULE__}.cast"
  @label_process_pid :"#{__MODULE__}.process_pid"
  @label_current_message :"#{__MODULE__}.current_message"
  @label_match :"#{__MODULE__}.match"
  @label_nomatch :"#{__MODULE__}.nomatch"
  @label_passed_through :"#{__MODULE__}.passed_through"

  @typep received? :: boolean()
  @typep expect_fun_result :: term()
  @typep state :: %{
           process_name: Nuntiux.process_name(),
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
  @typep expects_matched :: unquote(@label_nomatch) | {unquote(@label_match), expect_fun_result()}

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
  @spec expect(process_name, expect_name, expect_fun) :: expect_id
        when process_name: Nuntiux.process_name(),
             expect_name: nil | expect_name(),
             expect_fun: expect_fun(),
             expect_id: expect_id()
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
  @spec expects(process_name) :: expects
        when process_name: Nuntiux.process_name(),
             expects: expects()
  def expects(process_name) do
    request = :expects
    call(process_name, request)
  end

  @doc false
  @spec delete(process_name, expect_id) :: ok
        when process_name: Nuntiux.process_name(),
             expect_id: nil | expect_id(),
             ok: :ok
  def delete(process_name, expect_id \\ nil)

  def delete(process_name, nil = _expect_id) do
    process_pid = mocked_process(process_name)
    reregister(process_name, process_pid)
  end

  def delete(process_name, expect_id) do
    request = {:delete, expect_id}
    cast(process_name, request)
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

    Keyword.get(dict, @label_mocked_process)
  end

  @doc false
  @spec passthrough() :: ok
        when ok: :ok
  def passthrough do
    message = current_message()
    passthrough(message)
  end

  @doc false
  @spec passthrough(message) :: ok
        when message: term(),
             ok: :ok
  def passthrough(message) do
    process_pid = process_pid()
    passed_through?(true)
    send(process_pid, message)
    :ok
  end

  @doc false
  @spec mocked_process() :: pid
        when pid: pid()
  def mocked_process do
    process_pid()
  end

  @doc false
  @spec history(process_name) :: history
        when process_name: Nuntiux.process_name(),
             history: history()
  def history(process_name) do
    request = :history
    call(process_name, request)
  end

  @doc false
  @spec received?(process_name, message) :: received?
        when process_name: Nuntiux.process_name(),
             message: term(),
             received?: received?()
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

    opts = Map.merge(@default_opts, opts)

    state =
      Map.merge(@default_state, %{
        process_name: process_name,
        process_monitor: process_monitor,
        opts: opts
      })

    process_pid(process_pid)
    loop(state)
  end

  @doc false
  @spec call(process_name, request) :: result_call
        when process_name: Nuntiux.process_name(),
             request: request_call(),
             result_call: result_call()
  defp call(process_name, request) do
    {:ok, result} = :gen.call(process_name, @label_call, request)
    result
  end

  @doc false
  @spec cast(process_name, request) :: ok
        when process_name: Nuntiux.process_name(),
             request: request_cast(),
             ok: :ok
  defp cast(process_name, request) do
    send(process_name, {@label_cast, request})
    :ok
  end

  @doc false
  @spec loop(state) :: no_return
        when state: state(),
             no_return: no_return()
  defp loop(state) do
    process_monitor = state.process_monitor
    process_pid = process_pid()

    next_state =
      receive do
        {:DOWN, ^process_monitor, :process, ^process_pid, reason} ->
          exit(reason)

        {@label_call, from, request} ->
          handled_call = handle_call(request, state)
          :gen.reply(from, handled_call)
          state

        {@label_cast, request} ->
          handle_cast(request, state)

        message ->
          handle_message(message, state)
      end

    loop(next_state)
  end

  @doc false
  @spec handle_call(request, state) :: result_call
        when request: request_call(),
             state: state(),
             result_call: result_call()
  defp handle_call(:history, state) do
    Enum.reverse(state.history)
  end

  defp handle_call({:received?, message}, state) do
    Enum.any?(state.history, &(&1.message == message))
  end

  defp handle_call(:expects, state) do
    state.expects
  end

  @doc false
  @spec handle_cast(request, state) :: updated_state
        when request: request_cast(),
             state: state(),
             updated_state: state()
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

  @doc false
  @spec handle_message(message, state) :: updated_state
        when message: term(),
             state: state(),
             updated_state: state()
  defp handle_message(message, state) do
    current_message(message)
    passed_through?(false)
    expects_matched = maybe_run_expects(message, state.expects)
    maybe_passthrough(message, expects_matched, state.opts)
    maybe_add_event(message, expects_matched, state)
  end

  @doc false
  @spec reregister(process_name, target_pid, source_pid) :: ok
        when process_name: Nuntiux.process_name(),
             target_pid: pid(),
             source_pid: pid() | nil,
             ok: :ok
  defp reregister(process_name, target_pid, source_pid \\ nil) do
    Process.unregister(process_name)
    Process.register(target_pid, process_name)
    if is_pid(source_pid), do: Process.put(@label_mocked_process, source_pid)
    :ok
  end

  @doc false
  @spec maybe_run_expects(message, expects) :: expects_matched
        when message: term(),
             expects: expects(),
             expects_matched: expects_matched()
  defp maybe_run_expects(message, expects) do
    Enum.reduce_while(
      expects,
      @label_nomatch,
      fn
        {_expect_id, _expect_fun}, {@label_match, _matched} = result ->
          {:halt, result}

        {_expect_id, expect_fun}, @label_nomatch ->
          try do
            {:cont, {@label_match, expect_fun.(message)}}
          catch
            :error, :function_clause ->
              {:cont, @label_nomatch}
          end
      end
    )
  end

  @doc false
  @spec maybe_passthrough(message, expects_matched, opts) :: ok
        when message: term(),
             expects_matched: expects_matched(),
             opts: opts(),
             ok: :ok
  defp maybe_passthrough(_message, {@label_match, _expect_fun_result}, _opts) do
    :ok
  end

  defp maybe_passthrough(_message, _expects_matched, %{passthrough?: false}) do
    :ok
  end

  defp maybe_passthrough(message, _expects_matched, _opts) do
    passthrough(message)
  end

  @doc false
  @spec maybe_add_event(message, expects_matched, state) :: updated_state
        when message: term(),
             expects_matched: expects_matched(),
             state: state(),
             updated_state: state()
  defp maybe_add_event(_message, _expects_matched, %{opts: %{history?: false}} = state) do
    state
  end

  defp maybe_add_event(message, expects_matched, state) do
    {_current_value, state} =
      Map.get_and_update(state, :history, fn history ->
        timestamp = System.system_time()
        mocked? = expects_matched != @label_nomatch
        passed_through? = passed_through?()

        {history,
         [
           %{
             timestamp: timestamp,
             message: message,
             mocked?: mocked?,
             passed_through?: passed_through?
           }
           | history
         ]}
      end)

    state
  end

  @doc false
  @spec process_pid(process_pid) :: ok
        when process_pid: pid(),
             ok: :ok
  defp process_pid(process_pid) do
    nil = Process.put(@label_process_pid, process_pid)
    :ok
  end

  @doc false
  @spec process_pid() :: pid
        when pid: pid()
  defp process_pid do
    Process.get(@label_process_pid)
  end

  @doc false
  @spec current_message(message) :: ok
        when message: term(),
             ok: :ok
  defp current_message(message) do
    _previous_message = Process.put(@label_current_message, message)
    :ok
  end

  @doc false
  @spec current_message() :: message
        when message: term()
  defp current_message do
    Process.get(@label_current_message)
  end

  @doc false
  @spec passed_through?(new_passed_through?) :: old_passed_through?
        when new_passed_through?: boolean(),
             old_passed_through?: boolean()
  defp passed_through?(passed_through?) do
    Process.put(@label_passed_through, passed_through?)
  end

  @doc false
  @spec passed_through?() :: passed_through?
        when passed_through?: boolean()
  defp passed_through? do
    Process.get(@label_passed_through)
  end
end
