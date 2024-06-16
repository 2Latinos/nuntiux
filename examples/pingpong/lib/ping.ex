defmodule Ping do
  def start(:proc) do
    fn -> loop() end
    |> spawn()
    |> Process.register(:ping)
  end

  def start(:mocker) do
    proc_mock_ref =
      :ping
      |> Nuntiux.new!()
      |> Nuntiux.expect(
        :ping,
        fn {int, from} ->
          PingPong.shout_out_to_fibo({int, from})
          Nuntiux.passthrough()
        end
      )

    is_reference(proc_mock_ref) and IO.puts("ping mocked...")
  end

  def loop() do
    receive do
      {int, from} ->
        :timer.sleep(125)
        send(from, {int + 1, :ping})
        loop()
    end
  end
end
