defmodule Challenge.Supervisor do
  @moduledoc """
  This supervisor is responsible to create wallet for the users.
  """
  use DynamicSupervisor

  alias Challenge.Models.Bet
  alias Challenge.Models.User
  alias Challenge.Models.Win
  alias Challenge.Worker

  def start_link(opts \\ []) do
    DynamicSupervisor.start_link(__MODULE__, opts)
  end

  @impl true
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @spec start_children(server :: GenServer.server(), users :: List.t()) :: :ok
  def start_children(server, users) do
    for user <- users do
      user
      |> get_child_specs(server)
      |> start_child_process(server)
    end

    :ok
  end

  @spec bet(server :: GenServer.server(), body :: map, registry :: atom()) :: map
  def bet(server, body, registry) do
    with %Bet{user: user} = bet <- Bet.new(body),
         res = get_pid_from_registry("#{user}_#{inspect(server)}", registry),
         {:ok, pid} <- get_pid_from_res(res),
         {:ok, res} <- GenServer.call(pid, {:bet, bet}) do
      res
    else
      {:error, :invalid_bet} ->
        %{status: "RS_ERROR_WRONG_SYNTAX"}

      {:error, :wrong_type} ->
        %{status: "RS_ERROR_WRONG_TYPES"}

      _ ->
        %{status: "RS_ERROR_UNKNOWN"}
    end
  end

  @spec win(server :: GenServer.server(), body :: map, registry :: atom()) :: map
  def win(server, body, registry) do
    with %Win{user: user} = win <- Win.new(body),
         res = get_pid_from_registry("#{user}_#{inspect(server)}", registry),
         {:ok, pid} <- get_pid_from_res(res),
         {:ok, res} <- GenServer.call(pid, {:win, win}) do
      res
    else
      {:error, :invalid_win} ->
        %{status: "RS_ERROR_WRONG_SYNTAX"}

      {:error, :wrong_type} ->
        %{status: "RS_ERROR_WRONG_TYPES"}

      _ ->
        %{status: "RS_ERROR_UNKNOWN"}
    end
  end

  defp get_child_specs(user, server), do: {Worker, [User.new(%{id: user}), server]}

  defp get_pid_from_res([]), do: []
  defp get_pid_from_res([{pid, nil}]), do: {:ok, pid}

  defp get_pid_from_registry(name, registry), do: Registry.lookup(registry, name)

  defp start_child_process({_, [%User{}, _server]} = child_spec, server),
    do: DynamicSupervisor.start_child(server, child_spec)

  defp start_child_process(_, _), do: :ok
end
