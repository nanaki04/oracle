defmodule Oracle.Vision do
  use GenServer

  @type status :: :undiscovered | :consulting | :revealing | :forgotten
  @type reason :: Oracle.reason()
  @type revealer :: (Oracle.state() -> :ok | {:error, reason}) | atom
  @type name :: {:via, Oracle.VisionRegistry, reference}

  @type t :: %Oracle.Vision{
          oracle: {:some, Oracle.t()} | :none,
          ref: {:some, reference} | :none,
          key: Oracle.key(),
          parent: {:some, pid} | :none,
          parent_ref: {:some, reference} | :none,
          status: status,
          value: Oracle.state(),
          current_modifier: number,
          modifiers: [Oracle.Modifier.t()],
          assigns: %{number => %{}},
          revealer: revealer
        }

  defstruct oracle: :none,
            ref: :none,
            key: :*,
            parent: :none,
            parent_ref: :none,
            status: :undiscovered,
            value: nil,
            current_modifier: 0,
            modifiers: [],
            assigns: %{},
            revealer: :revealer_not_set

  @spec interprete(t | {:ok, t} | {:error, reason}, revealer) :: {:ok, name} | {:error, reason}
  def interprete({:ok, vision}, revealer), do: interprete(vision, revealer)

  def interprete({:error, reason}, _), do: {:error, reason}

  def interprete(vision, revealer) do
    vision = %{
      vision
      | revealer: revealer,
        ref: {:some, make_ref()},
        status: :revealing,
        parent: {:some, self()}
    }

    case DynamicSupervisor.start_child(Oracle.VisionSupervisor, __MODULE__.child_spec(vision)) do
      {:ok, _} -> {:ok, make_name!(vision)}
      {:ok, _, _} -> {:ok, make_name!(vision)}
      :ignore -> {:error, :ignore}
      {:error, error} -> {:error, error}
    end
  end

  @spec forget(t) :: :ok | {:error, reason}
  def forget(vision) do
    GenServer.stop(make_name!(vision), :normal, 5000)
  end

  @spec update_value(t, (Oracle.state() -> {:ok, Oracle.state()} | {:error, reason})) ::
          {:ok, t} | {:error, reason}
  def update_value(vision, updater) do
    updater.(vision.value)
    |> ResultEx.map(fn value -> Map.put(vision, :value, value) end)
  end

  @spec assign(t, atom, term) :: {:ok, t} | {:error, reason}
  def assign(%{assigns: assigns, current_modifier: index} = vision, key, data) do
    Map.update(assigns, index, Map.put(%{}, key, data), & Map.put(&1, key, data))
    |> (&%{vision | assigns: &1}).()
    |> ResultEx.return()
  end

  @spec fetch_assign(t, atom) :: {:some, term} | :none
  def fetch_assign(%{assigns: assigns, current_modifier: index}, key) do
    get_in(assigns, [index, key])
    |> OptionEx.return()
  end

  @spec update_assign(t, atom, term, (term -> term)) :: {:ok, t} | {:error, reason}
  #  def update_assign(vision, key, {:ok, default}, updater),
  #    do: update_assign(vision, key, default, updater)
  #
  #  def update_assign(_, _, {:error, reason}, _), do: {:error, reason}

  def update_assign(%{assigns: assigns, current_modifier: index} = vision, key, default, updater) do
    %{
      vision
      | assigns:
          Map.update(assigns, index, Map.put(%{}, key, default), fn a ->
            Map.update(a, key, default, updater)
          end)
    }
    |> ResultEx.return()
  end

  @spec fetch_current_modifier(t) :: {:ok, Oracle.Modifier.t()} | {:error, reason}
  def fetch_current_modifier(%{current_modifier: index, modifiers: modifiers}) do
    case Enum.fetch(modifiers, index) do
      :error -> {:error, :index_out_of_range}
      modifier -> modifier
    end
  end

  @spec fetch_remaining_modifiers(t) :: {:ok, [Oracle.Modifier.t()]} | {:error, reason}
  def fetch_remaining_modifiers(%{current_modifier: index, modifiers: modifiers}) do
    modifiers
    |> Enum.with_index()
    |> Enum.drop_while(fn {_, i} -> i <= index end)
    |> Enum.map(fn {item, _} -> item end)
    |> ResultEx.return()
  end

  @spec increment_current_modifier(t) :: t
  def increment_current_modifier(%{current_modifier: n} = vision) do
    %{vision | current_modifier: n + 1}
  end

  @spec reset_current_modifier(t) :: t
  def reset_current_modifier(vision) do
    %{vision | current_modifier: 0}
  end

  @spec make_name!(t) :: name
  def make_name!(vision) do
    OptionEx.to_result(vision.ref, :vision_ref_not_set)
    |> ResultEx.map(fn ref -> {:via, Registry, {Oracle.VisionRegistry, ref}} end)
    |> ResultEx.unwrap!()
  end

  @spec map(
          t | {:ok, t} | {:error, reason},
          (Oracle.state() -> {:ok, Oracle.state()} | {:error, reason})
        ) :: {:ok, t} | {:error, reason}
  def map({:ok, vision}, fun), do: map(vision, fun)

  def map({:error, reason}, _), do: {:error, reason}

  def map(vision, fun) do
    Oracle.Modifier.add(vision, {:map, fun})
  end

  @spec reduce(
          t | {:ok, t} | {:error, reason},
          (Oracle.state(), term -> {:ok, term} | {:error, reason})
        ) :: {:ok, t} | {:error, reason}
  def reduce({:ok, vision}, fun), do: reduce(vision, fun)

  def reduce({:error, reason}, _), do: {:error, reason}

  def reduce(vision, fun) do
    Oracle.Modifier.add(vision, {:reduce, fun})
  end

  @spec reduce(
          t | {:ok, t} | {:error, reason},
          term,
          (Oracle.state(), term -> {:ok, term} | {:error, reason})
        ) :: {:ok, t} | {:error, reason}
  def reduce({:ok, vision}, default, fun), do: reduce(vision, default, fun)

  def reduce({:error, reason}, _, _), do: {:error, reason}

  def reduce(vision, default, fun) do
    Oracle.Modifier.add(vision, {:reduce, {default, fun}})
  end

  @spec filter(t | {:ok, t} | {:error, reason}, (Oracle.state() -> boolean)) ::
          {:ok, t} | {:error, reason}
  def filter({:ok, vision}, fun), do: filter(vision, fun)

  def filter({:error, reason}, _), do: {:error, reason}

  def filter(vision, fun) do
    Oracle.Modifier.add(vision, {:filter, fun})
  end

  @spec bind(t | {:ok, t} | {:error, reason}, (term -> t)) :: {:ok, t} | {:error, reason}
  def bind({:ok, vision}, fun), do: bind(vision, fun)

  def bind({:error, reason}, _), do: {:error, reason}

  def bind(vision, fun) do
    Oracle.Modifier.add(vision, {:bind, fun})
  end

  @spec count(t | {:ok, t} | {:error, reason}) :: {:ok, t} | {:error, reason}
  def count({:ok, vision}), do: count(vision)

  def count({:error, reason}), do: {:error, reason}

  def count(vision) do
    Oracle.Modifier.add(vision, :count)
  end

  @spec interval(t | {:ok, t} | {:error, reason}, number) :: {:ok, t} | {:error, reason}
  def interval(vision, interval_ms), do: interval(vision, interval_ms, :infinite)

  @spec interval(t | {:ok, t} | {:error, reason}, number, number | :infinite) ::
          {:ok, t} | {:error, reason}
  def interval({:ok, vision}, interval_ms, limit), do: interval(vision, interval_ms, limit)

  def interval({:error, reason}, _, _), do: {:error, reason}

  def interval(vision, interval_ms, limit) do
    Oracle.Modifier.add(vision, {:interval, {interval_ms, limit}})
  end

  @spec distinct(t | {:ok, t} | {:error, reason}) :: {:ok, t} | {:error, reason}
  def distinct({:ok, vision}), do: distinct(vision)

  def distinct({:error, reason}), do: {:error, reason}

  def distinct(vision) do
    Oracle.Modifier.add(vision, :distinct)
  end

  @spec track(t | {:ok, t} | {:error, reason}) :: {:ok, t} | {:error, reason}
  def track({:ok, vision}), do: track(vision)

  def track({:error, reason}), do: {:error, reason}

  def track(vision) do
    Oracle.Modifier.add(vision, :track)
  end

  @spec modify(t, Oracle.Modifier.t() | term) :: {:ok, t} | {:error, reason}
  def modify(vision, modifier) do
    Oracle.Modifier.add(vision, modifier)
  end

  # Not intended to be called directly by the user
  @doc false
  @spec reveal(pid, Oracle.state()) :: {:ok, t} | {:error, reason}
  def reveal(pid, state) do
    GenServer.call(pid, {:reveal, state})
  end

  @spec child_spec(t) :: Supervisor.child_spec()
  def child_spec(%Oracle.Vision{} = vision) do
    %{
      id: vision.ref,
      start: {GenServer, :start_link, [__MODULE__, vision, [name: make_name!(vision)]]},
      restart: :transient,
      shutdown: 5000,
      type: :worker
    }
  end

  @impl GenServer
  def init(%{oracle: {:some, oracle}, parent: {:some, parent}} = vision) do
    Oracle.interprete(oracle, vision.key, {__MODULE__, :reveal})
    |> ResultEx.map(fn _ -> {:ok, %{vision | parent_ref: {:some, Process.monitor(parent)}}} end)
    |> ResultEx.or_else_with(fn error -> {:stop, error} end)
  end

  def init(vision) do
    {:stop, {:badarg, vision}}
  end

  @impl GenServer
  def handle_call({:reveal, state}, _, vision) do
    vision_result =
      update_value(vision, fn _ -> {:ok, state} end)
      |> ResultEx.map(&reset_current_modifier/1)

    revealer = fn
      :revealer_not_set ->
        {:error, :revealer_not_set}

      %{revealer: revealer} = vision when is_atom(revealer) ->
        OptionEx.map(vision.parent, fn parent ->
          send(parent, {revealer, vision.value})
          vision
        end)
        |> OptionEx.to_result

      vision ->
        # TODO error handling
        case Task.Supervisor.start_child(Oracle.TaskSupervisor, fn ->
               vision.revealer.(vision.value)
             end) do
          {:ok, _} -> {:ok, vision}
          {:error, reason} -> {:error, reason}
          error -> {:error, error}
        end
    end

    composition =
      vision_result
      |> ResultEx.map(& &1.modifiers)
      |> ResultEx.map(fn modifiers ->
        Enum.reduce(modifiers, revealer, fn
          modifier, prev ->
            fn vision ->
              Oracle.Modifier.modify(vision, modifier, prev)
              |> ResultEx.map(&increment_current_modifier/1)
            end
        end)
      end)
      |> ResultEx.or_else_with(fn error -> fn _ -> {:error, error} end end)

    result = ResultEx.bind(vision_result, composition)

    ResultEx.or_else(result, vision)
    |> (&{:reply, result, &1}).()
  end

  def handle_call(:fetch, _, vision) do
    {:reply, vision, vision}
  end

  @impl GenServer
  def handle_info({:DOWN, ref, :process, _pid, _reason}, vision) do
    OptionEx.map(vision.parent_ref, fn
      ^ref -> {:stop, :normal, vision}
      _ -> {:noreply, vision}
    end)
    |> OptionEx.or_else({:noreply, vision})
  end
end
