defmodule Oracle.Modifier.Count do
  use Oracle.Modifier

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
