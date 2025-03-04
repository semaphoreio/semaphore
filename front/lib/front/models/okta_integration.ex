defmodule Front.Models.OktaIntegration do
  require Logger
  use Ecto.Schema
  import Ecto.Changeset

  @type t() :: %__MODULE__{
          org_id: String.t(),
          creator_id: String.t(),
          sso_url: String.t() | nil,
          issuer: String.t() | nil,
          certificate: String.t() | nil,
          idempotency_token: String.t(),
          jit_provisioning_enabled: boolean()
        }

  @fields ~w(org_id creator_id sso_url issuer certificate idempotency_token jit_provisioning_enabled)a
  @primary_key false

  embedded_schema do
    field(:id, :string)
    field(:org_id, :string)
    field(:creator_id, :string)
    field(:sso_url, :string)
    field(:issuer, :string)
    field(:certificate, :string)
    field(:jit_provisioning_enabled, :boolean)
    field(:idempotency_token, :string)
  end

  def new do
    struct(__MODULE__) |> changeset()
  end

  def find_for_org(org_id) do
    case grpc_list(org_id) do
      {:ok, []} -> {:error, :not_found}
      {:ok, [integration | _]} -> {:ok, integration}
      e -> e
    end
  end

  @doc """
    Returns:
    {:ok, user_ids}: list of ids of users who have been provisioned by okta
    {:error, nil}
  """
  def get_okta_members(org_id) do
    okta_endpoint = Application.fetch_env!(:front, :okta_grpc_endpoint)
    req = InternalApi.Okta.ListUsersRequest.new(org_id: org_id)

    with {:ok, channel} <- GRPC.Stub.connect(okta_endpoint) do
      case InternalApi.Okta.Okta.Stub.list_users(channel, req) do
        {:ok, response} ->
          {:ok, response.user_ids}

        e ->
          Logger.error("Could not fetch okta members for org #{org_id}. Error #{inspect(e)}")
          {:error, nil}
      end
    end
  end

  def create_or_upadte(org_id, creator_id, params) do
    result =
      struct(__MODULE__, org_id: org_id, creator_id: creator_id)
      |> changeset(params)
      |> Ecto.Changeset.apply_action(:insert)

    case result do
      {:ok, model} -> grpc_set_up(model)
      {:error, changeset} -> {:error, changeset}
    end
  end

  def gen_token(integration_id) do
    alias InternalApi.Okta.GenerateScimTokenRequest
    alias InternalApi.Okta.Okta.Stub

    endpoint = Application.fetch_env!(:front, :okta_grpc_endpoint)

    req = GenerateScimTokenRequest.new(integration_id: integration_id)

    with {:ok, channel} <- GRPC.Stub.connect(endpoint),
         {:ok, response} <- Stub.generate_scim_token(channel, req) do
      {:ok, response.token}
    end
  end

  def destroy(integration_id, user_id) do
    alias InternalApi.Okta.DestroyRequest
    alias InternalApi.Okta.Okta.Stub

    endpoint = Application.fetch_env!(:front, :okta_grpc_endpoint)
    req = DestroyRequest.new(integration_id: integration_id, user_id: user_id)

    with {:ok, channel} <- GRPC.Stub.connect(endpoint),
         {:ok, _response} <- Stub.destroy(channel, req) do
      :ok
    end
  end

  def changeset(schema, params \\ %{}) do
    schema
    |> cast(params, @fields)
    |> validate_required([
      :org_id,
      :creator_id,
      :sso_url,
      :issuer,
      :certificate,
      :jit_provisioning_enabled,
      :idempotency_token
    ])
  end

  defp grpc_set_up(model) do
    endpoint = Application.fetch_env!(:front, :okta_grpc_endpoint)

    req =
      InternalApi.Okta.SetUpRequest.new(
        org_id: model.org_id,
        creator_id: model.creator_id,
        sso_url: model.sso_url,
        saml_issuer: model.issuer,
        saml_certificate: model.certificate,
        idempotency_token: model.idempotency_token,
        saml_auto_provision: model.jit_provisioning_enabled
      )

    with {:ok, channel} <- GRPC.Stub.connect(endpoint) do
      case InternalApi.Okta.Okta.Stub.set_up(channel, req) do
        {:ok, response} ->
          {:ok,
           struct!(__MODULE__,
             id: response.integration.id,
             org_id: response.integration.org_id
           )}

        e ->
          e
      end
    end
  end

  defp grpc_list(org_id) do
    endpoint = Application.fetch_env!(:front, :okta_grpc_endpoint)

    req = InternalApi.Okta.ListRequest.new(org_id: org_id)

    with {:ok, channel} <- GRPC.Stub.connect(endpoint) do
      case InternalApi.Okta.Okta.Stub.list(channel, req) do
        {:ok, response} ->
          integrations =
            Enum.map(response.integrations, fn i ->
              struct!(__MODULE__,
                id: i.id,
                org_id: i.org_id,
                sso_url: i.sso_url,
                issuer: i.saml_issuer,
                jit_provisioning_enabled: i.jit_provisioning_enabled
              )
            end)

          {:ok, integrations}

        e ->
          e
      end
    end
  end
end
