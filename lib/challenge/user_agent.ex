defmodule Challenge.UserAgent do
  use Agent

  @doc """
  This model handles idempotency for the transactions.
  """

  def start_link(_opts) do
    Agent.start_link(fn -> %{} end, name: :agent)
  end

  def get_transaction(:agent, transaction_uuid) do
    Agent.get(:agent, &Map.get(&1, transaction_uuid))
  end

  @spec put_transaction(atom() | pid() | {atom(), any()} | {:via, atom(), any()}, any(), any()) ::
          :ok
  def put_transaction(:agent, key, body) do
    Agent.update(:agent, &Map.put(&1, key, body))
  end
end
