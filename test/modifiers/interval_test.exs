defmodule Oracle.Modifier.IntervalTest do
  use ExUnit.Case
  doctest Oracle.Modifier.Interval

  test "creates an 'Oracle.Vision', which splits an event into multiple events spread out over time" do
    # ms
    interval = 10
    limit = 5
    me = self()

    {:ok, _} =
      Oracle.consult(TestOracle, :interval_number)
      |> Oracle.Vision.interval(interval, limit)
      |> Oracle.Vision.map(fn %{value: value} -> {:ok, value} end)
      |> Oracle.Vision.map(&{:ok, &1 + 1})
      |> Oracle.Vision.interprete(fn value -> send(me, {:proc, value}) end)

    assert :ok == Oracle.reveal(TestOracle, 0, :interval_number)

    Enum.each(1..5, fn n ->
      receive do
        {:proc, value} ->
          assert value == n

        _ ->
          assert false
      end
    end)

    assert true
  end
end
