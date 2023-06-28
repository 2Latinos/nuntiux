defmodule NuntiuxTest do
  use ExUnit.Case, async: false
  doctest Nuntiux

  setup do
    {:ok, _modules} = Nuntiux.start()

    plus_oner_pid = spawn(&plus_oner/0)
    plus_oner_name = :plus_oner
    safe_unregister(plus_oner_name)
    Process.register(plus_oner_pid, plus_oner_name)

    echoer_pid = spawn(&echoer/0)
    echoer_name = :echoer
    safe_unregister(echoer_name)
    Process.register(echoer_pid, echoer_name)

    on_exit(:kill_plus_oner_and_echoer, fn ->
      reason = :kill
      safe_unregister(plus_oner_name)
      Process.exit(plus_oner_pid, reason)

      safe_unregister(echoer_name)
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

    test "history is available (and can be checked) for mocked processes", %{
      plus_oner_name: plus_oner_name
    } do
      # If a process is not mocked, Nuntiux returns an error
      {:error, :not_mocked} = Nuntiux.history(plus_oner_name)
      {:error, :not_mocked} = Nuntiux.received?(plus_oner_name, :any_message)

      # We mock it
      :ok = Nuntiux.new(plus_oner_name)

      # Originally the history is empty
      [] = Nuntiux.history(plus_oner_name)
      false = Nuntiux.received?(plus_oner_name, 1)

      # We send a message to it
      2 = send2(plus_oner_name, 1)

      # The message appears in the history
      [%{timestamp: t1, message: m1}] = Nuntiux.history(plus_oner_name)
      true = Nuntiux.received?(plus_oner_name, m1)
      false = Nuntiux.received?(plus_oner_name, 2)

      # We send another message
      3 = send2(plus_oner_name, 2)

      # The message appears in the history
      [%{timestamp: ^t1, message: ^m1}, %{timestamp: t2, message: m2}] =
        plus_oner_name
        |> Nuntiux.history()
        |> Enum.sort(&(&1.timestamp <= &2.timestamp))

      true = t1 < t2
      true = Nuntiux.received?(plus_oner_name, m1)
      true = Nuntiux.received?(plus_oner_name, m2)

      # If we reset the history, it's now empty again
      :ok = Nuntiux.reset_history(plus_oner_name)
      [] = Nuntiux.history(plus_oner_name)
      false = Nuntiux.received?(plus_oner_name, m1)
      false = Nuntiux.received?(plus_oner_name, m2)

      # We send yet another message
      4 = send2(plus_oner_name, 3)
      [%{timestamp: t3, message: m3}] = Nuntiux.history(plus_oner_name)
      false = Nuntiux.received?(plus_oner_name, m1)
      false = Nuntiux.received?(plus_oner_name, m2)
      true = Nuntiux.received?(plus_oner_name, m3)
      true = t2 < t3
    end

    test "history is not available under certain conditions", %{plus_oner_name: plus_oner_name} do
      :ok = Nuntiux.new(plus_oner_name, history?: false)

      # Originally the history is empty
      [] = Nuntiux.history(plus_oner_name)
      false = Nuntiux.received?(plus_oner_name, 1)

      # We send a message to it
      2 = send2(plus_oner_name, 1)

      # The history is still empty
      [] = Nuntiux.history(plus_oner_name)
      false = Nuntiux.received?(plus_oner_name, 1)

      # Resetting the history has no effect
      :ok = Nuntiux.reset_history(plus_oner_name)
      [] = Nuntiux.history(plus_oner_name)
      false = Nuntiux.received?(plus_oner_name, 1)

      # We send another message to it
      3 = send2(plus_oner_name, 2)

      # The history is still empty
      [] = Nuntiux.history(plus_oner_name)
      false = Nuntiux.received?(plus_oner_name, 1)
      false = Nuntiux.received?(plus_oner_name, 2)
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

  defp safe_unregister(name) do
    Process.unregister(name)
  rescue
    _error -> :ok
  end
end
