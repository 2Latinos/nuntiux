defmodule Nuntiux.Mocker do
  @moduledoc """
  A process that mocks another one.
  """

  @typep state :: %{
           process_name: Nuntiux.process_name(),
           process_pid: pid(),
           process_monitor: reference(),
           opts: Nuntiux.opts()
         }

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
  def delete(_process_name) do
    :ok
  end

  @doc false
  @spec init(process_name, process_pid, opts) :: no_return
        when process_name: Nuntiux.process_name(),
             process_pid: pid(),
             opts: Nuntiux.opts(),
             no_return: no_return()
  def init(process_name, process_pid, opts) do
    self = self()
    process_monitor = Process.monitor(process_pid)
    Process.unregister(process_name)
    Process.register(self, process_name)
    :proc_lib.init_ack({:ok, self})

    loop(%{
      process_name: process_name,
      process_pid: process_pid,
      process_monitor: process_monitor,
      opts: opts
    })
  end

  @spec loop(state) :: no_return
        when state: state(),
             no_return: no_return()
  defp loop(state) do
    process_monitor = state.process_monitor
    process_pid = state.process_pid
    passthrough? = Nuntiux.passthrough?(state.opts)

    receive do
      {:DOWN, ^process_monitor, :process, ^process_pid, reason} ->
        exit(reason)

      message ->
        maybe_passthrough(passthrough?, process_pid, message)
    end

    loop(state)
  end

  @spec maybe_passthrough(passthrough?, process_pid, message) :: message | ignore
        when passthrough?: boolean(),
             process_pid: pid(),
             message: any(),
             ignore: :ignore
  defp maybe_passthrough(false = _passthrough?, _process_pid, _message) do
    # We don't pass messages through, we just ignore them.
    :ignore
  end

  defp maybe_passthrough(true = _passthrough?, process_pid, message) do
    # We pass messages through.
    send(process_pid, message)
  end
end
