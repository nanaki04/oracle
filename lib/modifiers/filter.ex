defmodule Oracle.Modifier.Filter do
  use Oracle.Modifier

  @impl Oracle.Modifier
  def modify(vision, {_, fun}, next) do
    if fun.(vision.value) do
      next.(vision)
    else
      {:ok, vision}
    end
  end
end
