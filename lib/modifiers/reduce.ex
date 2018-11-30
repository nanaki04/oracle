defmodule Oracle.Modifier.Reduce do
  use Oracle.Modifier

  @moduledoc """
  Accumulates data from multiple events into one value.

  ## Examples

      iex> {:ok, _} =
      ...>   Oracle.consult(TestOracle, :reduce)
      ...>   |> Oracle.Vision.reduce(1, & {:ok, &1 * &2})
      ...>   |> Oracle.Vision.interprete(:callback_reduce)
      ...>
      ...> :ok = Oracle.reveal(TestOracle, 2, :reduce)
      ...> :ok = Oracle.reveal(TestOracle, 2, :reduce)
      ...> :ok = Oracle.reveal(TestOracle, 2, :reduce)
      ...>
      ...> receive do {:callback_reduce, value} -> value end
      2
      iex> receive do {:callback_reduce, value} -> value end
      4
      iex> receive do {:callback_reduce, value} -> value end
      8
  """

  @impl Oracle.Modifier
  def modify(vision, {_, {{:ok, default}, fun}}, next), do: modify(vision, {:reduce, {default, fun}}, next)

  def modify(_, {_, {{:error, reason}, _}}, _), do: {:error, reason}

  def modify(vision, {_, {default, fun}}, next) do
    Oracle.Vision.update_assign(vision, :accumulator, fun.(vision.value, default), fn
      {:ok, acc} -> fun.(vision.value, acc)
      {:error, reason} -> {:error, reason}
      e -> {:error, {:oracle_reduce_type_error, e}}
    end)
    |> ResultEx.map(fn vision -> [
      {:ok, vision},
      Oracle.Vision.fetch_assign(vision, :accumulator)
      |> OptionEx.to_result
      |> ResultEx.flatten
    ] end)
    |> ResultEx.bind(&ResultEx.flatten_enum/1)
    |> ResultEx.map(fn [vision, accumulator] -> %{vision | value: accumulator} end)
    |> ResultEx.bind(next)
  end

  def modify(vision, {id, fun}, next), do: modify(vision, {id, {nil, fun}}, next)
end
