defmodule Nuntiux.Supervisor do
  @moduledoc false
  use DynamicSupervisor

  @supervisor __MODULE__

  @impl DynamicSupervisor
  def init(start_args) do
    strategy = :one_for_one
    extra_arguments = [start_args]
    DynamicSupervisor.init(strategy: strategy, extra_arguments: extra_arguments)
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
    child_args = [process_name, opts]
    child_spec = {child, child_args}

    case DynamicSupervisor.start_child(@supervisor, child_spec) do
      {:ok, _other} ->
        :ok

      {:error, :not_found} = error ->
        error
    end
  end

  @spec stop_mock(process_name) :: ok | error
        when process_name: Nuntiux.process_name(),
             ok: :ok,
             error: {:error, :not_mocked}
  def stop_mock(process_name) do
    if process_name in mocked() do
      mocker_pid = Process.whereis(process_name)
      Nuntiux.Mocker.delete(process_name)
      DynamicSupervisor.terminate_child(@supervisor, mocker_pid)
    else
      {:error, :not_mocked}
    end
  end

  @spec mocked() :: process_names
        when process_names: [Nuntiux.process_name()]
  defp mocked do
    type = :worker
    item = :registered_name
    item_list = [item]

    for {_id, pid, ^type, _modules} <- DynamicSupervisor.which_children(@supervisor),
        {^item, process_name} <- Process.info(pid, item_list) do
      process_name
    end
  end
end
