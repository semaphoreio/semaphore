defmodule Ppl.PFCClientTest do
  use ExUnit.Case, async: false
  alias Ppl.PFCClient

  alias InternalApi.PreFlightChecksHub, as: API

  @url_env_var "INTERNAL_API_URL_PFC"
  @mock_port 51_520

  setup_all [:setup_grpc_mock, :setup_organization_pfc, :setup_project_pfc]

  describe "PFCClient.describe/2" do
    test "when pipeline has pre-flight checks configured for both organization and project" <>
           "then returns both non-empty pre-flight checks",
         context do
      organization_id = context[:org_id]
      project_id = context[:prj_id]

      pfcs = %{
        "organization_pfc" => %{
          "commands" => context[:org_pfc][:commands],
          "secrets" => context[:org_pfc][:secrets]
        },
        "project_pfc" => %{
          "commands" => context[:prj_pfc][:commands],
          "secrets" => context[:prj_pfc][:secrets],
          "agent" => %{
            "machine_type" => context[:prj_pfc][:agent][:machine_type],
            "os_image" => context[:prj_pfc][:agent][:os_image]
          }
        }
      }

      GrpcMock.expect(PFCServiceMock, :describe, fn _request, _stream ->
        Util.Proto.deep_new!(API.DescribeResponse, %{
          status: %{code: :OK},
          pre_flight_checks: %{
            organization_pfc: context[:org_pfc],
            project_pfc: context[:prj_pfc]
          }
        })
      end)

      assert {:ok, ^pfcs} = PFCClient.describe(organization_id, project_id)
      assert :ok = GrpcMock.verify!(PFCServiceMock)
    end

    test "when pipeline has pre-flight checks configured for only the organization" <>
           "then returns non-empty organization pre-flight check " <>
           "and empty project pre-flight check",
         context do
      organization_id = context[:org_id]
      project_id = context[:prj_id]

      pfcs = %{
        "organization_pfc" => %{
          "commands" => context[:org_pfc][:commands],
          "secrets" => context[:org_pfc][:secrets]
        },
        "project_pfc" => nil
      }

      GrpcMock.expect(PFCServiceMock, :describe, fn _request, _stream ->
        Util.Proto.deep_new!(API.DescribeResponse, %{
          status: %{code: :OK},
          pre_flight_checks: %{
            organization_pfc: context[:org_pfc]
          }
        })
      end)

      assert {:ok, ^pfcs} = PFCClient.describe(organization_id, project_id)
      assert :ok = GrpcMock.verify!(PFCServiceMock)
    end

    test "when pipeline has pre-flight checks configured for only the project" <>
           "then returns empty organization pre-flight check " <>
           "and non-empty project pre-flight check",
         context do
      organization_id = context[:org_id]
      project_id = context[:prj_id]

      pfcs = %{
        "organization_pfc" => nil,
        "project_pfc" => %{
          "commands" => context[:prj_pfc][:commands],
          "secrets" => context[:prj_pfc][:secrets],
          "agent" => %{
            "machine_type" => context[:prj_pfc][:agent][:machine_type],
            "os_image" => context[:prj_pfc][:agent][:os_image]
          }
        }
      }

      GrpcMock.expect(PFCServiceMock, :describe, fn _request, _stream ->
        Util.Proto.deep_new!(API.DescribeResponse, %{
          status: %{code: :OK},
          pre_flight_checks: %{
            project_pfc: context[:prj_pfc]
          }
        })
      end)

      assert {:ok, ^pfcs} = PFCClient.describe(organization_id, project_id)
      assert :ok = GrpcMock.verify!(PFCServiceMock)
    end

    test "when pipeline has pre-flight checks configured for only the project without agent config" <>
           "then returns empty organization pre-flight check " <>
           "and non-empty project pre-flight check without agent config",
         context do
      organization_id = context[:org_id]
      project_id = context[:prj_id]

      pfcs = %{
        "organization_pfc" => nil,
        "project_pfc" => %{
          "commands" => context[:prj_pfc][:commands],
          "secrets" => context[:prj_pfc][:secrets],
          "agent" => nil
        }
      }

      GrpcMock.expect(PFCServiceMock, :describe, fn _request, _stream ->
        Util.Proto.deep_new!(API.DescribeResponse, %{
          status: %{code: :OK},
          pre_flight_checks: %{
            project_pfc: Map.delete(context[:prj_pfc], :agent)
          }
        })
      end)

      assert {:ok, ^pfcs} = PFCClient.describe(organization_id, project_id)
      assert :ok = GrpcMock.verify!(PFCServiceMock)
    end

    test "when pipeline has no pre-flight checks configured" <>
           "then returns both empty pre-flight checks",
         context do
      organization_id = context[:org_id]
      project_id = context[:prj_id]

      GrpcMock.expect(PFCServiceMock, :describe, fn _request, _stream ->
        Util.Proto.deep_new!(API.DescribeResponse, %{
          status: %{code: :NOT_FOUND, message: ""}
        })
      end)

      assert {:ok, :undefined} = PFCClient.describe(organization_id, project_id)
      assert :ok = GrpcMock.verify!(PFCServiceMock)
    end

    test "returns {:error, :timeout{} when connection times out",
         context do
      organization_id = context[:org_id]
      project_id = context[:prj_id]

      GrpcMock.expect(PFCServiceMock, :describe, fn _request, _stream ->
        Process.sleep(15_000)

        Util.Proto.deep_new!(API.DescribeResponse, %{
          status: %{code: :NOT_FOUND, message: ""}
        })
      end)

      assert {:error, :timeout} = PFCClient.describe(organization_id, project_id)
      assert :ok = GrpcMock.verify!(PFCServiceMock)
    end

    test "returns {:error, reason} when something crashes",
         context do
      organization_id = context[:org_id]
      project_id = context[:prj_id]

      GrpcMock.expect(PFCServiceMock, :describe, fn _request, _stream ->
        raise "Some error"
      end)

      assert {:error, %GRPC.RPCError{}} = PFCClient.describe(organization_id, project_id)
      assert :ok = GrpcMock.verify!(PFCServiceMock)
    end
  end

  defp setup_grpc_mock(_context) do
    {:ok, %{port: port}} = Test.Support.GrpcServerHelper.start_server_with_cleanup(PFCServiceMock)
    Test.Support.GrpcServerHelper.setup_service_url(@url_env_var, port)
  end

  defp setup_organization_pfc(_context) do
    {:ok,
     org_id: UUID.uuid4(),
     org_pfc: %{
       commands: [
         ~s[./security_script.sh --env ci --foo bar],
         ~s[make check.deps --include-vulnerabilities],
         ~s[./check_secrets.sh -- SECRET_1]
       ],
       secrets: ["ORG_SECRET"]
     }}
  end

  defp setup_project_pfc(_context) do
    {:ok,
     prj_id: UUID.uuid4(),
     prj_pfc: %{
       commands: [
         ~s[./security_script.sh --env ci],
         ~s[make check.deps],
         ~s[./check_secrets.sh -- PRJ_SECRETS]
       ],
       secrets: ["PRJ_SECRET"],
       agent: %{
         machine_type: "e1-standard-2",
         os_image: "ubuntu1804"
       }
     }}
  end
end
