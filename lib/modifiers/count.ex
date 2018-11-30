defmodule Oracle.Modifier.Count do
  use Oracle.Modifier

  @moduledoc """
  Set the number of events procced as event value.

  ## Examples

      iex> {:ok, _} =
      ...>   Oracle.consult(TestOracle, :count)
      ...>   |> Oracle.Vision.count()
      ...>   |> Oracle.Vision.interprete(:callback_count)
      ...>
      ...> for _ <- 1..5, do: Oracle.reveal(TestOracle, :any, :count)
      ...> for _ <- 1..5 do
      ...>   receive do {:callback_count, value} -> value end
      ...> end
      [1, 2, 3, 4, 5]

  """

  @impl Oracle.Modifier
  def modify(vision, _, next) do
    Oracle.Modifier.Reduce.modify(
      vision,
      {:reduce,
       fn
         _, nil -> {:ok, 1}
         _, count -> {:ok, count + 1}
       end},
      next
    )
  end
end
