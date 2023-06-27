defmodule NuntiuxTest do
  use ExUnit.Case, async: false
  doctest Nuntiux

  setup do
    {:ok, _modules} = Nuntiux.start()

    plus_oner_pid = spawn(&plus_oner/0)
    plus_oner_name = :plus_oner
    Process.register(plus_oner_pid, plus_oner_name)

    echoer_pid = spawn(&echoer/0)
    echoer_name = :echoer
    Process.register(echoer_pid, echoer_name)

    on_exit(:kill_plus_oner_and_echoer, fn ->
      reason = :kill

      Process.unregister(plus_oner_name)
      Process.exit(plus_oner_pid, reason)

      Process.unregister(echoer_name)
      Process.exit(echoer_pid, reason)

      # Give it time to process the exit
      :timer.sleep(1)
    end)

    %{
      plus_oner_pid: plus_oner_pid,
      plus_oner_name: plus_oner_name,
      echoer_pid: echoer_pid,
      echoer_name: echoer_name
    }
  end

  describe "Nuntiux" do
    test "starts and stops" do
      application = Nuntiux.application()

      :ok = Nuntiux.stop()

      {:ok, apps} = Nuntiux.start()
      [^application | _other] = apps
      no_modules = []
      {:ok, ^no_modules} = Nuntiux.start()
      :ok = Nuntiux.stop()

      {:ok, [^application]} = Nuntiux.start()
      :ok = Nuntiux.stop()
    end

    test "has a practically invisible default mock", %{plus_oner_name: plus_oner_name} do
      # Original state
      2 = send2(plus_oner_name, 1)

      # We mock the process but we don't handle any message
      :ok = Nuntiux.new(plus_oner_name)

      # So, nothing changes
      2 = send2(plus_oner_name, 1)
    end

    test "raises an error if the process to mock doesn't exist" do
      {:error, :not_found} = Nuntiux.new(:non_existing_process)
    end

    test "processes can be unmocked", %{
      plus_oner_pid: plus_oner_pid,
      plus_oner_name: plus_oner_name
    } do
      # Trying to remove a non-existent mock, fails
      {:error, :not_mocked} = Nuntiux.delete(plus_oner_name)
      {:error, :not_mocked} = Nuntiux.delete(:doesnt_even_exist)

      # Mocking it and later deleting the mock
      # restores the registered name to the mocked process
      :ok = Nuntiux.new(plus_oner_name)
      refute Process.whereis(plus_oner_name) == plus_oner_pid
      :ok = Nuntiux.delete(plus_oner_name)
      ^plus_oner_pid = Process.whereis(plus_oner_name)

      # And the process is, again, not mocked
      {:error, :not_mocked} = Nuntiux.delete(plus_oner_name)
    end

    test "users can get the pid of a mocked process and the list of all mocked processes", %{
      plus_oner_pid: plus_oner_pid,
      plus_oner_name: plus_oner_name,
      echoer_name: echoer_name
    } do
      # Initially, no mocked processes
      [] = Nuntiux.mocked()

      # If process is not mocked, you can't find the original process
      {:error, :not_mocked} = Nuntiux.mocked_process(plus_oner_name)

      # Once you mock it, you can get the original PID
      :ok = Nuntiux.new(plus_oner_name)
      refute Process.whereis(plus_oner_name) == plus_oner_pid

      # And the process appears in the list of mocked processes
      ^plus_oner_pid = Nuntiux.mocked_process(plus_oner_name)
      [^plus_oner_name] = Nuntiux.mocked()

      # If you mock two processes, they both appear in the list
      :ok = Nuntiux.new(echoer_name)
      [^echoer_name, ^plus_oner_name] = Enum.sort(Nuntiux.mocked())

      # If you remove a mock, it goes away from the list
      :ok = Nuntiux.delete(plus_oner_name)
      [^echoer_name] = Nuntiux.mocked()
    end
  end

  defp send2(dest, msg) do
    caller = self()
    ref = make_ref()
    send(dest, {caller, ref, msg})

    receive do
      {^ref, result} ->
        result
    after
      1000 ->
        exit(%{
          reason: :timeout,
          process: dest,
          message: msg
        })
    end
  end

  defp plus_oner do
    # A basic plus oner
    receive do
      {caller, ref, a_number} ->
        send(caller, {ref, a_number + 1})
    end

    plus_oner()
  end

  defp echoer do
    receive do
      {caller, ref, a_message} ->
        send(caller, {ref, a_message})
    end

    echoer()
  end
end
