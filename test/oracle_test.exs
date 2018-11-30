defmodule OracleTest do
  use ExUnit.Case
  alias Oracle.Modifier.Track
  doctest Oracle

  test "creates an 'Oracle.Vision'" do
    vision = Oracle.consult(TestOracle)
    assert vision.oracle == {:some, TestOracle}
    assert vision.key == :*
    assert vision.status == :consulting
  end

  test "creates and subscribes an 'Oracle.Vision'" do
    {:ok, name} =
      Oracle.consult(TestOracle)
      |> Oracle.Vision.track()
      |> Oracle.Vision.interprete(fn state ->
        assert state == :state
      end)

    assert :ok == Oracle.reveal(TestOracle, :state)

    Track.fetch_meta_data(name)
    |> OptionEx.unwrap!()
    |> Map.fetch!(:proc_count)
    |> Kernel.==(1)
    |> assert()
  end

  test "creates an 'Oracle.Vision' and subscribes it by key" do
    {:ok, name} =
      Oracle.consult(TestOracle, :hello)
      |> Oracle.Vision.track()
      |> Oracle.Vision.interprete(fn
        :world ->
          assert true

        _ ->
          assert false
      end)

    assert :ok == Oracle.reveal(TestOracle, :world, :hello)
    assert :ok == Oracle.reveal(TestOracle, :no_proc, :hi)
    assert :ok == Oracle.reveal(TestOracle, :no_proc)

    Track.fetch_meta_data(name)
    |> OptionEx.unwrap!()
    |> Map.fetch!(:proc_count)
    |> Kernel.==(1)
    |> assert()
  end
end
