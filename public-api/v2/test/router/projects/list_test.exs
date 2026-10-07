defmodule Router.Projects.ListTest do
  use PublicAPI.Case

  import Test.PipelinesClient, only: [headers: 1, url: 0]
  import OpenApiSpex.TestAssertions

  describe "authorized users" do
    setup do
      Support.Stubs.init()
      org_id = UUID.uuid4()
      user_id = UUID.uuid4()

      PermissionPatrol.add_permissions(org_id, user_id, "organization.view")

      {:ok, %{org_id: org_id, user_id: user_id}}
    end

    test "good request - endpoint returns paginated projects", ctx do
      project_ids = Enum.map(1..5, fn _ -> UUID.uuid4() end)

      projects =
        Enum.map(project_ids, fn project_id ->
          Support.Stubs.Project.create(%{id: ctx.org_id}, %{id: ctx.user_id}, id: project_id)
        end)

      page_size = 2
      next_page_token = Enum.at(projects, page_size) |> Map.get(:id)

      assert {200, headers, list_res} = list_projects(ctx, page_size: page_size)

      headers_contain(
        expected_headers(next_page_token, page_size),
        headers
      )

      assert projects_in_schema(list_res)
    end

    test "no secrets empty response and no next page pagination links", ctx do
      assert {200, _headers, list_res} = list_projects(ctx, page_size: 2)

      assert list_res == []
    end

    test "one of the projects not owned by request organization", ctx do
      wrong_org = UUID.uuid4()

      project_ids = Enum.map(1..5, fn _ -> UUID.uuid4() end)

      Enum.map(project_ids, fn project_id ->
        Support.Stubs.Project.create(%{id: ctx.org_id}, %{id: ctx.user_id}, id: project_id)
      end)

      Support.Stubs.Project.create(%{id: wrong_org}, %{id: ctx.user_id}, id: UUID.uuid4())

      GrpcMock.stub(ProjecthubMock, :list_keyset, fn _req, _ ->
        alias InternalApi.Projecthub.{ListKeysetResponse, ResponseMeta}
        alias Support.Stubs.DB
        projects = DB.all(:projects) |> DB.extract(:api_model)
        status = %ResponseMeta.Status{code: ResponseMeta.Code.value(:OK)}
        meta = %ResponseMeta{status: status}

        %ListKeysetResponse{
          metadata: meta,
          projects: projects,
          next_page_token: "next",
          previous_page_token: "prev"
        }
      end)

      assert {404, _, _resp} = list_projects(ctx, page_size: 6)
    end
  end

  describe "unauthorized users" do
    setup do
      project_id = UUID.uuid4()
      org_id = UUID.uuid4()
      user_id = UUID.uuid4()

      project = Support.Stubs.Project.create(%{id: org_id}, %{id: user_id}, id: project_id)

      {:ok, %{org_id: org_id, user_id: user_id, project_id: project.id}}
    end

    test "endpoint returns 404", ctx do
      for _i <- 1..10 do
        project_id = UUID.uuid4()
        Support.Stubs.Project.create(%{id: ctx.org_id}, %{id: ctx.user_id}, id: project_id)
      end

      page_size = 2

      assert {404, _, _resp} = list_projects(ctx, page_size: page_size)
    end
  end

  defp list_projects(ctx, params) do
    defaults = %{page_size: 20, page_token: ""}
    params = Map.merge(defaults, Map.new(params))
    {:ok, response} = get_list_projects(ctx, params)
    %{body: body, status_code: status_code, headers: headers} = response
    if(status_code != 200, do: IO.puts("Response body: #{inspect(body)}"))

    body = Jason.decode!(body)

    {status_code, headers, body}
  end

  defp headers_contain(expected_list, headers) do
    Enum.map(expected_list, fn {expected_key, expected_value} = expected ->
      header = Enum.find(headers, nil, fn {key, _value} -> key == expected_key end)

      if header != expected && expected_value != :any_val do
        require Logger
        Logger.error("Response headers do not contain: #{inspect(expected)}")
        Logger.warning("Response headers: #{inspect(headers)}")
        assert false
      end
    end)
  end

  defp expected_headers(_token, page_size) do
    [
      {"link", :any_val},
      {"per-page", "#{page_size}"}
    ]
  end

  defp projects_in_schema(list_res) do
    spec = PublicAPI.ApiSpec.spec()

    assert_schema(list_res, "Projects.ListResponse", spec)
  end

  defp get_list_projects(ctx, params) do
    url = url() <> "/projects?" <> Plug.Conn.Query.encode(params)

    HTTPoison.get(url, headers(ctx))
  end
end
