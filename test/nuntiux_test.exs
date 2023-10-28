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

    test "returns an error if the process to mock doesn't exist" do
      {:error, :not_found} = Nuntiux.new(:non_existing_process)
    end

    test "new!/1 raises an exception if the process to mock doesn't exist" do
      assert_raise(Nuntiux.Exception, ~r/^Process .* not found\.$/, fn ->
        Nuntiux.new!(:non_existing_process)
      end)
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
      :ok = Nuntiux.new(plus_oner_name, %{history?: false})

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

    test "allows pipelining for more concise code", %{plus_oner_name: plus_oner_name} do
      ref =
        plus_oner_name
        |> Nuntiux.new!()
        |> Nuntiux.expect!(fn _in -> :ok end)
        |> Nuntiux.expect(fn _in -> :ok end)

      true = is_reference(ref)
    end

    test "expect!/2 raises an exception if the target process is not mocked" do
      assert_raise(Nuntiux.Exception, ~r/^Process .* not mocked\.$/, fn ->
        Nuntiux.expect!(:non_existing_process, fn -> :irrelevant end)
      end)
    end

    test "allows defining/consulting expectations", %{plus_oner_name: plus_oner_name} do
      expects = fn -> Nuntiux.expects(plus_oner_name) end
      :ok = Nuntiux.new(plus_oner_name)

      # Add (unnamed) expectations...
      ref1 = Nuntiux.expect(plus_oner_name, fn _in -> :ok end)
      true = is_reference(ref1)
      ref2 = Nuntiux.expect(plus_oner_name, fn _in -> :ok end)
      true = is_reference(ref2)

      # ... and (only known) references in expectations
      2 = map_size(expects.())
      [^ref2] = Map.keys(expects.()) -- [ref1]

      # Now add (named) expectations...
      :named_exp1 = Nuntiux.expect(plus_oner_name, :named_exp1, fn _in -> :ok end)

      # ... and check they're there
      3 = map_size(expects.())
      [:named_exp1] = Map.keys(expects.()) -- [ref1, ref2]

      # ... and that using the same name overwrites existing expectations
      :named_exp1 = Nuntiux.expect(plus_oner_name, :named_exp1, fn _in -> :ok end)
      [:named_exp1] = Map.keys(expects.()) -- [ref1, ref2]

      # ... though different names don't
      fun_named_exp2 = fn _in -> :ok end
      :named_exp2 = Nuntiux.expect(plus_oner_name, :named_exp2, fun_named_exp2)
      4 = map_size(expects.())
      [:named_exp2] = Map.keys(expects.()) -- [ref1, ref2, :named_exp1]

      # Let's now delete an expectation...
      # It was here...
      {:ok, _expects_ref1} = Map.fetch(expects.(), ref1)
      :ok = Nuntiux.delete(plus_oner_name, ref1)
      # ... and it's not anymore
      :error = Map.fetch(expects.(), ref1)

      # ... and another one
      # It was here...
      {:ok, _expects_ref2} = Map.fetch(expects.(), ref2)
      :ok = Nuntiux.delete(plus_oner_name, ref2)
      # ... and it's not anymore
      :error = Map.fetch(expects.(), ref2)

      # ... and another one
      # It was here...
      {:ok, _expects_named_exp1} = Map.fetch(expects.(), :named_exp1)
      :ok = Nuntiux.delete(plus_oner_name, :named_exp1)
      # ... and it's not anymore
      :error = Map.fetch(expects.(), :named_exp1)

      # named_exp2 is still there (with its function)
      1 = map_size(expects.())
      %{named_exp2: _fun} = expects.()
    end

    test "allows changing behaviour based on expectations", %{echoer_name: echoer_name} do
      :ok = Nuntiux.new(echoer_name, %{passthrough?: false})
      self = self()
      boomerang = :boomerang
      kylie = :kylie
      # Have the expectation send a message back to us
      _expectid1 =
        Nuntiux.expect(echoer_name, :boom_echo, fn ^boomerang = m -> send(self, {:echoed, m}) end)

      _expectid2 =
        Nuntiux.expect(echoer_name, :kyli_echo, fn ^kylie = m -> send(self, {:echoed, m}) end)

      send(echoer_name, boomerang)

      receive do
        {:echoed, ^boomerang} ->
          [%{mocked?: true, passed_through?: false}] = Nuntiux.history(echoer_name)
          :ok
      after
        250 ->
          raise "timeout"
      end

      # Check if a nonmatching expectation would also work
      send(echoer_name, :unknown)

      :ok =
        receive do
          _something ->
            :ignored
        after
          250 ->
            [_, %{mocked?: false, passed_through?: false}] = Nuntiux.history(echoer_name)
            :ok
        end
    end

    test "mocked processes keep their source pid", %{
      echoer_pid: echoer_pid,
      echoer_name: echoer_name
    } do
      boom = :boom
      from_mocked = :from_mocked
      self = self()

      :ok = Nuntiux.new(echoer_name)

      _expect_id =
        Nuntiux.expect(
          echoer_name,
          fn ^boom ->
            ^echoer_pid = Nuntiux.mocked_process()
            send(self, from_mocked)
          end
        )

      # We send the mocked process a message
      send(echoer_name, boom)

      receive do
        ^from_mocked ->
          [%{mocked?: true, passed_through?: false}] = Nuntiux.history(echoer_name)
          # ... and if we got here we have echo's pid inside the expectation
          :ok
      after
        250 ->
          raise "timeout"
      end
    end

    test "allows passing a message down to the original process", %{echoer_name: echoer_name} do
      back = :back
      :ok = Nuntiux.new(echoer_name)

      # We pass a message to the mocked process
      _expect_id = Nuntiux.expect(echoer_name, fn _anything -> Nuntiux.passthrough() end)
      # ... and since it's an echo process, we get it back
      send2(echoer_name, back)

      receive do
        {_ref, ^back} ->
          # ... but not from the pass through
          raise "received"
      after
        250 ->
          # The last message was explicitly passed through
          [%{mocked?: true, passed_through?: true}] = Nuntiux.history(echoer_name)
          :ok
      end
    end

    test "allows passing a specific message, inside the expectation, down to the original process",
         %{echoer_name: echoer_name} do
      message = :message
      :ok = Nuntiux.new(echoer_name, %{passthrough?: false})

      _expect_id =
        Nuntiux.expect(
          echoer_name,
          fn ^message ->
            # We pass a specific message to the mocked process
            Nuntiux.passthrough({self(), make_ref(), message})

            receive do
              {_ref, ^message} ->
                # ... and then we get it back (inside the process)
                :ok
            after
              250 ->
                raise "timeout"
            end
          end
        )

      send(echoer_name, message)

      # And now, for a different test...
      new_message = :new_message
      self = self()

      _expect_id =
        Nuntiux.expect(
          echoer_name,
          fn ^new_message ->
            # We pass another specific message to the mocked process
            mocked = Nuntiux.mocked_process()
            Nuntiux.passthrough({self, make_ref(), {new_message, mocked}})
          end
        )

      send(echoer_name, new_message)

      mocked = Nuntiux.mocked_process(echoer_name)

      receive do
        {_ref, {^new_message, ^mocked}} ->
          # ... and we get it back (from the mocked process - notice _mocked_)
          [%{mocked?: true, passed_through?: true}, %{mocked?: true, passed_through?: true}] =
            Nuntiux.history(echoer_name)
      after
        250 ->
          raise "not received"
      end
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
