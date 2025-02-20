defmodule PreFlightChecks.GRPC.ServerTest do
  alias InternalApi.PreFlightChecksHub, as: API
  alias API.PreFlightChecksService, as: PFCService

  alias PreFlightChecks.OrganizationPFC.Model.OrganizationPFCQueries
  alias PreFlightChecks.ProjectPFC.Model.ProjectPFCQueries

  use ExUnit.Case, async: false

  @host "localhost"
  @port 50_051

  setup [:checkout, :setup_ids, :setup_org_pfc, :setup_proj_pfc]

  describe "rpc Describe(DescribeRequest) returns (DescribeResponse)" do
    test "when `level = ORGANIZATION` " <>
           "and organization has pre-flight checks " <>
           "then replies with OK response",
         context do
      commands = context[:org_pfc].definition.commands
      secrets = context[:org_pfc].definition.secrets

      assert {:ok,
              %API.DescribeResponse{
                pre_flight_checks: %API.PreFlightChecks{
                  organization_pfc: %API.OrganizationPFC{
                    commands: ^commands,
                    secrets: ^secrets
                  }
                },
                status: %InternalApi.Status{code: :OK}
              }} =
               send(
                 API.DescribeRequest.new(
                   level: :ORGANIZATION,
                   organization_id: context[:organization_id]
                 )
               )
    end

    test "when `level = ORGANIZATION` " <>
           "and has no pre-flight checks " <>
           "then replies with NOT_FOUND response" do
      organization_id = UUID.uuid4()
      message = "Pre-flight check for organization \"#{organization_id}\" was not found"

      assert {:ok,
              %API.DescribeResponse{
                status: %InternalApi.Status{
                  code: :NOT_FOUND,
                  message: ^message
                }
              }} =
               send(
                 API.DescribeRequest.new(
                   level: :ORGANIZATION,
                   organization_id: organization_id
                 )
               )
    end

    test "when level is ORGANIZATION " <>
           "and no organization_id is set " <>
           "then replies with INVALID_ARGUMENT response",
         _context do
      assert {:ok,
              %API.DescribeResponse{
                status: %InternalApi.Status{
                  code: :INVALID_ARGUMENT,
                  message: "organization_id can't be blank"
                }
              }} = send(API.DescribeRequest.new(level: :ORGANIZATION))
    end

    test "when `level = PROJECT` " <>
           "and project has pre-flight checks " <>
           "then returns PROJECT level",
         context do
      commands = context[:proj_pfc].definition.commands
      secrets = context[:proj_pfc].definition.secrets

      machine_type = context[:proj_pfc].definition.agent.machine_type
      os_image = context[:proj_pfc].definition.agent.os_image

      assert {:ok,
              %API.DescribeResponse{
                pre_flight_checks: %API.PreFlightChecks{
                  project_pfc: %API.ProjectPFC{
                    commands: ^commands,
                    secrets: ^secrets,
                    agent: %API.Agent{
                      machine_type: ^machine_type,
                      os_image: ^os_image
                    }
                  }
                },
                status: %InternalApi.Status{code: :OK}
              }} =
               send(
                 API.DescribeRequest.new(
                   level: :PROJECT,
                   project_id: context[:project_id]
                 )
               )
    end

    test "when `level = PROJECT` " <>
           "and has no pre-flight checks " <>
           "then replies with NOT_FOUND response" do
      project_id = UUID.uuid4()
      message = "Pre-flight check for project \"#{project_id}\" was not found"

      assert {:ok,
              %API.DescribeResponse{
                status: %InternalApi.Status{
                  code: :NOT_FOUND,
                  message: ^message
                }
              }} =
               send(
                 API.DescribeRequest.new(
                   level: :PROJECT,
                   project_id: project_id
                 )
               )
    end

    test "when level is PROJECT " <>
           "and project_id is not set " <>
           "then replies with INVALID_ARGUMENT response",
         _context do
      assert {:ok,
              %API.DescribeResponse{
                status: %InternalApi.Status{
                  code: :INVALID_ARGUMENT,
                  message: "project_id can't be blank"
                }
              }} = send(API.DescribeRequest.new(level: :PROJECT))
    end

    test "when `level = EVERYTHING` " <>
           "and data is valid " <>
           "then replies with OK response",
         context do
      org_commands = context[:org_pfc].definition.commands
      org_secrets = context[:org_pfc].definition.secrets

      proj_commands = context[:proj_pfc].definition.commands
      proj_secrets = context[:proj_pfc].definition.secrets

      assert {:ok,
              %API.DescribeResponse{
                pre_flight_checks: %API.PreFlightChecks{
                  organization_pfc: %API.OrganizationPFC{
                    commands: ^org_commands,
                    secrets: ^org_secrets
                  },
                  project_pfc: %API.ProjectPFC{
                    commands: ^proj_commands,
                    secrets: ^proj_secrets
                  }
                },
                status: %InternalApi.Status{code: :OK}
              }} =
               send(
                 API.DescribeRequest.new(
                   level: :EVERYTHING,
                   organization_id: context[:organization_id],
                   project_id: context[:project_id]
                 )
               )
    end

    test "when `level = EVERYTHING` " <>
           "and organization_id is missing " <>
           "then replies with INVALID_ARGUMENT response",
         context do
      assert {:ok,
              %API.DescribeResponse{
                status: %InternalApi.Status{
                  code: :INVALID_ARGUMENT,
                  message: "organization_id can't be blank"
                }
              }} =
               send(
                 API.DescribeRequest.new(
                   level: :EVERYTHING,
                   project_id: context[:project_id]
                 )
               )
    end

    test "when `level = EVERYTHING` " <>
           "and project_id is missing " <>
           "then replies with INVALID_ARGUMENT response",
         context do
      assert {:ok,
              %API.DescribeResponse{
                status: %InternalApi.Status{
                  code: :INVALID_ARGUMENT,
                  message: "project_id can't be blank"
                }
              }} =
               send(
                 API.DescribeRequest.new(
                   level: :EVERYTHING,
                   organization_id: context[:organization_id]
                 )
               )
    end
  end

  describe "rpc Apply(ApplyRequest) returns (ApplyResponse)" do
    test "when level is ORGANIZATION " <>
           "and data is proper " <>
           "then returns OK response",
         context do
      commands = context[:proj_pfc].definition.commands
      secrets = context[:proj_pfc].definition.secrets

      assert {:ok,
              %API.ApplyResponse{
                status: %InternalApi.Status{code: :OK},
                pre_flight_checks: %API.PreFlightChecks{
                  organization_pfc: %API.OrganizationPFC{
                    commands: ^commands,
                    secrets: ^secrets
                  }
                }
              }} =
               send(
                 Util.Proto.deep_new!(API.ApplyRequest,
                   level: :ORGANIZATION,
                   organization_id: context[:organization_id],
                   requester_id: context[:requester_id],
                   pre_flight_checks: %{
                     organization_pfc: %{
                       commands: commands,
                       secrets: secrets
                     }
                   }
                 )
               )
    end

    test "when level is ORGANIZATION " <>
           "and organization_id is missing " <>
           "then replies with INVALID_ARGUMENT response",
         context do
      commands = context[:proj_pfc].definition.commands
      secrets = context[:proj_pfc].definition.secrets
      agent_machine_type = "a1-standard-4"
      agent_os_image = "macos-xcode11"

      assert {:ok,
              %API.ApplyResponse{
                status: %InternalApi.Status{
                  code: :INVALID_ARGUMENT,
                  message: "organization_id can't be blank"
                }
              }} =
               send(
                 Util.Proto.deep_new!(API.ApplyRequest,
                   level: :ORGANIZATION,
                   pre_flight_checks: %{
                     organization_pfc: %{
                       commands: commands,
                       secrets: secrets,
                       agent: %{
                         machine_type: agent_machine_type,
                         os_image: agent_os_image
                       }
                     }
                   }
                 )
               )
    end

    test "when level is ORGANIZATION " <>
           "and requester_id is missing " <>
           "then replies with INVALID_ARGUMENT response",
         context do
      commands = context[:proj_pfc].definition.commands
      secrets = context[:proj_pfc].definition.secrets
      agent_machine_type = "a1-standard-4"
      agent_os_image = "macos-xcode11"

      assert {:ok,
              %API.ApplyResponse{
                status: %InternalApi.Status{
                  code: :INVALID_ARGUMENT,
                  message: "requester_id can't be blank"
                }
              }} =
               send(
                 Util.Proto.deep_new!(API.ApplyRequest,
                   level: :ORGANIZATION,
                   organization_id: context[:organization_id],
                   pre_flight_checks: %{
                     organization_pfc: %{
                       commands: commands,
                       secrets: secrets,
                       agent: %{
                         machine_type: agent_machine_type,
                         os_image: agent_os_image
                       }
                     }
                   }
                 )
               )
    end

    test "when level is ORGANIZATION " <>
           "and commands are missing " <>
           "then replies with INVALID_ARGUMENT response",
         context do
      secrets = context[:proj_pfc].definition.secrets
      agent_machine_type = "a1-standard-4"
      agent_os_image = "macos-xcode11"

      assert {:ok,
              %API.ApplyResponse{
                status: %InternalApi.Status{
                  code: :INVALID_ARGUMENT,
                  message: "commands should have at least 1 item(s)"
                }
              }} =
               send(
                 Util.Proto.deep_new!(API.ApplyRequest,
                   level: :ORGANIZATION,
                   organization_id: context[:organization_id],
                   requester_id: context[:requester_id],
                   pre_flight_checks: %{
                     organization_pfc: %{
                       secrets: secrets,
                       agent: %{
                         machine_type: agent_machine_type,
                         os_image: agent_os_image
                       }
                     }
                   }
                 )
               )
    end

    test "when level is PROJECT " <>
           "and data is proper " <>
           "then replies with OK response",
         context do
      commands = context[:org_pfc].definition.commands
      secrets = context[:org_pfc].definition.secrets

      assert {:ok,
              %API.ApplyResponse{
                pre_flight_checks: %API.PreFlightChecks{
                  project_pfc: %API.ProjectPFC{
                    commands: ^commands,
                    secrets: ^secrets,
                    agent: nil
                  }
                },
                status: %InternalApi.Status{code: :OK}
              }} =
               send(
                 Util.Proto.deep_new!(API.ApplyRequest,
                   level: :PROJECT,
                   organization_id: context[:organization_id],
                   project_id: context[:project_id],
                   requester_id: context[:requester_id],
                   pre_flight_checks: %{
                     project_pfc: %{
                       commands: commands,
                       secrets: secrets
                     }
                   }
                 )
               )
    end

    test "when level is PROJECT " <>
           "and organization_id is missing " <>
           "then replies with INVALID_ARGUMENT response",
         context do
      commands = context[:proj_pfc].definition.commands
      secrets = context[:proj_pfc].definition.secrets

      assert {:ok,
              %API.ApplyResponse{
                status: %InternalApi.Status{
                  code: :INVALID_ARGUMENT,
                  message: "organization_id can't be blank"
                }
              }} =
               send(
                 Util.Proto.deep_new!(API.ApplyRequest,
                   level: :PROJECT,
                   project_id: context[:project_id],
                   requester_id: context[:requester_id],
                   pre_flight_checks: %{
                     project_pfc: %{
                       commands: commands,
                       secrets: secrets
                     }
                   }
                 )
               )
    end

    test "when level is PROJECT " <>
           "and project_id is missing " <>
           "then replies with INVALID_ARGUMENT response",
         context do
      commands = context[:proj_pfc].definition.commands
      secrets = context[:proj_pfc].definition.secrets

      assert {:ok,
              %API.ApplyResponse{
                status: %InternalApi.Status{
                  code: :INVALID_ARGUMENT,
                  message: "project_id can't be blank"
                }
              }} =
               send(
                 Util.Proto.deep_new!(API.ApplyRequest,
                   level: :PROJECT,
                   organization_id: context[:organization_id],
                   requester_id: context[:requester_id],
                   pre_flight_checks: %{
                     project_pfc: %{
                       commands: commands,
                       secrets: secrets
                     }
                   }
                 )
               )
    end

    test "when level is PROJECT " <>
           "and requester_id is missing " <>
           "then replies with INVALID_ARGUMENT response",
         context do
      commands = context[:proj_pfc].definition.commands
      secrets = context[:proj_pfc].definition.secrets

      assert {:ok,
              %API.ApplyResponse{
                status: %InternalApi.Status{
                  code: :INVALID_ARGUMENT,
                  message: "requester_id can't be blank"
                }
              }} =
               send(
                 Util.Proto.deep_new!(API.ApplyRequest,
                   level: :PROJECT,
                   organization_id: context[:organization_id],
                   project_id: context[:project_id],
                   pre_flight_checks: %{
                     project_pfc: %{
                       commands: commands,
                       secrets: secrets
                     }
                   }
                 )
               )
    end

    test "when level is PROJECT " <>
           "and commands are missing " <>
           "then replies with INVALID_ARGUMENT response",
         context do
      secrets = context[:proj_pfc].definition.secrets

      assert {:ok,
              %API.ApplyResponse{
                status: %InternalApi.Status{
                  code: :INVALID_ARGUMENT,
                  message: "commands should have at least 1 item(s)"
                }
              }} =
               send(
                 Util.Proto.deep_new!(API.ApplyRequest,
                   level: :PROJECT,
                   organization_id: context[:organization_id],
                   project_id: context[:project_id],
                   requester_id: context[:requester_id],
                   pre_flight_checks: %{
                     organization_pfc: %{
                       secrets: secrets
                     }
                   }
                 )
               )
    end

    test "when level is PROJECT " <>
           "and agent's machine type is missing " <>
           "then replies with INVALID_ARGUMENT response",
         context do
      commands = context[:proj_pfc].definition.commands

      assert {:ok,
              %API.ApplyResponse{
                status: %InternalApi.Status{
                  code: :INVALID_ARGUMENT,
                  message: "machine_type can't be blank"
                }
              }} =
               send(
                 Util.Proto.deep_new!(API.ApplyRequest,
                   level: :PROJECT,
                   organization_id: context[:organization_id],
                   project_id: context[:project_id],
                   requester_id: context[:requester_id],
                   pre_flight_checks: %{
                     project_pfc: %{
                       commands: commands,
                       agent: %{
                         os_image: "macos-xcode11"
                       }
                     }
                   }
                 )
               )
    end

    test "when level is PROJECT " <>
           "and agent specification is present " <>
           "then replies with OK response",
         context do
      commands = context[:proj_pfc].definition.commands
      secrets = context[:proj_pfc].definition.secrets
      machine_type = context[:proj_pfc].definition.agent.machine_type
      os_image = context[:proj_pfc].definition.agent.os_image

      assert {:ok,
              %API.ApplyResponse{
                pre_flight_checks: %API.PreFlightChecks{
                  project_pfc: %API.ProjectPFC{
                    commands: ^commands,
                    secrets: ^secrets,
                    agent: %API.Agent{
                      machine_type: ^machine_type,
                      os_image: ^os_image
                    }
                  }
                },
                status: %InternalApi.Status{code: :OK}
              }} =
               send(
                 Util.Proto.deep_new!(API.ApplyRequest,
                   level: :PROJECT,
                   organization_id: context[:organization_id],
                   project_id: context[:project_id],
                   requester_id: context[:requester_id],
                   pre_flight_checks: %{
                     project_pfc: %{
                       commands: commands,
                       secrets: secrets,
                       agent: %{
                         machine_type: machine_type,
                         os_image: os_image
                       }
                     }
                   }
                 )
               )
    end

    test "when level is EVERYTHING " <>
           "then replies with INVALID_ARGUMENT response" do
      assert {:ok,
              %API.ApplyResponse{
                status: %InternalApi.Status{
                  code: :INVALID_ARGUMENT,
                  message: "level EVERYTHING is not supported"
                }
              }} = send(Util.Proto.deep_new!(API.ApplyRequest, level: :EVERYTHING))
    end
  end

  describe "rpc Destroy(DestroyRequest) returns (DestroyResponse)" do
    test "when level is ORGANIZATION " <>
           "and pre-flight check is configured " <>
           "then returns OK response",
         context do
      assert {:ok,
              %API.DestroyResponse{
                status: %InternalApi.Status{code: :OK}
              }} =
               send(
                 API.DestroyRequest.new(
                   level: :ORGANIZATION,
                   organization_id: context[:organization_id],
                   requester_id: context[:requester_id]
                 )
               )

      assert request_traced?(context[:requester_id], :SUCCESS)
    end

    test "when level is ORGANIZATION " <>
           "and pre-flight check is not configured " <>
           "then returns OK response",
         context do
      assert {:ok,
              %API.DestroyResponse{
                status: %InternalApi.Status{code: :OK}
              }} =
               send(
                 API.DestroyRequest.new(
                   level: :ORGANIZATION,
                   organization_id: UUID.uuid4(),
                   requester_id: context[:requester_id]
                 )
               )

      assert request_traced?(context[:requester_id], :SUCCESS)
    end

    test "when level is ORGANIZATION " <>
           "and no organization_id is set " <>
           "then replies with INVALID_ARGUMENT response",
         context do
      assert {:ok,
              %API.DestroyResponse{
                status: %InternalApi.Status{
                  code: :INVALID_ARGUMENT,
                  message: "organization_id can't be blank"
                }
              }} =
               send(
                 API.DestroyRequest.new(
                   level: :ORGANIZATION,
                   requester_id: context[:requester_id]
                 )
               )
    end

    test "when level is ORGANIZATION " <>
           "and no requester_id is set " <>
           "then replies with INVALID_ARGUMENT response",
         context do
      assert {:ok,
              %API.DestroyResponse{
                status: %InternalApi.Status{
                  code: :INVALID_ARGUMENT,
                  message: "requester_id can't be blank"
                }
              }} =
               send(
                 API.DestroyRequest.new(
                   level: :ORGANIZATION,
                   organization_id: context[:organization_id]
                 )
               )
    end

    test "when level is PROJECT " <>
           "and pre-flight check is configured " <>
           "then replies with OK response",
         context do
      assert {:ok,
              %API.DestroyResponse{
                status: %InternalApi.Status{code: :OK}
              }} =
               send(
                 API.DestroyRequest.new(
                   level: :PROJECT,
                   project_id: context[:project_id],
                   requester_id: context[:requester_id]
                 )
               )

      assert request_traced?(context[:requester_id], :SUCCESS)
    end

    test "when level is PROJECT " <>
           "and pre-flight check is not configured " <>
           "then replies with OK response",
         context do
      assert {:ok,
              %API.DestroyResponse{
                status: %InternalApi.Status{code: :OK}
              }} =
               send(
                 API.DestroyRequest.new(
                   level: :PROJECT,
                   project_id: UUID.uuid4(),
                   requester_id: context[:requester_id]
                 )
               )

      assert request_traced?(context[:requester_id], :SUCCESS)
    end

    test "when level is PROJECT " <>
           "and project_id is not set " <>
           "then replies with INVALID_ARGUMENT response",
         context do
      assert {:ok,
              %API.DestroyResponse{
                status: %InternalApi.Status{
                  code: :INVALID_ARGUMENT,
                  message: "project_id can't be blank"
                }
              }} =
               send(
                 API.DestroyRequest.new(
                   level: :PROJECT,
                   requester_id: context[:requester_id]
                 )
               )
    end

    test "when level is PROJECT " <>
           "and no requester_id is set " <>
           "then replies with INVALID_ARGUMENT response",
         context do
      assert {:ok,
              %API.DestroyResponse{
                status: %InternalApi.Status{
                  code: :INVALID_ARGUMENT,
                  message: "requester_id can't be blank"
                }
              }} =
               send(
                 API.DestroyRequest.new(
                   level: :PROJECT,
                   project_id: context[:project_id]
                 )
               )
    end

    test "when level is EVERYTHING " <>
           "then replies with INVALID_ARGUMENT response" do
      assert {:ok,
              %API.DestroyResponse{
                status: %InternalApi.Status{
                  code: :INVALID_ARGUMENT,
                  message: "level EVERYTHING is not supported"
                }
              }} = send(API.DestroyRequest.new(level: :EVERYTHING))
    end
  end

  defp request_traced?(requester_id, status) do
    require Ecto.Query

    PreFlightChecks.EctoRepo.exists?(
      Ecto.Query.where(
        PreFlightChecks.DestroyTraces.DestroyTrace,
        requester_id: ^requester_id,
        status: ^status
      )
    )
  end

  #
  # gRPC send helper function
  #

  defp send(%API.DescribeRequest{} = request), do: do_send(request, :describe)
  defp send(%API.ApplyRequest{} = request), do: do_send(request, :apply)
  defp send(%API.DestroyRequest{} = request), do: do_send(request, :destroy)

  defp do_send(request, fun) do
    with {:ok, channel} <- GRPC.Stub.connect("#{@host}:#{@port}") do
      apply(PFCService.Stub, fun, [channel, request])
    end
  end

  #
  # Setup functions
  #

  defp checkout(_context) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(PreFlightChecks.EctoRepo, shared: true)
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  end

  defp setup_ids(_context) do
    {:ok,
     [
       organization_id: UUID.uuid4(),
       project_id: UUID.uuid4(),
       requester_id: UUID.uuid4()
     ]}
  end

  defp setup_org_pfc(context) do
    params = %{
      organization_id: context[:organization_id],
      requester_id: context[:requester_id],
      definition: %{
        commands: ["git checkout master", "make install"],
        secrets: ["SESSION_SECRET"]
      }
    }

    {:ok, organization_pfc} = OrganizationPFCQueries.upsert(params)
    {:ok, [org_pfc: organization_pfc, org_pfc_params: params]}
  end

  defp setup_proj_pfc(context) do
    params = %{
      organization_id: context[:organization_id],
      project_id: context[:project_id],
      requester_id: context[:requester_id],
      definition: %{
        commands: ["git reset --hard HEAD", "mix release"],
        secrets: ["DATABASE_PASSWORD"],
        agent: %{
          machine_type: "e2-standard-2",
          os_image: "ubuntu2204"
        }
      }
    }

    {:ok, project_pfc} = ProjectPFCQueries.upsert(params)
    {:ok, [proj_pfc: project_pfc, proj_pfc_params: params]}
  end
end
