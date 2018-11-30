defmodule Oracle.Modifier.Map do
  use Oracle.Modifier

  @moduledoc """
  Modifier to change an events content, or select only a specific part of the content to be passed to the final callback.

  ## Examples

      iex> {:ok, _} = Oracle.consult(TestOracle, :contact_info)
      ...>            |> Oracle.Vision.map(fn user_model -> {:ok, user_model.contacts} end)
      ...>            |> Oracle.Vision.interprete(:callback_contact)
      ...>
      ...> model = %{contacts: %{phone: "090-1234-2345"}}
      ...> :ok = Oracle.reveal(TestOracle, model, :contact_info)
      ...>
      ...> receive do {:callback_contact, value} -> value end
      %{phone: "090-1234-2345"}

  """

  @impl Oracle.Modifier
  def modify(vision, {_, fun}, next) do
    Oracle.Vision.update_value(vision, fun)
    |> ResultEx.bind(next)
  end
end
