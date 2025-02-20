defmodule Ppl.Cache.OrganizationSettingsTest do
  use ExUnit.Case, async: false
  import Mock

  alias Ppl.Cache.OrganizationSettings
  alias InternalApi.Organization, as: API

  @cache_name Application.compile_env!(:ppl, [OrganizationSettings, :cache_name])
  @cache_ttl Application.compile_env!(:ppl, [OrganizationSettings, :expiration_ttl])
  @url_env_var "INTERNAL_API_URL_ORGANIZATION"
  @mock_port 51_521

  setup_all _ctx do
    {:ok, %{port: port}} = Test.Support.GrpcServerHelper.start_server_with_cleanup(OrganizationServiceMock)

    {:ok,
     port: port,
     org_id: UUID.uuid4(),
     settings: %{
       "plan_machine_type" => "e2-standard-4",
       "plan_os_image" => "ubuntu2004",
       "custom_machine_type" => "f1-standard-2",
       "custom_os_image" => "ubuntu2204"
     }}
  end

  setup %{port: port} do
    old_url = System.get_env(@url_env_var)
    Test.Support.GrpcServerHelper.setup_service_url(@url_env_var, port)
    on_exit(fn -> System.put_env(@url_env_var, old_url) end)
  end

  describe "get/2" do
    @tag capture_log: true
    test "when Organization API is unavailable then returns error",
         ctx = %{org_id: org_id, settings: settings} do
      Cachex.del(@cache_name, org_id)
      System.put_env(@url_env_var, "non-existent:#{9999}")

      assert {:error, :timeout} = OrganizationSettings.get(org_id, Map.keys(settings))
      assert {:ok, nil} = Cachex.get(@cache_name, org_id)
    end

    test "when role_ids are empty then returns empty map", %{org_id: org_id} do
      assert {:ok, %{}} = OrganizationSettings.get(org_id, [])
    end
  end

  describe "get/2 when organization settings have not been cached" do
    setup ctx do
      GrpcMock.expect(OrganizationServiceMock, :fetch_organization_settings, fn _request,
                                                                                _stream ->
        API.FetchOrganizationSettingsResponse.new(
          settings:
            Enum.into(ctx.settings, [], fn {key, value} ->
              API.OrganizationSetting.new(key: key, value: value)
            end)
        )
      end)

      Cachex.del(@cache_name, ctx.org_id)
      on_exit(fn -> GrpcMock.verify!(OrganizationServiceMock) end)
    end

    test "then calls Organization API to fetch them",
         ctx = %{org_id: org_id, settings: settings} do
      assert {:ok, ^settings} = OrganizationSettings.get(org_id, Map.keys(settings))
    end

    test "then caches fetched roles", ctx = %{org_id: org_id, settings: settings} do
      assert {:ok, ^settings} = OrganizationSettings.get(org_id, Map.keys(settings))
      assert {:ok, ^settings} = Cachex.get(@cache_name, org_id)
    end

    test "then TTL is reset", ctx = %{org_id: org_id, settings: settings} do
      assert {:ok, ^settings} = OrganizationSettings.get(org_id, Map.keys(settings))
      assert {:ok, ttl} = Cachex.ttl(@cache_name, org_id)
      assert_in_delta ttl, @cache_ttl * 1_000, 1_000
    end
  end

  describe "get/2 when organization settings have been cached" do
    setup ctx do
      GrpcMock.expect(OrganizationServiceMock, :fetch_organization_settings, 0, fn _request,
                                                                                   _stream ->
        API.FetchOrganizationSettingsResponse.new(
          settings:
            Enum.into(ctx.settings, [], fn {key, value} ->
              API.OrganizationSetting.new(key: key, value: value)
            end)
        )
      end)

      Cachex.put(@cache_name, ctx.org_id, ctx.settings, ttl: 90_000)
      on_exit(fn -> Cachex.del(@cache_name, ctx.org_id) end)

      on_exit(fn -> GrpcMock.verify!(OrganizationServiceMock) end)
    end

    test "then does not call Organization API", ctx = %{org_id: org_id, settings: settings} do
      assert {:ok, ^settings} = OrganizationSettings.get(org_id, Map.keys(settings))
    end

    test "then cache is untouched", ctx = %{org_id: org_id, settings: settings} do
      assert {:ok, ^settings} = Cachex.get(@cache_name, org_id)
      assert {:ok, ^settings} = OrganizationSettings.get(org_id, Map.keys(settings))
      assert {:ok, ^settings} = Cachex.get(@cache_name, org_id)
    end

    test "then TTL is kept", ctx = %{org_id: org_id, settings: settings} do
      assert {:ok, ^settings} = OrganizationSettings.get(org_id, Map.keys(settings))
      assert {:ok, ttl} = Cachex.ttl(@cache_name, org_id)
      assert_in_delta ttl, 90_000, 1_000
    end
  end
end
