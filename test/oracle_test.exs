defmodule OracleTest do
  use ExUnit.Case
  doctest Oracle

  test "creates an 'Oracle.Vision'" do
    vision = Oracle.consult(TestOracle)
    assert vision.oracle == {:some, TestOracle}
    assert vision.key == :*
    assert vision.status == :consulting
  end

  test "creates and subscribes an 'Oracle.Vision'" do
    Oracle.consult(TestOracle)
    |> Oracle.Vision.interprete(fn state ->
      IO.inspect(state, label: "callback procced")
      assert state == :state
    end)

    assert :ok == Oracle.reveal(TestOracle, :state)
  end

  test "creates an 'Oracle.Vision' and subscribes it by key" do
    Oracle.consult(TestOracle, :hello)
    |> Oracle.Vision.interprete(fn
      :world ->
        IO.inspect("callback procced")
        assert true
      _ -> assert false
    end)

    assert :ok == Oracle.reveal(TestOracle, :world, :hello)
    assert :ok == Oracle.reveal(TestOracle, :no_proc, :hi)
    assert :ok == Oracle.reveal(TestOracle, :no_proc)
  end

end
