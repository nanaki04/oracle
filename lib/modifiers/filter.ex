defmodule Oracle.Modifier.Filter do
  use Oracle.Modifier

  @moduledoc """
  Modifier that filters events by a predicate function that returns true for values that should be passed through, and false for values that should be ignored.

  ## Examples

      iex> {:ok, _} =
      ...>   Oracle.consult(TestOracle, :filter)
      ...>   |> Oracle.Vision.filter(& rem(&1, 2) == 0)
      ...>   |> Oracle.Vision.interprete(:callback_filter)
      ...>
      ...> :ok = Oracle.reveal(TestOracle, 1, :filter)
      ...> :ok = Oracle.reveal(TestOracle, 2, :filter)
      ...> :ok = Oracle.reveal(TestOracle, 3, :filter)
      ...> :ok = Oracle.reveal(TestOracle, 4, :filter)
      ...>
      ...> receive do {:callback_filter, value} -> value end
      2
      iex> receive do {:callback_filter, value} -> value end
      4
  """

  @impl Oracle.Modifier
  def modify(vision, {_, fun}, next) do
    if fun.(vision.value) do
      next.(vision)
    else
      {:ok, vision}
    end
  end
end
