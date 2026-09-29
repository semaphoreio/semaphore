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
          jit_provisioning_enabled: boolean() | nil,
          session_expiration_minutes: integer() | nil
        }

  @fields ~w(org_id creator_id sso_url issuer certificate idempotency_token jit_provisioning_enabled session_expiration_minutes)a

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
    field(:session_expiration_minutes, :integer)
  end

  def new do
    struct(__MODULE__, session_expiration_minutes: Front.Okta.SessionExpiration.default_minutes())
    |> changeset()
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
    base =
      case find_for_org(org_id) do
        {:ok, integration} ->
          %{integration | org_id: org_id, creator_id: creator_id}

        _ ->
          struct(__MODULE__,
            org_id: org_id,
            creator_id: creator_id,
            session_expiration_minutes: Front.Okta.SessionExpiration.default_minutes()
          )
      end

    result =
      base
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
  @spec get_mapping(String.t()) ::
          {:ok,
           {String.t(), [%{semaphore_id: String.t(), okta_id: String.t()}],
            %{semaphore_id: String.t(), okta_id: String.t()}}}
          | {:error, term()}
  def get_mapping(org_id) do
    endpoint = Application.fetch_env!(:front, :okta_grpc_endpoint)
    req = InternalApi.Okta.DescribeMappingRequest.new(org_id: org_id)

    with {:ok, channel} <- GRPC.Stub.connect(endpoint) do
      case InternalApi.Okta.Okta.Stub.describe_mapping(channel, req) do
        {:ok, response} ->
          {:ok,
           {
             response.default_role_id,
             mapping(response.group_mapping),
             mapping(response.role_mapping)
           }}

        error ->
          Logger.error("Failed to get Okta mappings: #{inspect(error)}")
          error
      end
    end
  end

  def set_mapping(org_id, params) do
    {default_role_id, group_mappings, role_mappings} = parse_mapping_params(params)
    set_mapping(org_id, default_role_id, group_mappings, role_mappings)
  end

  @doc """
  Sets up mappings for an organization.

  Takes the organization ID, default role ID, and a list of mappings.
  Each mapping should have semaphore_id and okta_id.
  """
  @spec set_mapping(String.t(), String.t(), [map()], [map()]) :: :ok | {:error, term()}
  def set_mapping(org_id, default_role_id, group_mappings, role_mappings) do
    endpoint = Application.fetch_env!(:front, :okta_grpc_endpoint)

    group_mappings =
      Enum.map(group_mappings, fn mapping ->
        InternalApi.Okta.GroupMapping.new(
          semaphore_group_id: mapping.semaphore_id,
          okta_group_id: mapping.okta_id
        )
      end)

    role_mappings =
      Enum.map(role_mappings, fn mapping ->
        InternalApi.Okta.RoleMapping.new(
          semaphore_role_id: mapping.semaphore_id,
          okta_role_id: mapping.okta_id
        )
      end)

    req =
      InternalApi.Okta.SetUpMappingRequest.new(
        org_id: org_id,
        default_role_id: default_role_id,
        group_mapping: group_mappings,
        role_mapping: role_mappings
      )

    with {:ok, channel} <- GRPC.Stub.connect(endpoint) do
      case InternalApi.Okta.Okta.Stub.set_up_mapping(channel, req) do
        {:ok, _response} ->
          :ok

        error ->
          Logger.error("Failed to set Okta group mappings: #{inspect(error)}")
          error
      end
    end
  end

  def mapping(mapping) do
    Enum.map(mapping, fn
      %{semaphore_group_id: semaphore_id, okta_group_id: okta_id} ->
        %{
          semaphore_id: semaphore_id,
          okta_id: okta_id
        }

      %{semaphore_role_id: semaphore_id, okta_role_id: okta_id} ->
        %{
          semaphore_id: semaphore_id,
          okta_id: okta_id
        }
    end)
  end

  @doc """
  Parses and validates group mapping parameters from the controller.

  Returns a tuple with the default role ID, group mappings, and role mappings.
  """
  @spec parse_mapping_params(map()) :: {String.t(), [map()], [map()]}
  def parse_mapping_params(params) do
    default_role_id = params["default_role_id"]
    group_mappings = process_mappings(params["group_mapping"])
    role_mappings = process_mappings(params["role_mapping"])

    {default_role_id, group_mappings, role_mappings}
  end

  defp process_mappings(mapping_data) do
    case mapping_data do
      mapping when is_map(mapping) ->
        mapping
        |> Enum.flat_map(fn
          # Handle when mappings come as {index, map} tuples (from form data)
          {_index, mapping} when is_map(mapping) ->
            if mapping["semaphore_id"] != nil &&
                 mapping["okta_id"] != nil &&
                 mapping["semaphore_id"] != "" &&
                 mapping["okta_id"] != "" do
              [
                %{
                  semaphore_id: mapping["semaphore_id"],
                  okta_id: mapping["okta_id"]
                }
              ]
            else
              []
            end

          # Skip anything else
          _ ->
            []
        end)

      _ ->
        []
    end
  end

  def changeset(schema, params \\ %{}) do
    schema
    |> cast(params, @fields)
    |> validate_required(required_fields(schema))
    |> validate_number(:session_expiration_minutes,
      greater_than: 0,
      less_than_or_equal_to: Front.Okta.SessionExpiration.max_minutes()
    )
    |> validate_certificate_for_issuer_or_sso_change()
  end

  defp validate_certificate_for_issuer_or_sso_change(changeset) do
    if edit_form_submission?(changeset) do
      validate_required(changeset, [:certificate])
    else
      changeset
    end
  end

  defp edit_form_submission?(%Ecto.Changeset{data: %__MODULE__{id: nil}}), do: false

  defp edit_form_submission?(%Ecto.Changeset{params: params}) when is_map(params) do
    Enum.any?(
      ["sso_url", "issuer", "certificate", "jit_provisioning_enabled"],
      &Map.has_key?(params, &1)
    )
  end

  defp edit_form_submission?(_changeset), do: false

  defp required_fields(%__MODULE__{id: nil}) do
    [
      :org_id,
      :creator_id,
      :sso_url,
      :issuer,
      :certificate,
      :jit_provisioning_enabled,
      :idempotency_token,
      :session_expiration_minutes
    ]
  end

  defp required_fields(%__MODULE__{}) do
    [
      :org_id,
      :creator_id,
      :sso_url,
      :issuer,
      :jit_provisioning_enabled,
      :idempotency_token,
      :session_expiration_minutes
    ]
  end

  defp grpc_set_up(model) do
    endpoint = Application.fetch_env!(:front, :okta_grpc_endpoint)

    req =
      InternalApi.Okta.SetUpRequest.new(
        org_id: model.org_id,
        creator_id: model.creator_id,
        sso_url: safe_string(model.sso_url),
        saml_issuer: safe_string(model.issuer),
        saml_certificate: safe_string(model.certificate),
        idempotency_token: safe_string(model.idempotency_token),
        jit_provisioning_enabled: model.jit_provisioning_enabled || false,
        session_expiration_minutes: model.session_expiration_minutes
      )

    with {:ok, channel} <- GRPC.Stub.connect(endpoint) do
      case InternalApi.Okta.Okta.Stub.set_up(channel, req) do
        {:ok, response} ->
          {:ok,
           struct!(__MODULE__,
             id: response.integration.id,
             org_id: response.integration.org_id,
             jit_provisioning_enabled: response.integration.jit_provisioning_enabled,
             session_expiration_minutes: response.integration.session_expiration_minutes
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
                jit_provisioning_enabled: i.jit_provisioning_enabled,
                session_expiration_minutes: i.session_expiration_minutes
              )
            end)

          {:ok, integrations}

        e ->
          e
      end
    end
  end

  defp safe_string(value) when value in [nil, ""], do: ""
  defp safe_string(value), do: value
end
