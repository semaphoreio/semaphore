defmodule Rbac.Okta.Saml.PayloadParser.Test do
  use Rbac.RepoCase, async: true

  alias Rbac.Okta.Saml.PayloadParser, as: Parser

  @org_id Ecto.UUID.generate()
  @recipient "https://testing123.localhost/okta/auth"
  @audience "https://testing123.localhost"
  @okta_issuer "http://www.okta.com/exk207czditgMeFGI697"
  @jump_cloud_issuer "http://www.jumpcloud.com/exk207czditgMeFGI697"
  @sso_url "http://www.okta.com/sso_endpoint"
  @creator_id Ecto.UUID.generate()

  test "saml data not provided => it returns saml not found error" do
    payload = %{}

    assert {:error, :saml_payload_not_found} =
             Parser.parse(integration(@okta_issuer), payload, @recipient, @audience)
  end

  test "saml is invalid base64 => it returns base64 decoding error" do
    payload = %{"SAMLResponse" => "ランダムゴミ"}

    assert {:error, :invalid_base64_encoding} =
             Parser.parse(integration(@okta_issuer), payload, @recipient, @audience)
  end

  test "saml XML is invalid => it returns invalid xml error" do
    payload = %{"SAMLResponse" => Base.encode64("Hello World, I'm not a valid XML")}

    assert {:error, :invalid_xml, _} =
             Parser.parse(integration(@okta_issuer), payload, @recipient, @audience)
  end

  test "valid SAML XML for Okta => returns a parsed SamlPayload" do
    payload =
      Support.Okta.Saml.PayloadBuilder.build(
        %{
          recipient: @recipient,
          audience: @audience,
          issuer: @okta_issuer,
          email: "igor@renderedtext.com"
        },
        :okta
      )

    assert {:ok, _assertions} =
             Parser.parse(
               integration(@okta_issuer),
               URI.decode_query(payload),
               @recipient,
               @audience
             )
  end

  test "valid SAML XML for JumpCloud => returns a parsed SamlPayload" do
    payload =
      Support.Okta.Saml.PayloadBuilder.build(
        %{
          recipient: @recipient,
          audience: @audience,
          issuer: @jump_cloud_issuer,
          email: "igor@renderedtext.com"
        },
        :jump_cloud
      )

    assert {:ok, _assertions} =
             Parser.parse(
               integration(@jump_cloud_issuer),
               URI.decode_query(payload),
               @recipient,
               @audience
             )
  end

  def integration(issuer) do
    {:ok, cert} = Support.Okta.Saml.PayloadBuilder.test_cert()

    {:ok, integration} =
      Rbac.Okta.Integration.create_or_update(@org_id, @creator_id, @sso_url, issuer, cert, false)

    integration
  end
end
