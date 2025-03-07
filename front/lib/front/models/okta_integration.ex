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
          jit_provisioning_enabled: boolean() | nil
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

  @doc """
  Gets the current group mappings for an organization.

  Returns a tuple with the default role ID and a list of group mappings.
  """
  @spec get_group_mappings(String.t()) ::
          {:ok, {String.t(), [%{semaphore_group_id: String.t(), okta_group_id: String.t()}]}}
          | {:error, term()}
  def get_group_mappings(org_id) do
    endpoint = Application.fetch_env!(:front, :okta_grpc_endpoint)
    req = InternalApi.Okta.DescribeGroupMappingRequest.new(org_id: org_id)

    with {:ok, channel} <- GRPC.Stub.connect(endpoint) do
      case InternalApi.Okta.Okta.Stub.describe_group_mapping(channel, req) do
        {:ok, response} ->
          mappings =
            Enum.map(response.mappings, fn mapping ->
              %{
                semaphore_group_id: mapping.semaphore_group_id,
                okta_group_id: mapping.okta_group_id
              }
            end)

          {:ok, {response.default_role_id, mappings}}

        error ->
          Logger.error("Failed to get Okta group mappings: #{inspect(error)}")
          error
      end
    end
  end

  @doc """
  Sets up group mappings for an organization.

  Takes the organization ID, default role ID, and a list of mappings.
  Each mapping should have semaphore_group_id and okta_group_id.
  """
  @spec set_group_mappings(String.t(), String.t(), [map()]) :: :ok | {:error, term()}
  def set_group_mappings(org_id, default_role_id, mappings) do
    endpoint = Application.fetch_env!(:front, :okta_grpc_endpoint)

    group_mappings =
      Enum.map(mappings, fn mapping ->
        InternalApi.Okta.GroupMapping.new(
          semaphore_group_id: mapping.semaphore_group_id,
          okta_group_id: mapping.okta_group_id
        )
      end)

    req =
      InternalApi.Okta.SetUpGroupMappingRequest.new(
        org_id: org_id,
        default_role_id: default_role_id,
        mappings: group_mappings
      )

    with {:ok, channel} <- GRPC.Stub.connect(endpoint) do
      case InternalApi.Okta.Okta.Stub.set_up_group_mapping(channel, req) do
        {:ok, _response} ->
          :ok

        error ->
          Logger.error("Failed to set Okta group mappings: #{inspect(error)}")
          error
      end
    end
  end

  @doc """
  Parses and validates group mapping parameters from the controller.

  Returns a list of valid mappings and the default role ID.
  """
  @spec parse_mapping_params(map()) :: {String.t(), [map()]}
  def parse_mapping_params(params) do
    default_role_id = params["default_role_id"]

    mappings =
      params
      |> Map.get("mappings", [])
      |> Enum.flat_map(fn
        # Handle when mappings come as a list of maps
        mapping when is_map(mapping) ->
          if mapping["semaphore_group_id"] != nil &&
               mapping["okta_group_id"] != nil &&
               mapping["semaphore_group_id"] != "" &&
               mapping["okta_group_id"] != "" do
            [
              %{
                semaphore_group_id: mapping["semaphore_group_id"],
                okta_group_id: mapping["okta_group_id"]
              }
            ]
          else
            []
          end

        # Handle when mappings come as {index, map} tuples (from form data)
        {_index, mapping} when is_map(mapping) ->
          if mapping["semaphore_group_id"] != nil &&
               mapping["okta_group_id"] != nil &&
               mapping["semaphore_group_id"] != "" &&
               mapping["okta_group_id"] != "" do
            [
              %{
                semaphore_group_id: mapping["semaphore_group_id"],
                okta_group_id: mapping["okta_group_id"]
              }
            ]
          else
            []
          end

        # Skip anything else
        _ ->
          []
      end)

    {default_role_id, mappings}
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
        jit_provisioning_enabled: model.jit_provisioning_enabled
      )

    with {:ok, channel} <- GRPC.Stub.connect(endpoint) do
      case InternalApi.Okta.Okta.Stub.set_up(channel, req) do
        {:ok, response} ->
          {:ok,
           struct!(__MODULE__,
             id: response.integration.id,
             org_id: response.integration.org_id,
             jit_provisioning_enabled: response.integration.jit_provisioning_enabled
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
