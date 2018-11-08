defmodule Oracle.Modifier.Reduce do
  use Oracle.Modifier

  @impl Oracle.Modifier
  def modify(vision, {id, fun}, next), do: modify(vision, {id, nil, fun}, next)

  def modify(vision, {_, default, fun}, next) do
    Oracle.Vision.update_assign(vision, :accumulator, fun.(vision.value, default), fn
      {:ok, acc} -> fun.(vision.value, acc)
      {:error, reason} -> {:error, reason}
      _ -> {:error, :oracle_reduce_type_error}
    end)
    |> ResultEx.map(fn vision -> [vision, Oracle.Vision.fetch_assign(vision, :accumulator)] end)
    |> ResultEx.flatten_enum()
    |> ResultEx.map(fn [vision, accumulator] -> %{vision | value: accumulator} end)
    |> ResultEx.bind(next)
  end
end
