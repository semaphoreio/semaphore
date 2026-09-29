defmodule Rbac.Okta.Saml.PayloadParser do
  @moduledoc """
  This module parses and validated the SAML payload that is sent by Okta
  when a customer clicks on our application in the Okta
  interface.

  The Payload is a Base64 encoded XML data, signed with a 256 bit lenght key.
  """

  import Rbac.Okta.Saml.Esaml

  def parse(okta_integration, params, consume_uri, metadata_uri) do
    with sp <- construct_service_provider_details(okta_integration, consume_uri, metadata_uri),
         {:ok, payload} <- extract_saml_response(params),
         {:ok, decoded} <- decode_payload(payload),
         {:ok, assertion} <- validate_assertion(decoded, sp) do
      email = esaml_assertion(assertion, :subject) |> esaml_subject(:name)
      attributes = esaml_assertion(assertion, :attributes) |> construct_attributes_map()

      {:ok, email |> to_string |> String.downcase(), attributes}
    end
  end

  defp extract_saml_response(params) do
    case Map.fetch(params, "SAMLResponse") do
      {:ok, payload} -> {:ok, payload}
      :error -> {:error, :saml_payload_not_found}
    end
  end

  defp decode_payload(payload) do
    xml = :esaml_binding.decode_response("", payload)

    {:ok, xml}
  rescue
    _ -> {:error, :invalid_base64_encoding}
  catch
    :exit, {:fatal, e = {:expected_element_start_tag, _, _, _}} ->
      {:error, :invalid_xml, e}

    :exit, e ->
      {:error, :invalid_xml, e}
  end

  defp construct_attributes_map(attributes) do
    Enum.reduce(attributes, %{}, fn {name, value}, acc ->
      name = name |> Atom.to_string() |> sanitize_string()
      value = to_string(value) |> sanitize_string()
      Map.update(acc, name, [value], &(&1 ++ [value]))
    end)
  end

  defp sanitize_string(string) do
    <<first::utf8, rest::binary>> = string |> String.trim("/")
    <<String.downcase(<<first::utf8>>)::binary, rest::binary>>
  end

  defp validate_assertion(saml, sp) do
    :esaml_sp.validate_assertion(saml, sp)
  end

  defp construct_service_provider_details(okta_integration, consume_uri, metadata_uri) do
    require Rbac.Okta.Saml.Esaml

    Rbac.Okta.Saml.Esaml.esaml_sp(
      consume_uri: to_charlist(consume_uri),
      metadata_uri: to_charlist(metadata_uri),
      # Okta signs both envelope and assertion, while JumpCloud signs only assertion
      idp_signs_envelopes: okta_integration.saml_issuer =~ "www.okta.com",
      idp_signs_assertions: true,
      trusted_fingerprints: [Base.decode64!(okta_integration.saml_certificate_fingerprint)]
    )
  end
end
