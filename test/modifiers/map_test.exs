defmodule Oracle.Modifier.MapTest do
  use ExUnit.Case
  doctest Oracle.Modifier.Map

  test "creates an 'Oracle.Vision', subscribes it by key, and modifies the events content on proc" do
    {:ok, name} =
      Oracle.consult(TestOracle, :number)
      |> Oracle.Vision.map(&{:ok, &1 * 2})
      |> Oracle.Vision.interprete(& &1)

    assert :ok == Oracle.reveal(TestOracle, 1, :number)

    %{value: value} = GenServer.call(name, :fetch)
    assert value == 2

    assert :ok == Oracle.reveal(TestOracle, 2, :number)

    %{value: value} = GenServer.call(name, :fetch)
    assert value == 4
  end

  test "creates an 'Oracle.Vision', subscribes it by key, and modifies the events content multiple times on proc" do
    {:ok, name} =
      Oracle.consult(TestOracle, :number)
      |> Oracle.Vision.map(&{:ok, &1 * 2})
      |> Oracle.Vision.map(&{:ok, &1 + 2})
      |> Oracle.Vision.map(&{:ok, "The number is: #{&1}"})
      |> Oracle.Vision.interprete(& &1)

    assert :ok == Oracle.reveal(TestOracle, 1, :number)

    %{value: value} = GenServer.call(name, :fetch)
    assert value == "The number is: 4"

    assert :ok == Oracle.reveal(TestOracle, 2, :number)

    %{value: value} = GenServer.call(name, :fetch)
    assert value == "The number is: 6"
  end
end
