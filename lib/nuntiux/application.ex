defmodule Nuntiux.Application do
  @moduledoc false
  use Application

  @impl Application
  def start(_start_type, start_args) do
    Nuntiux.Supervisor.start_link(start_args)
  end

  @impl Application
  def stop(_state) do
    :ok
  end
end
