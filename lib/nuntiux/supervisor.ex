defmodule Nuntiux.Supervisor do
  @moduledoc false
  use DynamicSupervisor

  require Nuntiux

  @supervisor __MODULE__

  @impl DynamicSupervisor
  def init(_start_args) do
    strategy = :one_for_one
    DynamicSupervisor.init(strategy: strategy)
  end

  @spec start_link(start_args) :: ok | error
        when start_args: term(),
             ok: {:ok, pid()},
             error: {:error, term()}
  def start_link(start_args) do
    module = __MODULE__
    name = module
    DynamicSupervisor.start_link(module, start_args, name: name)
  end

  @spec start_mock(process_name, opts) :: ok | error
        when process_name: Nuntiux.process_name(),
             opts: Nuntiux.opts(),
             ok: :ok,
             error: {:error, :not_found}
  def start_mock(process_name, opts) do
    child = Nuntiux.Mocker
    module = child
    function = :start_link
    child_args = [process_name, opts]

    child_spec = %{
      id: child,
      start: {module, function, child_args}
    }

    case DynamicSupervisor.start_child(@supervisor, child_spec) do
      {:ok, _pid} -> :ok
      :ignore -> {:error, :not_found}
    end
  end

  @spec stop_mock(process_name) :: ok | error
        when process_name: Nuntiux.process_name(),
             ok: :ok,
             error: {:error, :not_mocked}
  def stop_mock(process_name) do
    Nuntiux.if_mocked(process_name, fn ->
      mocker_pid = Process.whereis(process_name)
      Nuntiux.Mocker.delete(process_name)
      DynamicSupervisor.terminate_child(@supervisor, mocker_pid)
    end)
  end

  @spec mocked() :: process_names
        when process_names: [Nuntiux.process_name()]
  def mocked do
    type = :worker
    item = :registered_name
    item_list = [item]

    for {_id, pid, ^type, _modules} <- DynamicSupervisor.which_children(@supervisor),
        {^item, process_name} <- Process.info(pid, item_list) do
      process_name
    end
  end
end
