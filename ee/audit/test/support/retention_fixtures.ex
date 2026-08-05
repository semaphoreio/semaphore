defmodule Support.RetentionFixtures do
  alias Audit.Event
  alias Audit.Repo
  alias Google.Protobuf.Timestamp
  alias InternalApi.Usage.OrganizationPolicyApply

  def insert_event(attrs \\ %{}) do
    defaults = %{
      resource: 1,
      operation: 1,
      timestamp: DateTime.utc_now() |> DateTime.truncate(:second),
      org_id: Ecto.UUID.generate(),
      user_id: Ecto.UUID.generate(),
      username: "tester",
      ip_address: "127.0.0.1",
      operation_id: Ecto.UUID.generate(),
      resource_id: Ecto.UUID.generate(),
      resource_name: "resource",
      metadata: %{},
      medium: 1,
      streamed: false,
      expires_at: nil
    }

    defaults
    |> Map.merge(attrs)
    |> then(&struct(Event, &1))
    |> Repo.insert!()
  end

  def encode_policy_event(org_id, cutoff = %DateTime{}) do
    %OrganizationPolicyApply{
      org_id: org_id,
      cutoff_date: timestamp(cutoff)
    }
    |> OrganizationPolicyApply.encode()
  end

  defp timestamp(datetime = %DateTime{}) do
    %Timestamp{
      seconds: DateTime.to_unix(datetime, :second),
      nanos: elem(datetime.microsecond, 0) * 1_000
    }
  end
end
