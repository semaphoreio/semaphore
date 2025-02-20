defmodule E2E.Clients.Secret do
  @api_endpoint "api/v1beta"

  alias E2E.Clients.Common

  @doc """
  Lists organization secrets
  Returns {:ok, response} on success, {:error, reason} on failure.
  """
  def list, do: Common.get("#{@api_endpoint}/secrets")

  @doc """
  Creates a new secret.
  Params example:
    %{
      metadata: %{
        name: "app-credentials",
      },
      data: %{
        env_vars: [
          %{
            name: "DATABASE_URL",
            value: "postgres://user:pass@localhost:5432/mydb"
          },
        ],
        files: [
          %{
            path: "/etc/ssl/private/cert.pem",
            content: "-----BEGIN CERTIFICATE-----\nMIIEpDCCA...-----END CERTIFICATE-----"
          },
        ]
      }
    }
  Returns {:ok, response} on success, {:error, reason} on failure.
  """
  def create(params) do
    Common.post("#{@api_endpoint}/secrets", params)
  end
end
