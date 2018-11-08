defmodule Oracle.Modifier.Bind do
  use Oracle.Modifier

  @impl Oracle.Modifier
  def modify(vision, {_, fun}, _next) do
    # make new inner vision
    inner_vision = fun.(vision.value)

    # add remaining modifier stack to the new vision and interprete using the original revealer on proc
    Enum.reduce(Oracle.Vision.fetch_remaining_modifiers(vision), inner_vision, fn
      modifier, {:ok, inner_vision} ->
        Oracle.Modifier.add(inner_vision, modifier)

      _, {:error, reason} ->
        {:error, reason}

      _, _ ->
        {:error, :bind_callback_type_mismatch}
    end)
    |> ResultEx.bind(fn inner_vision ->
      Oracle.Vision.interprete(inner_vision, vision.revealer)
    end)
    |> ResultEx.map(fn _ -> vision end)
  end
end
