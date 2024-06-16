defmodule Pong do
  def start(:proc) do
    fn -> loop() end
    |> spawn()
    |> Process.register(:pong)
  end

  def start(:mocker) do
    proc_mock_ref =
      :pong
      |> Nuntiux.new!()
      |> Nuntiux.expect(
        :pong,
        fn {int, from} ->
          PingPong.shout_out_to_fibo({int, from})
          Nuntiux.passthrough()
        end
      )

    is_reference(proc_mock_ref) and IO.puts("pong mocked...")
  end

  def loop() do
    receive do
      {int, from} ->
        :timer.sleep(125)
        send(from, {int + 1, :pong})
        loop()
    end
  end
end
