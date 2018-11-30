defmodule Oracle.Modifier.Interval do
  use Oracle.Modifier
  use GenServer

  @moduledoc """
  Modifier to proc the event multiple times on a time based interval.

  ## Examples

      iex> interval = 10 # ms
      ...> limit = 3
      ...> my_pid = self()
      ...>
      ...> {:ok, _} = Oracle.consult(TestOracle)
      ...>            |> Oracle.Vision.interval(interval, limit)
      ...>            |> Oracle.Vision.map(fn %{value: n} -> {:ok, n + 1} end)
      ...>            |> Oracle.Vision.interprete(fn n -> send(my_pid, {:interval_proc, n}) end)
      ...>
      ...> :ok = Oracle.reveal(TestOracle, 0)
      ...>
      ...> Enum.map(1..3, fn _ ->
      ...>   receive do
      ...>     {:interval_proc, n} -> n
      ...>   end
      ...> end)
      [1, 2, 3]

  """

  @type t :: %{
          delta_time: number,
          value: Oracle.state(),
          time_running: number,
          frame: number
        }

  @type state :: %Oracle.Modifier.Interval{
          last_fired: number,
          time_started: number,
          time_running: number,
          ms: number,
          frame: number,
          max: number | :infinite,
          vision: Oracle.Vision.t(),
          next: fun
        }

  defstruct last_fired: 0,
            time_started: 0,
            time_running: 0,
            ms: 0,
            frame: 0,
            max: :infinite,
            vision: nil,
            next: nil

  @impl Oracle.Modifier
  def modify(vision, {_, {ms, limit}}, next) do
    now = :os.system_time(:milli_seconds)

    vision = %{
      vision
      | value: %{
          delta_time: 0,
          value: vision.value,
          time_running: 0,
          frame: 0
        }
    }

    state = %Oracle.Modifier.Interval{
      last_fired: now,
      time_started: now,
      ms: ms,
      max: limit,
      vision: vision,
      next: next
    }

    state =
      next.(vision)
      |> ResultEx.map(&%{state | vision: &1})
      |> ResultEx.or_else(state)

    case GenServer.start_link(__MODULE__, state) do
      {:ok, pid} ->
        Process.send_after(pid, :tick, state.ms)
        {:ok, vision}

      :ignore ->
        {:error, :ignore}

      error ->
        error
    end
  end

  @impl GenServer
  def init(state) do
    # exit when parent exits
    Process.flag(:trap_exit, true)
    {:ok, state}
  end

  @impl GenServer
  def handle_info(:tick, %{max: max, frame: frame} = state)
      when is_integer(max) and frame + 1 >= max do
    {:stop, :normal, state}
  end

  def handle_info(:tick, state) do
    now = :os.system_time(:milli_seconds)
    diff = now - state.last_fired
    delta_time = diff / 1000
    time_running = now - state.time_started
    frame = state.frame + 1

    vision = %{
      state.vision
      | value: %{
          delta_time: delta_time,
          value: state.vision.value,
          time_running: time_running,
          frame: frame
        }
    }

    state =
      state.next.(vision)
      |> ResultEx.map(&%{state | vision: &1})
      |> ResultEx.or_else(state)

    state = %{state | last_fired: now, time_running: time_running, frame: frame}

    case state.vision.value do
      :stop ->
        {:stop, :normal, state}

      _ ->
        Process.send_after(
          self(),
          :tick,
          max(state.ms - (:os.system_time(:milli_seconds) - now), 0)
        )

        {:noreply, state}
    end
  end
end
