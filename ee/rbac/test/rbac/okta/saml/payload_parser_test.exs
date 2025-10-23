defmodule Rbac.Okta.Saml.PayloadParser.Test do
  use Rbac.RepoCase, async: true

  import Mock
  alias Rbac.Okta.Saml.PayloadParser, as: Parser

  @org_id Ecto.UUID.generate()
  @recipient "https://testing123.localhost/okta/auth"
  @audience "https://testing123.localhost"
  @okta_issuer "http://www.okta.com/exk207czditgMeFGI697"
  @jump_cloud_issuer "http://www.jumpcloud.com/exk207czditgMeFGI697"
  @sso_url "http://www.okta.com/sso_endpoint"
  @email "igor@renderedtext.com"
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

  test "valid SAML XML without attributes => returns a parsed SamlPayload" do
    payload =
      Support.Okta.Saml.PayloadBuilder.build(
        %{
          recipient: @recipient,
          audience: @audience,
          issuer: @okta_issuer,
          email: @email
        },
        :okta
      )

    assert {:ok, @email, %{}} =
             Parser.parse(
               integration(@okta_issuer),
               URI.decode_query(payload),
               @recipient,
               @audience
             )
  end

  test "valid SAML XML with attributes => returns a parsed SamlPayload" do
    # When processing assertions, '/' should be trimmerd, and first character should always be lowercase
    attributes = [
      {"member", "group1/"},
      {"member", "/group2"},
      {"/Role/", "User"}
    ]

    payload =
      Support.Okta.Saml.PayloadBuilder.build(
        %{
          recipient: @recipient,
          audience: @audience,
          issuer: @jump_cloud_issuer,
          email: @email,
          attributes: attributes
        },
        :jump_cloud
      )

    assert {:ok, @email, %{"role" => ["user"], "member" => ["group2", "group1"]}} =
             Parser.parse(
               integration(@jump_cloud_issuer),
               URI.decode_query(payload),
               @recipient,
               @audience
             )
  end

  def integration(issuer) do
    {:ok, cert} = Support.Okta.Saml.PayloadBuilder.test_cert()

    with_mocks([
      {Rbac.Api.Organization, [],
       [
         find_by_id: fn _ -> {:ok, %{allowed_id_providers: []}} end,
         update: fn _ -> {:ok, %{}} end
       ]}
    ]) do
      {:ok, integration} =
        Rbac.Okta.Integration.create_or_update(
          @org_id,
          @creator_id,
          @sso_url,
          issuer,
          cert,
          false
        )

      integration
    end
  end
end
