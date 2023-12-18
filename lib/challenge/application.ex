defmodule Challenge.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false
  alias Challenge.UserAgent

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Registry, [keys: :unique, name: Challenge.Registry]},
      {UserAgent, name: Challenge.UserAgent}
    ]

    opts = [strategy: :one_for_one, name: Challenge.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
