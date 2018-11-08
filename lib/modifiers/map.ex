defmodule Oracle.Modifier.Map do
  use Oracle.Modifier

  @impl Oracle.Modifier
  def modify(vision, {_, fun}, next) do
    Oracle.Vision.update_value(vision, fun)
    |> ResultEx.bind(next)
  end
end
