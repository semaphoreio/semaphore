defmodule Router.Notifications.ListTest do
  use PublicAPI.Case

  import Test.PipelinesClient, only: [headers: 1, url: 0]
  import OpenApiSpex.TestAssertions

  describe "authorized users" do
    setup do
      Support.Stubs.init()
      org_id = UUID.uuid4()
      user_id = UUID.uuid4()

      org = Support.Stubs.Organization.create(org_id: org_id)

      PermissionPatrol.add_permissions(org_id, user_id, "organization.notifications.view")

      {:ok, %{org_id: org_id, user_id: user_id, org: org}}
    end

    test "GET /notifications - endpoint returns paginated notifications", ctx do
      for i <- 1..5,
          do:
            Support.Stubs.Notifications.create(
              ctx.org,
              name: "notification_no_" <> Integer.to_string(i)
            )

      page_size = 2

      assert {200, _headers, list_res} = list_notifications(ctx, page_size: page_size)
      assert notifications_in_schema(list_res)
    end

    test "no notifications -> empty response", ctx do
      assert {200, headers, list_res} = list_notifications(ctx, page_size: 2)

      assert list_res == []

      assert headers_contain(
               [
                 {"link", "<#{link("", 2)}>; rel=\"first\""}
               ],
               headers
             )
    end

    test "notification in response not owned by requester org", ctx do
      GrpcMock.stub(NotificationsMock, :list, fn _req, _ ->
        %InternalApi.Notifications.ListResponse{
          notifications: [
            %InternalApi.Notifications.Notification{
              id: UUID.uuid4(),
              org_id: UUID.uuid4(),
              name: "notification_example"
            }
          ],
          next_page_token: ""
        }
      end)

      assert {404, _headers, _resp} = list_notifications(ctx, page_size: 2)
    end
  end

  describe "unauthorized users" do
    setup do
      org_id = UUID.uuid4()
      user_id = UUID.uuid4()
      org = Support.Stubs.Organization.create(org_id: org_id)

      {:ok, %{org_id: org_id, user_id: user_id, org: org}}
    end

    test "GET /notifications - endpoint returns 404", ctx do
      for i <- 1..5,
          do:
            Support.Stubs.Notifications.create(
              ctx.org,
              name: "notification_no_" <> Integer.to_string(i)
            )

      page_size = 2

      assert {404, _, resp} = list_notifications(ctx, page_size: page_size)
      spec = PublicAPI.ApiSpec.spec()
      assert_schema(resp, "Error", spec)
    end
  end

  defp list_notifications(ctx, params) do
    defaults = %{page_size: 20, page_token: ""}
    params = Map.merge(defaults, Map.new(params))
    {:ok, response} = get_list_notifications(ctx, params)
    %{body: body, status_code: status_code, headers: headers} = response
    if(status_code != 200, do: IO.puts("Response body: #{inspect(body)}"))

    body = Jason.decode!(body)

    {status_code, headers, body}
  end

  defp link(token, page_size) do
    "http://localhost:4004/api/#{api_version()}/notifications?" <>
      URI.encode("page_size=#{page_size}&page_token=#{token}")
  end

  defp notifications_in_schema(list_res) do
    spec = PublicAPI.ApiSpec.spec()

    assert_schema(list_res, "Notifications.ListResponse", spec)
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

  defp api_version(), do: System.get_env("API_VERSION")

  defp get_list_notifications(ctx, params) do
    url = url() <> "/notifications?" <> Plug.Conn.Query.encode(params)

    HTTPoison.get(url, headers(ctx))
  end
end
