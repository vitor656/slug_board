defmodule SlugBoard.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    :dets.open_file(:boards_dets, [{:file, ~c"boards.dets"}, {:type, :set}])

    children = [
      SlugBoardWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:slug_board, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: SlugBoard.PubSub},
      # Start a worker by calling: SlugBoard.Worker.start_link(arg)
      # {SlugBoard.Worker, arg},

      {Registry, keys: :unique, name: SlugBoard.BoardRegistry},
      {DynamicSupervisor, name: SlugBoard.BoardSupervisor, strategy: :one_for_one},

      # Start to serve requests, typically the last entry
      SlugBoardWeb.Presence,
      SlugBoardWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: SlugBoard.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    SlugBoardWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
