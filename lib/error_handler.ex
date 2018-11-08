defmodule Oracle.ErrorHandler do
  @type t :: module

  @callback report([{:error, term}]) :: :ok
end
