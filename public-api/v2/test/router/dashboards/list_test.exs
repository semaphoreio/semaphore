defmodule Router.Dashboards.ListTest do
  use PublicAPI.Case

  import Test.PipelinesClient, only: [headers: 1, url: 0]
  import OpenApiSpex.TestAssertions

  describe "authorized users" do
    setup do
      Support.Stubs.init()
      org_id = UUID.uuid4()
      user_id = UUID.uuid4()

      org = Support.Stubs.Organization.create(org_id: org_id)

      PermissionPatrol.add_permissions(org_id, user_id, "organization.dashboards.view")

      {:ok, %{org_id: org_id, user_id: user_id, org: org}}
    end

    test "GET /dashboards - endpoint returns paginated dashboards (correct headers set)", ctx do
      for _i <- 1..5,
          do: Support.Stubs.Dashboards.create(ctx.org)

      page_size = 2

      assert {200, _headers, list_res} = list_dashboards(ctx, page_size: page_size)

      assert length(list_res) == 2
      assert dashboards_in_schema(list_res)
    end

    test "GET /dashboards - no dashboards -> empty response and no next page pagination links",
         ctx do
      assert {200, headers, list_res} = list_dashboards(ctx, page_size: 2)

      assert list_res == []

      assert headers_contain(
               [
                 {"link", "<#{link("", 2)}>; rel=\"first\""}
               ],
               headers
             )
    end

    test "GET /dashboards - dashboard not owned by requester org -> not found", ctx do
      wrong_org = UUID.uuid4()

      for _i <- 1..5,
          do: Support.Stubs.Dashboards.create(%{id: wrong_org})

      GrpcMock.stub(DashboardMock, :list, fn req, _ ->
        alias Support.Stubs.DB

        dashboards =
          DB.filter(:dashboards, org_id: wrong_org)
          |> DB.extract(:api_model)
          |> Enum.take(req.page_size)

        %InternalApi.Dashboardhub.ListResponse{dashboards: dashboards}
      end)

      assert {404, _headers, resp} = list_dashboards(ctx, page_size: 2)
      assert %{"message" => "Not found"} = resp
    end
  end

  describe "unauthorized users" do
    setup do
      org_id = UUID.uuid4()
      user_id = UUID.uuid4()

      org = Support.Stubs.Organization.create(org_id: org_id)

      {:ok, %{org_id: org_id, user_id: user_id, org: org}}
    end

    test "GET /dashboards - endpoint returns paginated dashboards (correct headers set)", ctx do
      for _i <- 1..5,
          do: Support.Stubs.Dashboards.create(ctx.org)

      page_size = 2

      assert {404, _headers, list_res} = list_dashboards(ctx, page_size: page_size)
      spec = PublicAPI.ApiSpec.spec()
      assert_schema(list_res, "Error", spec)
    end
  end

  defp list_dashboards(ctx, params) do
    defaults = %{page_size: 20, page_token: ""}
    params = Map.merge(defaults, Map.new(params))
    {:ok, response} = get_list_dashboards(ctx, params)
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

  defp link(token, page_size) do
    "http://localhost:4004/api/#{api_version()}/dashboards?" <>
      URI.encode("page_size=#{page_size}&page_token=#{token}")
  end

  defp dashboards_in_schema(list_res) do
    spec = PublicAPI.ApiSpec.spec()

    assert_schema(list_res, "Dashboards.ListResponse", spec)
  end

  defp api_version(), do: System.get_env("API_VERSION")

  defp get_list_dashboards(ctx, params) do
    url = url() <> "/dashboards?" <> Plug.Conn.Query.encode(params)

    HTTPoison.get(url, headers(ctx))
  end
end
