defmodule Support.Factories.OktaIntegration do
  alias Rbac.Repo.OktaIntegration
  alias Ecto.UUID

  @doc """
    Expected arg options:
    - org_id (organization which owns the mapper)
    - creator_id
    - sso_url
    - saml_issuer (also needs to be url)
    - cert_fingerprint (valid)
    - jit_provisioning_enabled (bool)
    - session_expiration_minutes (integer)

    All of these parameters are optional.
    If they are not present they will be generated.
  """
  def insert(options \\ []) do
    %OktaIntegration{
      org_id: get_id(options[:org_id]),
      creator_id: get_id(options[:creator_id]),
      sso_url: get_url(options[:sso_url]),
      saml_issuer: get_url(options[:saml_issuer]),
      saml_certificate_fingerprint: get_cert(options[:cert_fingerprint]),
      jit_provisioning_enabled: options[:jit_provisioning_enabled] || false,
      session_expiration_minutes:
        get_session_expiration_minutes(options[:session_expiration_minutes])
    }
    |> Rbac.Repo.insert(on_conflict: :replace_all, conflict_target: :id)
  end

  defp get_id(nil), do: UUID.generate()
  defp get_id(id), do: id

  defp get_string(nil), do: for(_ <- 1..10, into: "", do: <<Enum.random(~c"abcdefghijk")>>)
  defp get_string(string), do: string

  defp get_url(nil), do: "https://#{get_string(nil)}.com/#{get_string(nil)}"
  defp get_url(url_string), do: url_string

  defp get_cert(nil),
    do:
      Support.Okta.Saml.PayloadBuilder.test_cert()
      |> elem(1)
      |> Rbac.Okta.Saml.Certificate.fingerprint()
      |> elem(1)
      |> Base.encode64()

  defp get_cert(cert), do: cert

  defp get_session_expiration_minutes(nil), do: 20_160
  defp get_session_expiration_minutes(value), do: value
end
