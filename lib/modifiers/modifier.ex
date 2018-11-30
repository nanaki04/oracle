defmodule Oracle.Modifier do
  @type reason :: Oracle.reason()
  @type accumulator :: term
  @type next :: (Oracle.Vision.t() -> {:ok, Oracle.Vision.t()} | {:error, reason})
  @type t ::
          {:map, (Oracle.state() -> {:ok, Oracle.state()} | {:error, reason})}
          | {:filter, (Oracle.state() -> boolean)}
          | {:bind, (Oracle.state() -> {:ok, Oracle.Vision.t()} | {:error, reason})}
          | {:reduce,
             (Oracle.state(), accumulator -> {:ok, Oracle.Vision.t()} | {:error, reason})}
          | {:reduce, term,
             (Oracle.state(), accumulator -> {:ok, Oracle.Vision.t()} | {:error, reason})}
          | :count
          | :track
          # To account for user defined custom modifiers
          | {atom, term}

  @callback init(Oracle.Vision.t(), t) :: {:ok, Oracle.Vision.t()} | {:error, reason}
  @callback modify(Oracle.Vision.t(), t, next) :: {:ok, Oracle.Vision.t()} | {:error, reason}
  @callback terminate(Oracle.Vision.t()) :: :ok | {:error, reason}

  defmacro __using__(_) do
    quote do
      @behaviour Oracle.Modifier

      @impl Oracle.Modifier
      def init(vision, _modifier) do
        {:ok, vision}
      end

      @impl Oracle.Modifier
      def modify(vision, _modifier, next) do
        next(vision)
      end

      @impl Oracle.Modifier
      def terminate(_), do: :ok

      defoverridable init: 2, modify: 3
    end
  end

  @spec add(Oracle.Vision.t(), t) :: {:ok, Oracle.Vision.t()} | {:error, reason}
  def add(vision, modifier) do
    build_modifier_module_name(modifier)
    |> Kernel.apply(:init, [vision, modifier])
    |> ResultEx.map(fn vision -> add_modifier(vision, modifier) end)
  end

  @spec modify(Oracle.Vision.t(), t, next) :: {:ok, Oracle.Vision.t()} | {:error, reason}
  def modify(vision, modifier, next) do
    build_modifier_module_name(modifier)
    |> Kernel.apply(:modify, [vision, modifier, next])
  end

  @spec terminate(Oracle.Vision.t(), t) :: :ok | {:error, reason}
  def terminate(vision, modifier) do
    build_modifier_module_name(modifier)
    |> Kernel.apply(:terminate, [vision])
  end

  @spec build_modifier_module_name(t) :: module
  defp build_modifier_module_name({modifier, _}), do: build_modifier_module_name(modifier)

  defp build_modifier_module_name(modifier) do
    modifier
    |> Atom.to_string()
    |> String.capitalize()
    |> (fn id -> Module.concat(Oracle.Modifier, id) end).()
  end

  @spec add_modifier(Oracle.Vision.t(), t) :: Oracle.Vision.t()
  defp add_modifier(vision, modifier) do
    Map.put(vision, :modifiers, [modifier | vision.modifiers])
  end
end
