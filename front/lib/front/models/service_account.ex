defmodule Front.Models.ServiceAccount do
  @moduledoc """
  Model representing a Service Account
  """

  defstruct [
    :id,
    :name,
    :description,
    :org_id,
    :creator_id,
    :created_at,
    :updated_at,
    :deactivated
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          description: String.t(),
          org_id: String.t(),
          creator_id: String.t(),
          created_at: DateTime.t(),
          updated_at: DateTime.t(),
          deactivated: boolean()
        }

  @doc """
  Creates a new ServiceAccount struct from protobuf data
  """
  @spec from_proto(InternalApi.ServiceAccount.t()) :: t
  def from_proto(proto) do
    %__MODULE__{
      id: proto.id,
      name: proto.name,
      description: proto.description,
      org_id: proto.org_id,
      creator_id: proto.creator_id,
      created_at: timestamp_to_datetime(proto.created_at),
      updated_at: timestamp_to_datetime(proto.updated_at),
      deactivated: proto.deactivated
    }
  end

  defp timestamp_to_datetime(%Google.Protobuf.Timestamp{seconds: seconds}) do
    DateTime.from_unix!(seconds)
  end

  defp timestamp_to_datetime(_), do: DateTime.utc_now()
end
