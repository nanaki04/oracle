defmodule Oracle.Modifier.Distinct do
  use Oracle.Modifier

  @moduledoc """
  Filters out events with values not equal to the value of the previous event.

  ## Examples

      iex> {:ok, _} =
      ...>   Oracle.consult(TestOracle, :distinct)
      ...>   |> Oracle.Vision.distinct
      ...>   |> Oracle.Vision.interprete(:callback_distinct)
      ...>
      ...> :ok = Oracle.reveal(TestOracle, 1, :distinct)
      ...> :ok = Oracle.reveal(TestOracle, 1, :distinct)
      ...> :ok = Oracle.reveal(TestOracle, 2, :distinct)
      ...>
      ...> receive do {:callback_distinct, value} -> value end
      1
      iex> receive do {:callback_distinct, value} -> value end
      2

  """

  @impl Oracle.Modifier
  def modify(vision, _, next) do
    case {
      Oracle.Vision.fetch_assign(vision, :accumulator),
      Oracle.Vision.assign(vision, :accumulator, vision.value)
    } do
      {:none, {:ok, vision}} ->
        unless vision.value == nil, do: next.(vision), else: {:ok, vision}
      {{:some, acc}, {:ok, vision}} ->
        unless vision.value == acc, do: next.(vision), else: {:ok, vision}
      {_, {:error, error}} ->
        {:error, error}
    end
  end
end
