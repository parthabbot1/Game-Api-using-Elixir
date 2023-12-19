defmodule Challenge.UserAgent do
  use Agent

  @doc """
  This model handles idempotency for the transactions.
  """

  def start_link(_opts) do
    Agent.start_link(fn -> %{} end, name: :idempotent)
  end

  def get_transaction(transaction_uuid) do
    Agent.get(:idempotent, &Map.get(&1, transaction_uuid))
  end

  def put_transaction(transaction_uuid, body) do
    Agent.update(:idempotent, &Map.put(&1, transaction_uuid, body))
  end
end
