defmodule NuntiuxTest do
  use ExUnit.Case
  doctest Nuntiux

  @mocked :mocked

  setup do
    Nuntiux.start()

    pid = spawn(&mocked/0)
    name = @mocked
    Process.register(pid, name)

    on_exit(:kill_mocked, fn ->
      reason = :kill
      Process.unregister(name)
      Process.exit(pid, reason)
    end)

    [mock_pid: pid]
  end

  describe "Nuntiux" do
    test "starts and stops" do
      application = Nuntiux.application()

      Nuntiux.stop()

      {:ok, apps} = Nuntiux.start()
      [^application | _other] = apps
      no_modules = []
      {:ok, ^no_modules} = Nuntiux.start()
      Nuntiux.stop()

      {:ok, [^application]} = Nuntiux.start()
      Nuntiux.stop()
    end

    test "has a practically invisible default mock" do
      # Original state
      2 = add_one(1)

      # We mock the process but we don't handle any message
      Nuntiux.new(@mocked)

      # So, nothing changes
      2 = add_one(1)
    end

    test "raises an error if the process to mock doesn't exist" do
      {:error, :not_found} = Nuntiux.new(:non_existing_process)
    end
  end

  def mocked do
    # A basic plus oner
    receive do
      {caller, ref, a_number} ->
        send(caller, {ref, a_number + 1})
    end

    mocked()
  end

  defp add_one(a_number) do
    caller = self()
    ref = make_ref()
    dest = @mocked
    send(dest, {caller, ref, a_number})

    receive do
      {^ref, result} ->
        result
    after
      2500 ->
        exit(%{
          reason: :timeout,
          parameter: a_number
        })
    end
  end
end
