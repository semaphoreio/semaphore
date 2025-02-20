defmodule Secrethub.OpenIDConnect.Utilization do
  def add_token_generated(org_username) do
    # cache organization id so if .well_known is hit we can consider it a usage of the feature
    Cachex.put(:oidc_usage, org_username, org_username)
  end

  def submit_usage(host) do
    org_username = host |> String.split(".") |> List.first()
    # check if we have a token generated for this org
    case check_if_token_generated(org_username) do
      {:ok, _} ->
        # we have a token generated, so we can submit usage
        Watchman.increment({"oidc_usage", [org_username]})

      _ ->
        nil
    end
  end

  defp check_if_token_generated(org_username) do
    Cachex.get(:oidc_usage, org_username)
  end
end
