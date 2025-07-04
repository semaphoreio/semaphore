defmodule Support.Okta.Saml.PayloadBuilder do
  @moduledoc """
  In the SAML API tests, we need to build SAML payloads to verify if
  the API is able to consume them.

  We need to build this payload dynamically in order to inject
  proper dates and successfully digitally sign the payload.

  The payload is an XML document.
  See an example: test/support/okta/saml/payload_example.xml.

  The payload should contain:
  - The subject that is logging in: ex: igor@renderedtext.com
  - Valid timestamps: IssuedInstant, NotOnOrAfter, NotBefore, etc...
  - Valid digital signatures for the envelope and for the assertions
  """

  require Support.Okta.Saml.XML
  alias Support.Okta.Saml.XML, as: XML

  def build(inputs, issuer) do
    unless issuer in [:okta, :jump_cloud], do: raise("Issuer must be either :okta or :jump_cloud")
    unless Map.has_key?(inputs, :recipient), do: raise("Must have a recipient")
    unless Map.has_key?(inputs, :issuer), do: raise("Must have an issuer")
    unless Map.has_key?(inputs, :email), do: raise("Must have an email")
    unless Map.has_key?(inputs, :audience), do: raise("Must have an audience")

    now = DateTime.utc_now()
    not_after = DateTime.add(now, 600, :second)

    iso_now = DateTime.to_iso8601(now)
    iso_not_after = DateTime.to_iso8601(not_after)

    inputs =
      Map.merge(inputs, %{
        issue_instant: iso_now,
        not_before: iso_now,
        authn_instant: iso_now,
        not_on_or_after: iso_not_after
      })

    inputs
    |> saml_response()
    |> sign_response(issuer)
    |> serialize()
  end

  defp sign_response(response, :okta), do: response |> sign()
  defp sign_response(response, :jump_cloud), do: response

  defp saml_response(inputs) do
    XML.el(
      name: "saml2p:Response",
      attributes: [
        XML.attr("Destination", inputs.recipient),
        XML.attr("ID", "id390583926959464451773798740"),
        XML.attr("IssueInstant", "2022-08-22T11:55:32.522Z"),
        XML.attr("Version", "2.0"),
        XML.attr("xmlns:saml2p", "urn:oasis:names:tc:SAML:2.0:protocol")
      ],
      content: [
        status(),
        assertion(inputs)
      ]
    )
  end

  defp status do
    XML.el(
      name: "saml2p:Status",
      attributes: [
        XML.attr("xmlns:saml2p", "urn:oasis:names:tc:saml:2.0:protocol")
      ],
      content: [
        XML.el(
          name: "saml2p:StatusCode",
          attributes: [
            XML.attr("Value", "urn:oasis:names:tc:SAML:2.0:status:Success")
          ]
        )
      ]
    )
  end

  defp assertion(inputs) do
    XML.el(
      name: "saml2:Assertion",
      attributes: [
        XML.attr("ID", "id39058392696107999797089705"),
        XML.attr("IssueInstant", inputs.issue_instant),
        XML.attr("Version", "2.0"),
        XML.attr("xmlns:saml2", "urn:oasis:names:tc:SAML:2.0:assertion")
      ],
      content: [
        issuer(inputs),
        subject(inputs),
        conditions(inputs),
        authn_statement(inputs),
        attribute_statement(inputs)
      ]
    )
    |> sign()
  end

  defp attribute_statement(inputs) do
    XML.el(
      name: "saml2:AttributeStatement",
      attributes: [
        XML.attr("xmlns:saml2", "urn:oasis:names:tc:SAML:2.0:assertion")
      ],
      content: create_attributes(inputs[:attributes] || [])
    )
  end

  defp create_attributes(attributes) do
    Enum.map(attributes, fn {name, value} -> create_attribute(name, value) end)
  end

  defp create_attribute(name, value) do
    XML.el(
      name: "saml2:Attribute",
      attributes: [
        XML.attr("Name", name),
        XML.attr("NameFormat", "urn:oasis:names:tc:SAML:2.0:attrname-format:basic")
      ],
      content: [
        XML.el(
          name: "saml2:AttributeValue",
          attributes: [
            XML.attr("xmlns:xsi", "http://www.w3.org/2001/XMLSchema-instance"),
            XML.attr("xsi:type", "xs:string")
          ],
          content: [XML.text(value)]
        )
      ]
    )
  end

  defp conditions(inputs) do
    XML.el(
      name: "saml2:Conditions",
      attributes: [
        XML.attr("NotBefore", inputs.not_before),
        XML.attr("NotOnOrAfter", inputs.not_on_or_after),
        XML.attr("xmlns:saml2", "urn:oasis:names:tc:SAML:2.0:assertion")
      ],
      content: [
        XML.el(
          name: "saml2:AudienceRestriction",
          content: [
            XML.el(
              name: "saml2:Audience",
              content: [
                XML.text(inputs.audience)
              ]
            )
          ]
        )
      ]
    )
  end

  defp issuer(inputs) do
    XML.el(
      name: "saml2:Issuer",
      attributes: [
        XML.attr("Format", "urn:oasis:names:tc:SAML:2.0:nameid-format:entity"),
        XML.attr("xmlns:saml2", "urn:oasis:names:tc:SAML:2.0:assertion")
      ],
      content: [
        XML.text(inputs.issuer)
      ]
    )
  end

  defp authn_statement(inputs) do
    XML.el(
      name: "saml2:AuthnStatement",
      attributes: [
        XML.attr("AuthnInstant", inputs.authn_instant),
        XML.attr("SessionIndex", "id1661169332521.1242430099"),
        XML.attr("xmlns:saml2", "urn:oasis:names:tc:SAML:2.0:assertion")
      ],
      content: [
        XML.el(
          name: "saml2:AuthnContext",
          content: [
            XML.el(
              name: "saml2:AuthnContextClassRef",
              content: [
                XML.text("urn:oasis:names:tc:SAML:2.0:ac:classes:PasswordProtectedTransport")
              ]
            )
          ]
        )
      ]
    )
  end

  defp subject(inputs) do
    XML.el(
      name: "saml2:Subject",
      attributes: [
        XML.attr("xmlns:saml2", "urn:oasis:names:tc:SAML:2.0:assertion")
      ],
      content: [
        name(inputs),
        subject_confirmation(inputs)
      ]
    )
  end

  defp name(inputs) do
    XML.el(
      name: "saml2:NameID",
      attributes: [
        XML.attr("Format", "urn:oasis:names:tc:SAML:1.1:nameid-format:unspecified")
      ],
      content: [
        XML.text(inputs.email)
      ]
    )
  end

  defp subject_confirmation(inputs) do
    XML.el(
      name: "saml2:SubjectConfirmation",
      attributes: [
        XML.attr("Method", "urn:oasis:names:tc:SAML:2.0:cm:bearer")
      ],
      content: [
        XML.el(
          name: "saml2:SubjectConfirmationData",
          attributes: [
            XML.attr("NotOnOrAfter", inputs.not_on_or_after),
            XML.attr("Recipient", inputs.recipient)
          ]
        )
      ]
    )
  end

  #
  # Utility methods for serializing the XML object into a format that is
  # sent over the wire
  #

  defp serialize(el) do
    # first, convert the XML object to a canonical string
    text = to_string(:xmerl_c14n.c14n(el))

    # then, encode the payload into a Base64 represenation
    encoded = Base.encode64(text)

    # finally, prepare it as a :urlencoded body parameter
    URI.encode_query(%{"SAMLResponse" => encoded})
  end

  #
  # Utilities for digitally signing XML elements
  # Inputs: Normal element.
  # Output: Signed XML element, with ds tags. (ds stands for digital signature)
  #
  defp sign(el) do
    canon = :xmerl_c14n.c14n(el)
    {xml, _} = :xmerl_scan.string(canon, namespace_conformant: true)

    {certificate, key} = test_sign_256_key()

    :xmerl_dsig.sign(xml, key, certificate, :rsa_sha256)
  end

  def test_sign_256_key do
    # The test private key and certificate were created with:
    #
    # openssl genrsa -out private.key 2048
    # openssl req -key private.key -new -x509 -out cert.crt
    #

    {:ok, binary} = File.read("test/support/okta/saml/test_private.key")
    [rsa_entry] = :public_key.pem_decode(binary)
    private_key = :public_key.pem_entry_decode(rsa_entry, "")

    {:ok, cert} = test_cert()
    {:ok, decoded} = Rbac.Okta.Saml.Certificate.decode(cert)

    {decoded, private_key}
  end

  def test_cert do
    File.read("test/support/okta/saml/test_cert.crt")
  end
end
