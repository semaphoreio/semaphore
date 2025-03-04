defmodule Rbac.Repo.OktaIntegration do
  use Rbac.Repo.Schema

  @timestamps_opts [type: :utc_datetime]

  @required_fields [
    :org_id,
    :creator_id,
    :saml_issuer,
    :saml_certificate_fingerprint
  ]

  @updatable_fields [
    :saml_issuer,
    :saml_certificate_fingerprint,
    :scim_token_hash,
    :sso_url,
    :jit_provisioning_enabled
  ]

  schema "okta_integrations" do
    field(:idempotency_token, :string)
    field(:org_id, :binary_id)
    field(:creator_id, :binary_id)

    field(:saml_issuer, :string)
    field(:sso_url, :string)
    field(:saml_certificate_fingerprint, :string)
    field(:scim_token_hash, :string)
    field(:jit_provisioning_enabled, :boolean, default: false)

    timestamps()
  end

  def changeset(okta_integration, params \\ %{}) do
    okta_integration
    |> cast(params, @updatable_fields)
    |> validate_required(@required_fields)
    |> unique_constraint(:org_id,
      name: "okta_integrations_org_id_index",
      message: "Organization already has okta integration"
    )
    |> unique_constraint(:idempotency_token,
      name: "okta_integrations_idempotency_token_index",
      message: "Idempotent Request"
    )
  end

  def insert_or_update(fields \\ []) do
    # Each time you want to make any change to the integration, token will be reset
    fields = Keyword.put(fields, :scim_token_hash, "")
    integration = struct(__MODULE__, fields)

    changeset = Rbac.Repo.OktaIntegration.changeset(integration)

    case find_idempotent_record(fields[:org_id], fields[:idempotency_token]) do
      {:ok, integration} ->
        {:ok, integration}

      {:error, :not_found} ->
        Rbac.Repo.insert(changeset,
          returning: true,
          on_conflict: {:replace_all_except, [:id, :org_id, :inserted_at]},
          conflict_target: :org_id
        )
    end
  end

  def fetch_one do
    res = __MODULE__ |> Rbac.Repo.one()

    case res do
      nil -> {:error, :not_found}
      integration -> {:ok, integration}
    end
  rescue
    e -> {:error, e}
  end

  def fetch_for_org(org_id) do
    import Ecto.Query, only: [where: 3]

    res = __MODULE__ |> where([o], o.org_id == ^org_id) |> Rbac.Repo.one()

    case res do
      nil -> {:error, :not_found}
      integration -> {:ok, integration}
    end
  rescue
    e -> {:error, e}
  end

  defp find_idempotent_record(org_id, idempotency_token) do
    import Ecto.Query, only: [from: 2]

    query =
      from(i in __MODULE__,
        where: i.org_id == ^org_id and i.idempotency_token == ^idempotency_token
      )

    case Rbac.Repo.one(query) do
      nil -> {:error, :not_found}
      record -> {:ok, record}
    end
  end
end
