defmodule Router.PorjectSecrets.ListTest do
  use PublicAPI.Case

  import Test.PipelinesClient, only: [headers: 1, url: 0]
  import OpenApiSpex.TestAssertions

  describe "authorized users, enabled feature" do
    setup do
      Support.Stubs.init()
      project_id = UUID.uuid4()
      org_id = UUID.uuid4()
      user_id = UUID.uuid4()
      project = Support.Stubs.Project.create(%{id: org_id}, %{id: user_id}, id: project_id)

      Support.Stubs.Feature.enable_feature(org_id, "project_level_secrets")
      PermissionPatrol.add_permissions(org_id, user_id, "project.secrets.view", project_id)

      {:ok,
       %{org_id: org_id, user_id: user_id, project_id: project_id, project_name: project.name}}
    end

    test "good request - endpoint returns paginated secrets (correct headers set)", ctx do
      secrets =
        for i <- 1..5,
            do:
              Support.Stubs.Secret.create(
                "secret_no_" <> Integer.to_string(i),
                %{level: :PROJECT, project_id: ctx.project_id},
                %{org_id: ctx.org_id}
              )

      page_size = 2
      next_page_token = Enum.at(secrets, page_size) |> Map.get(:id)

      assert {200, headers, list_res} = list_secrets(ctx, ctx.project_id, page_size: page_size)

      assert headers_contain(
               expected_headers(next_page_token, ctx.project_id, page_size),
               headers
             )

      assert secrets_in_schema(list_res)
    end

    test "good request with project name - endpoint returns paginated secrets (correct headers set)",
         ctx do
      secrets =
        for i <- 1..5,
            do:
              Support.Stubs.Secret.create(
                "secret_no_" <> Integer.to_string(i),
                %{level: :PROJECT, project_id: ctx.project_id},
                %{org_id: ctx.org_id}
              )

      page_size = 2
      next_page_token = Enum.at(secrets, page_size) |> Map.get(:id)

      assert {200, headers, list_res} = list_secrets(ctx, ctx.project_name, page_size: page_size)

      assert headers_contain(
               expected_headers(next_page_token, ctx.project_name, page_size),
               headers
             )

      assert secrets_in_schema(list_res)
    end

    test "no secrets empty response and no next page pagination links", ctx do
      assert {200, headers, list_res} = list_secrets(ctx, ctx.project_id, page_size: 2)

      assert list_res == []

      assert headers_contain(
               [
                 {"link", "<#{link("", ctx.project_id, 2)}>; rel=\"first\""}
               ],
               headers
             )
    end

    test "GET /secrets - with one of the secrets not owned by the users organization returns 404",
         ctx do
      wrong_org = UUID.uuid4()

      GrpcMock.stub(SecretMock, :list_keyset, fn _req, _ ->
        alias InternalApi.Secrethub.ResponseMeta

        secrets =
          for i <- 1..5,
              do:
                Support.Stubs.Secret.create(
                  "secret_no_" <> Integer.to_string(i),
                  %{level: :PROJECT, org_id: wrong_org, project_id: ctx.project_id}
                )

        api_secrets = Enum.map(secrets, fn secret -> secret.api_model end)

        %InternalApi.Secrethub.ListKeysetResponse{
          secrets: api_secrets,
          next_page_token: "asdf",
          metadata: %ResponseMeta{
            status: %ResponseMeta.Status{code: ResponseMeta.Code.value(:OK)}
          }
        }
      end)

      assert {404, _headers, error_resp} = list_secrets(ctx, ctx.project_id, page_size: 2)
      assert %{"message" => "Not found"} = error_resp
    end
  end

  describe "unauthorized users" do
    setup do
      project_id = UUID.uuid4()
      org_id = UUID.uuid4()
      user_id = UUID.uuid4()

      Support.Stubs.Project.create(%{id: org_id}, %{id: user_id}, id: project_id)

      Support.Stubs.Feature.enable_feature(org_id, "project_level_secrets")

      {:ok, %{org_id: org_id, user_id: user_id, project_id: project_id}}
    end

    test "endpoint returns 404", ctx do
      for i <- 1..10,
          do:
            Support.Stubs.Secret.create(
              "secret_no_" <> Integer.to_string(i),
              %{level: :PROJECT, project_id: ctx.project_id},
              %{org_id: ctx.org_id}
            )

      page_size = 2

      assert {404, _, _resp} = list_secrets(ctx, ctx.project_id, page_size: page_size)
    end
  end

  defp list_secrets(ctx, project, params) do
    defaults = %{page_size: 20, page_token: ""}
    params = Map.merge(defaults, Map.new(params))
    {:ok, response} = get_list_secrets(ctx, project, params)
    %{body: body, status_code: status_code, headers: headers} = response
    if(status_code != 200, do: IO.puts("Response body: #{inspect(body)}"))

    body = Jason.decode!(body)

    {status_code, headers, body}
  end

  defp headers_contain(list, headers) do
    Enum.map(list, fn value ->
      unless Enum.find(headers, nil, fn x -> x == value end) != nil do
        require Logger
        Logger.error("Response headers do not contain: #{inspect(value)}")
        Logger.warning("Response headers: #{inspect(headers)}")
        assert false
      end
    end)
  end

  defp expected_headers(token, project_id, page_size) do
    [
      {"link",
       "<#{link(token, project_id, page_size)}>; rel=\"next\", <#{link("", project_id, page_size)}>; rel=\"first\""},
      {"per-page", "#{page_size}"}
    ]
  end

  defp link(token, project_id, page_size) do
    "http://localhost:4004/api/#{api_version()}/projects/#{project_id}/secrets?" <>
      URI.encode("page_size=#{page_size}&page_token=#{token}")
  end

  defp secrets_in_schema(list_res) do
    spec = PublicAPI.ApiSpec.spec()

    assert_schema(list_res, "ProjectSecrets.ListResponse", spec)
  end

  defp api_version(), do: System.get_env("API_VERSION")

  defp get_list_secrets(ctx, project_id_or_name, params) do
    url = url() <> "/projects/#{project_id_or_name}/secrets?" <> Plug.Conn.Query.encode(params)

    HTTPoison.get(url, headers(ctx))
  end
end
