defmodule Rbac.Okta.Saml.Certificate do
  @moduledoc """
  Certificates in PEM format are Base 64 encoded versions of a binary
  DER format.

  A typical certificate looks like this:

    -----BEGIN CERTIFICATE-----
    ...
    base64 encoded DER
    ...
    -----END CERTIFICATE-----

  To decode it we apply two operations:

    1. Remove the header and footer
    2. Run a Base64 decode on the rest

  """

  alias X509.Certificate

  @begin_header "-----BEGIN CERTIFICATE-----"
  @end_header "-----END CERTIFICATE-----"

  @spec fingerprint(String.t()) :: {:ok, String.t()} | {:error, any()}
  def fingerprint(saml_certificate) do
    validate_cert(saml_certificate)

    case decode(saml_certificate) do
      {:ok, decoded} -> {:ok, :crypto.hash(:sha, decoded)}
    end
  rescue
    _e -> {:error, :cert_decode_error}
  end

  def decode(cert) do
    cert
    |> remove_headers()
    |> Base.decode64()
  end

  defp remove_headers(cert) do
    cert
    |> String.split("\n")
    |> Enum.filter(fn x ->
      !String.contains?(x, @begin_header) && !String.contains?(x, @end_header)
    end)
    |> Enum.map_join(&String.trim/1)
  end

  defp validate_cert(certificate) do
    Certificate.from_pem!(certificate)
  end
end
