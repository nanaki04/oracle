defmodule Oracle.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      {DynamicSupervisor, strategy: :one_for_one, name: Oracle.OracleSupervisor},
      {DynamicSupervisor, strategy: :one_for_one, name: Oracle.VisionSupervisor},
      {Registry, name: Oracle.VisionRegistry, keys: :unique},
      {Task.Supervisor, name: Oracle.TaskSupervisor}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Oracle.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
