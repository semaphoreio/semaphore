defmodule Secrethub.OpenIDConnect.JWTFilter do
  @moduledoc """
  Handles filtering of OIDC claims based on feature flags and configuration.
  """

  alias Secrethub.OpenIDConnect.JWTConfiguration

  @aws_tags_claim "https://aws.amazon.com/tags"

  def filter_enabled?(org_id),
    do: FeatureProvider.feature_enabled?(:open_id_connect_filter, param: org_id)

  @doc """
  Filters JWT claims based on organization or project settings.
  Uses JWT configuration if available, otherwise falls back to essential claims.
  Returns filtered claims map.
  """
  def filter_claims(claims, org_id, project_id) when is_map(claims) do
    if filter_enabled?(org_id) do
      _filter_claims(claims, org_id, project_id)
    else
      {:ok, claims}
    end
  end

  def filter_claims(_claims, _org_id, _project_id), do: {:error, :invalid_claims}

  def _filter_claims(claims, org_id, project_id) do
    case get_allowed_claims(org_id, project_id) do
      {:ok, allowed_claims} ->
        filtered_claims =
          claims
          |> Enum.filter(fn {key, _value} -> key in allowed_claims end)
          |> Enum.into(%{})

        filter_aws_tags(filtered_claims, allowed_claims)

      err ->
        err
    end
  end

  # Private function to filter AWS tags
  defp filter_aws_tags(claims, allowed_claims) do
    case Map.get(claims, @aws_tags_claim) do
      nil ->
        {:ok, claims}

      aws_tags ->
        filtered_principal_tags =
          aws_tags["principal_tags"]
          |> Enum.filter(fn {key, _value} -> key in allowed_claims end)
          |> Enum.into(%{})

        filtered_claims =
          Map.put(claims, @aws_tags_claim, %{
            "principal_tags" => filtered_principal_tags,
            "transitive_tag_keys" => Map.keys(filtered_principal_tags)
          })

        {:ok, filtered_claims}
    end
  end

  @doc """
  Gets the allowed claims for an organization from JWT configuration.
  Returns a list of active claim names or error tuple.
  """
  def get_allowed_claims(org_id, project_id) do
    case JWTConfiguration.get_project_config(org_id, project_id) do
      {:ok, config} ->
        active_claims =
          config.claims
          |> Enum.filter(fn claim -> claim["is_active"] == true end)
          |> Enum.map(fn claim -> claim["name"] end)
          |> Enum.sort()

        {:ok, active_claims}

      err ->
        err
    end
  end
end
