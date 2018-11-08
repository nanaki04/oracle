defmodule Oracle do
  @type t :: GenServer.name()
  @type key :: atom
  @type state :: term
  @type reason :: term

  @callback consult(key) :: Oracle.Vision.t()
  @callback reveal(state, key) :: :ok | {:error, reason}
  @callback register_error_handler(Oracle.ErrorHandler.t()) :: {:ok, pid} | {:error, reason}

  defmacro __using__(opts) do
    name = Keyword.get(opts, :name, Module.concat(Oracle, __MODULE__))
    error_handler = Keyword.get(opts, :error_handler)

    quote bind_quoted: [name: name, error_handler: error_handler] do
      @behaviour Oracle

      @doc false
      @impl Oracle
      def consult(key \\ :*), do: Oracle.consult(name, key)

      @doc false
      @impl Oracle
      def reveal(state, key \\ :*) do
        ensure_started()
        |> ResultEx.bind(fn oracle -> Oracle.reveal(oracle, state, key) end)
      end

      @doc false
      @impl Oracle
      def register_error_handler(error_handler) do
        ensure_started()
        |> ResultEx.bind(fn oracle -> Oracle.register_error_handler(oracle, error_handler) end)
      end

      @doc false
      @spec ensure_started() :: {:ok, t} | {:error, reason}
      defp ensure_started() do
        GenServer.whereis(name)
        |> OptionEx.return()
        |> OptionEx.or_else_with(fn _ ->
          case DynamicSupervisor.start_child(Oracle.OracleSupervisor, Registry,
                 keys: :duplicate,
                 name: oracle
               ) do
            {:ok, _} ->
              error_handler
              |> OptionEx.map(&register_error_handler/1)
              |> OptionEx.or_else({:ok, :none})
              |> ResultEx.map(fn _ -> oracle end)

            {:error, error} ->
              {:error, error}

            :ignore ->
              {:error, :ignore}
          end
        end)
        |> ResultEx.return()
        |> ResultEx.flatten()
      end
    end
  end

  @spec consult(t, key) :: Oracle.Vision.t()
  def consult(oracle, key \\ :*) do
    %Oracle.Vision{
      oracle: {:some, oracle},
      key: key,
      status: :consulting
    }
  end

  # Not intended to be called by the user
  @doc false
  @spec interprete(t, key, {module, atom}) :: {:ok, pid} | {:error, reason}
  def interprete(oracle, key, mf) do
    ensure_started(oracle)
    |> ResultEx.bind(fn oracle -> Registry.register(oracle, key, mf) end)
  end

  @spec reveal(t, state) :: :ok | {:error, reason}
  def reveal(oracle, state, key \\ :*) do
    ensure_started(oracle)
    |> ResultEx.map(fn oracle -> dispatch(oracle, key, state) end)
    |> ResultEx.or_else_with(fn err -> {:error, err} end)
  end

  @spec register_error_handler(t, Oracle.ErrorHandler.t()) :: {:ok, pid} | {:error, reason}
  def register_error_handler(oracle, error_handler) do
    Registry.register(oracle, :error_handlers, {error_handler, :report})
  end

  defp dispatch(oracle, :*, state) do
    Registry.dispatch(oracle, :*, fn entries ->
      handle_errors(
        oracle,
        Enum.map(entries, fn
          {pid, {mod, fun}} -> apply(mod, fun, [pid, state])
        end)
      )
    end)

    :ok
  end

  defp dispatch(oracle, :error_handlers, errors) do
    # skip error handling the error handlers to prevent infinite loops
    Registry.dispatch(oracle, :error_handlers, fn entries ->
      Enum.each(entries, fn
        {_pid, {mod, fun}} -> apply(mod, fun, [errors])
      end)
    end)

    :ok
  end

  defp dispatch(oracle, key, state) do
    dispatch(oracle, :*, state)

    Registry.dispatch(oracle, key, fn entries ->
      handle_errors(
        oracle,
        Enum.map(entries, fn
          {pid, {mod, fun}} -> apply(mod, fun, [pid, state])
        end)
      )
    end)

    :ok
  end

  @spec handle_errors(t, [{:error, term}]) :: :ok
  defp handle_errors(oracle, results) do
    errors =
      Enum.filter(results, fn
        {:ok, _} -> false
        _ -> true
      end)

    if length(errors) > 0 do
      dispatch(oracle, :error_handlers, errors)
    end

    :ok
  end

  @spec ensure_started(t) :: {:ok, t} | {:error, reason}
  defp ensure_started(oracle) do
    GenServer.whereis(oracle)
    |> OptionEx.return()
    |> OptionEx.or_else_with(fn ->
      case DynamicSupervisor.start_child(
             Oracle.OracleSupervisor,
             Registry.child_spec(keys: :duplicate, name: oracle)
           ) do
        {:ok, _} -> {:ok, oracle}
        {:error, error} -> {:error, error}
        :ignore -> {:error, :ignore}
      end
    end)
    |> ResultEx.return()
    |> ResultEx.flatten()
  end
end
