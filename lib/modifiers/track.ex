defmodule Oracle.Modifier.Track do
  use Oracle.Modifier

  @type t :: %Oracle.Modifier.Track{
          proc_count: number
        }

  defstruct proc_count: 0

  @impl Oracle.Modifier
  def modify(vision, _, next) do
    Oracle.Vision.update_assign(vision, :meta, %Oracle.Modifier.Track{proc_count: 1}, fn assign ->
      %{assign | proc_count: assign.proc_count + 1}
      |> ResultEx.return()
    end)
    |> ResultEx.bind(next)
  end

  @spec fetch_meta_data(Oracle.Vision.t() | Oracle.Vision.name()) :: {:some, t} | :none
  def fetch_meta_data(%Oracle.Vision{} = vision),
    do: fetch_meta_data(Oracle.Vision.make_name!(vision))

  def fetch_meta_data(name) do
    GenServer.call(name, :fetch)
    |> (fn %{modifiers: modifiers, assigns: assigns} ->
          idx = Enum.find_index(modifiers, &(&1 == :track))
          get_in(assigns, [idx, :meta])
        end).()
    |> OptionEx.return()
  end
end
