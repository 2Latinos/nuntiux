defmodule PingPong do
  # We have two processes (:ping and :pong) sending integers to each other.
  # Every time one of them gets an integer belonging to the Fibonacci sequence
  # their mocker will output `<from>: <int>`, where `<from>` is either `ping`
  # or `pong` and `<int>` is the integer belonging to the sequence.

  def go() do
    Ping.start(:proc)
    Pong.start(:proc)

    Ping.start(:mocker)
    Pong.start(:mocker)

    send(:ping, {1, :pong})
    :ok
  end

  # Auxiliary stuff.

  def shout_out_to_fibo({int, from}) do
    if is_fibonacci(int) do
      IO.puts("#{from}: #{int}")
    end

    :ok
  end

  def is_fibonacci(n) when n >= 0 do
    is_fibonacci(n, 0, 1)
  end

  def is_fibonacci(n, a, _) when n == a do
    true
  end

  def is_fibonacci(n, a, _b) when n < a do
    false
  end

  def is_fibonacci(n, a, b) do
    is_fibonacci(n, b, a + b)
  end
end
