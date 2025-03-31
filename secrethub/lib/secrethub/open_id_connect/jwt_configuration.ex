defmodule Secrethub.OpenIDConnect.JWTConfiguration do
  @moduledoc """
  Handles JWT configuration for organizations and projects.
  """
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias Secrethub.Repo
  alias Secrethub.OpenIDConnect.JWTClaim

  @primary_key {:id, :binary_id, autogenerate: true}
  @supported_claim_fields ~w(name description is_system_claim is_aws_tag is_mandatory is_active)

  schema "jwt_configurations" do
    field :org_id, :binary_id
    field :project_id, :binary_id, default: nil
    field :claims, {:array, :map}, default: []
    field :is_active, :boolean, default: true

    timestamps()
  end

  def changeset(jwt_configuration, attrs) do
    jwt_configuration
    |> cast(attrs, [:org_id, :project_id, :claims, :is_active])
    |> validate_required([:org_id])
    |> filter_claim_fields()
    |> validate_claims_array()
    |> enforce_default_values()
  end

  def create_or_update_org_config(org_id, _claims) when not is_binary(org_id),
    do: {:error, :org_id_required}

  def create_or_update_org_config("", _claims), do: {:error, :org_id_required}

  def create_or_update_org_config(_org_id, claims)
      when not is_list(claims) and not is_map(claims),
      do: {:error, :claims_required}

  def create_or_update_org_config(org_id, claims) when is_binary(org_id) do
    # Validate claims before proceeding
    if Enum.all?(claims, &valid_claim_config?/1) do
      attrs = %{
        org_id: org_id,
        project_id: nil,
        claims: claims,
        is_active: true
      }

      # Use upsert with conditional conflict target
      %__MODULE__{}
      |> changeset(attrs)
      |> Repo.insert(
        on_conflict: {:replace, [:claims, :is_active, :updated_at]},
        conflict_target: {:unsafe_fragment, ~s<("org_id") WHERE project_id IS NULL>},
        returning: true
      )
    else
      {:error, :invalid_claims}
    end
  end

  def create_or_update_project_config(org_id, _project_id, _claims) when not is_binary(org_id),
    do: {:error, :org_id_required}

  def create_or_update_project_config(_org_id, project_id, _claims)
      when not is_binary(project_id),
      do: {:error, :project_id_required}

  def create_or_update_project_config("", _project_id, _claims), do: {:error, :org_id_required}
  def create_or_update_project_config(_org_id, "", _claims), do: {:error, :project_id_required}

  def create_or_update_project_config(_org_id, _project_id, claims) when not is_list(claims),
    do: {:error, :claims_required}

  def create_or_update_project_config(org_id, project_id, claims)
      when is_binary(org_id) and is_binary(project_id) and is_list(claims) do
    # Validate claims before proceeding
    if Enum.all?(claims, &valid_claim_config?/1) do
      attrs = %{
        org_id: org_id,
        project_id: project_id,
        claims: claims,
        is_active: true
      }

      # Use upsert with conditional conflict target for project-level config
      %__MODULE__{}
      |> changeset(attrs)
      |> Repo.insert(
        on_conflict: {:replace, [:claims, :is_active, :updated_at]},
        conflict_target:
          {:unsafe_fragment, ~s<("org_id", "project_id") WHERE project_id IS NOT NULL>},
        returning: true
      )
    else
      {:error, :invalid_claims}
    end
  end

  def create_or_update_project_config(_org_id, _project_id, _claims),
    do: {:error, :invalid_request}

  def get_org_config(org_id) when not is_binary(org_id), do: {:error, :org_id_required}
  def get_org_config(""), do: {:error, :org_id_required}

  def get_org_config(org_id) do
    query =
      from c in __MODULE__,
        where: c.org_id == ^org_id and is_nil(c.project_id)

    case Repo.one(query) do
      nil ->
        create_default_org_config(org_id)

      config ->
        {:ok, config}
    end
  end

  # Create a default configuration with mandatory claims
  defp create_default_org_config(org_id) do
    claims =
      JWTClaim.standard_claims()
      |> JWTClaim.disable_on_prem_claims()
      |> Enum.map(fn {_name, claim} ->
        %{
          "name" => claim.name,
          "description" => claim.description,
          "is_active" => claim.is_active,
          "is_mandatory" => claim.is_mandatory,
          "is_aws_tag" => claim.is_aws_tag,
          "is_system_claim" => claim.is_system_claim
        }
      end)

    attrs = %{
      org_id: org_id,
      project_id: nil,
      claims: claims,
      is_active: true
    }

    %__MODULE__{}
    |> changeset(attrs)
    |> Repo.insert()
  end

  def get_project_config(org_id, _project_id) when not is_binary(org_id),
    do: {:error, :org_id_required}

  def get_project_config(_org_id, project_id) when not is_binary(project_id),
    do: {:error, :project_id_required}

  def get_project_config("", _project_id), do: {:error, :org_id_required}
  def get_project_config(_org_id, ""), do: {:error, :project_id_required}

  def get_project_config(org_id, project_id) do
    query =
      from c in __MODULE__,
        where: c.org_id == ^org_id and c.project_id == ^project_id

    case Repo.one(query) do
      nil -> get_org_config(org_id)
      config -> {:ok, config}
    end
  end

  def delete_org_config(org_id) when not is_binary(org_id), do: {:error, :org_id_required}
  def delete_org_config(""), do: {:error, :org_id_required}

  def delete_org_config(org_id) do
    query = from(c in __MODULE__, where: c.org_id == ^org_id)

    case Repo.delete_all(query) do
      {0, _} -> {:error, :not_found}
      {_count, _} -> {:ok, :deleted}
    end
  end

  def delete_project_config(org_id, _project_id) when not is_binary(org_id),
    do: {:error, :org_id_required}

  def delete_project_config(_org_id, project_id) when not is_binary(project_id),
    do: {:error, :project_id_required}

  def delete_project_config("", _project_id), do: {:error, :org_id_required}
  def delete_project_config(_org_id, ""), do: {:error, :project_id_required}

  def delete_project_config(org_id, project_id) do
    query =
      from(c in __MODULE__,
        where: c.org_id == ^org_id and c.project_id == ^project_id
      )

    case Repo.one(query) do
      nil -> {:error, :not_found}
      config -> Repo.delete(config)
    end
  end

  defp validate_claims_array(changeset) do
    claims = get_field(changeset, :claims)

    cond do
      is_nil(claims) ->
        changeset

      not is_list(claims) ->
        add_error(changeset, :claims, "must be an array")

      Enum.empty?(claims) ->
        # Empty claims array is valid
        changeset

      not Enum.all?(claims, &valid_claim_config?/1) ->
        add_error(changeset, :claims, "contains invalid claim configuration")

      true ->
        changeset
    end
  end

  defp enforce_default_values(changeset) do
    claims = get_field(changeset, :claims) || []
    standard_claims = JWTClaim.standard_claims()

    updated_claims =
      Enum.map(claims, fn claim -> enforce_default_claim_values(claim, standard_claims) end)

    put_change(changeset, :claims, updated_claims)
  end

  defp enforce_default_claim_values(claim = %{"name" => name}, standard_claims)
       when is_binary(name) do
    case Map.get(standard_claims, name) do
      nil ->
        ensure_non_standard_claim_values(claim)

      standard_claim ->
        claim
        |> ensure_standard_claim_values(standard_claim)
        |> ensure_mandatory_claim_is_active(standard_claim)
    end
  end

  defp enforce_default_claim_values(claim, _standard_claims), do: claim

  defp ensure_standard_claim_values(claim, standard_claim) do
    claim
    |> Map.put("description", standard_claim.description)
    |> Map.put("is_system_claim", standard_claim.is_system_claim)
    |> Map.put("is_aws_tag", standard_claim.is_aws_tag)
    |> Map.put("is_mandatory", standard_claim.is_mandatory)
    |> Map.put("is_aws_tag", standard_claim.is_aws_tag)
  end

  defp ensure_mandatory_claim_is_active(claim, _standard_claim = %{is_mandatory: true}) do
    Map.put(claim, "is_active", true)
  end

  defp ensure_mandatory_claim_is_active(claim, _standard_claim) do
    claim
  end

  defp ensure_non_standard_claim_values(claim) do
    claim
    |> Map.put("is_system_claim", false)
    |> Map.put("is_mandatory", false)
  end

  defp valid_claim_config?(%{"name" => name, "is_active" => is_active})
       when is_binary(name) and is_boolean(is_active) and name != "",
       do: true

  defp valid_claim_config?(_), do: false

  defp filter_claim_fields(changeset) do
    claims = get_field(changeset, :claims)

    if claims && is_list(claims) do
      filtered_claims = Enum.map(claims, &filter_supported_fields/1)
      put_change(changeset, :claims, filtered_claims)
    else
      changeset
    end
  end

  defp filter_supported_fields(claim) when is_map(claim) do
    Map.take(claim, @supported_claim_fields)
  end

  defp filter_supported_fields(claim), do: claim
end
