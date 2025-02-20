defmodule Front.Models.JWTConfig do
  use Ecto.Schema
  import Ecto.Changeset
  require Logger

  alias InternalApi.Secrethub.{
    GetJWTConfigRequest,
    UpdateJWTConfigRequest,
    ClaimConfig
  }

  embedded_schema do
    field(:org_id, :string)
    field(:project_id, :string)
    field(:claims, {:array, :map}, default: [])
    field(:is_active, :boolean, default: true)
  end

  @doc """
  Get OIDC Token configuration for a project or organization.
  """
  def get(org_id, project_id, _opts \\ []) do
    with {:ok, channel} <- GRPC.Stub.connect(endpoint()) do
      case InternalApi.Secrethub.SecretService.Stub.get_jwt_config(
             channel,
             %GetJWTConfigRequest{
               org_id: org_id,
               project_id: project_id || ""
             }
           ) do
        {:ok, response} ->
          {:ok,
           %__MODULE__{
             org_id: response.org_id,
             project_id: response.project_id,
             claims: response.claims,
             is_active: response.is_active
           }}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc """
  Update OIDC Token configuration for a project or organization.
  """
  def update(org_id, project_id, is_active, claims, _opts \\ []) do
    with {:ok, channel} <- GRPC.Stub.connect(endpoint()) do
      case InternalApi.Secrethub.SecretService.Stub.update_jwt_config(
             channel,
             %UpdateJWTConfigRequest{
               org_id: org_id,
               project_id: project_id || "",
               claims: claims,
               is_active: is_active
             }
           ) do
        {:ok, _response} -> {:ok, :updated}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  def change_claims(attrs \\ %{}) do
    types = %{
      is_active: :boolean,
      claims: {:array, :map}
    }

    {%{}, types}
    |> cast(attrs, Map.keys(types))
    |> validate_claims()
  end

  defp validate_claims(changeset) do
    claims = get_field(changeset, :claims) || []

    if validate_claim_structure(claims) do
      changeset
    else
      add_error(changeset, :claims, "invalid claims structure")
    end
  end

  defp validate_claim_structure(claims) when is_list(claims) do
    Enum.all?(claims, fn
      %ClaimConfig{} = claim ->
        is_binary(claim.name) and is_boolean(claim.is_active)

      _ ->
        false
    end)
  end

  defp validate_claim_structure(_), do: false

  defp endpoint do
    Application.get_env(:front, :jwt_grpc_endpoint, "127.0.0.1:50052")
  end
end
