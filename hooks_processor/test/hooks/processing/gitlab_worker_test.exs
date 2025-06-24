# credo:disable-for-this-file Credo.Check.Design.DuplicatedCode
defmodule HooksProcessor.Hooks.Processing.GitlabWorkerTest do
  use ExUnit.Case

  alias Support.GitlabHooks
  alias InternalApi.PlumberWF.ScheduleResponse
  alias HooksProcessor.Hooks.Model.HooksQueries
  alias HooksProcessor.Hooks.Processing.WorkersSupervisor
  alias InternalApi.Branch.{FindOrCreateResponse, DescribeResponse, ArchiveResponse}
  alias InternalApi.Projecthub
  alias InternalApi.Plumber.TerminateAllResponse

  @grpc_port 50_047

  setup_all do
    mocks = [AdminServiceMock, ProjectHubServiceMock, BranchServiceMock, WorkflowServiceMock]
    GRPC.Server.start(mocks, @grpc_port)

    Application.put_env(:hooks_processor, :projecthub_grpc_url, "localhost:#{inspect(@grpc_port)}")
    Application.put_env(:hooks_processor, :branch_api_grpc_url, "localhost:#{inspect(@grpc_port)}")
    Application.put_env(:hooks_processor, :plumber_grpc_url, "localhost:#{inspect(@grpc_port)}")

    provider = Application.get_env(:hooks_processor, :webhook_provider)
    Application.put_env(:hooks_processor, :webhook_provider, "gitlab")

    on_exit(fn ->
      GRPC.Server.stop(mocks)

      Application.put_env(:hooks_processor, :webhook_provider, provider)
      Test.Helpers.wait_until_stopped(mocks)
    end)

    {:ok, %{}}
  end

  setup do
    start_supervised!(WorkersSupervisor)

    Test.Helpers.truncate_db()

    :ok
  end

  test "valid new_branch-push hook => branch is created and workflow is scheduled" do
    params = %{
      received_at: DateTime.utc_now(),
      webhook: GitlabHooks.push_new_branch_with_commits(),
      repository_id: UUID.uuid4(),
      project_id: UUID.uuid4(),
      organization_id: UUID.uuid4(),
      provider: "gitlab"
    }

    assert {:ok, webhook} = HooksQueries.insert(params)

    # setup mocks

    ProjectHubServiceMock
    |> GrpcMock.expect(:describe, fn req, _ ->
      assert req.id == webhook.project_id

      %Projecthub.DescribeResponse{
        project: %{
          metadata: %{
            id: req.id,
            org_id: UUID.uuid4()
          },
          spec: %{
            repository: %{
              pipeline_file: ".semaphore/semaphore.yml",
              run_on: [:BRANCHES, :TAGS],
              whitelist: %{tags: ["/v1.*/", "/release-.*/"]}
            }
          }
        },
        metadata: %{status: %{code: :OK}}
      }
    end)

    BranchServiceMock
    |> GrpcMock.expect(:find_or_create, fn req, _ ->
      assert req.project_id == webhook.project_id
      assert req.repository_id == webhook.repository_id
      assert req.name == "master"
      assert req.display_name == "master"
      assert req.ref_type == :BRANCH

      %FindOrCreateResponse{branch: %{id: webhook.id, name: "master"}, status: %{code: :OK}}
    end)

    WorkflowServiceMock
    |> GrpcMock.expect(:schedule, fn req, _ ->
      branch_name = "master"
      commit_sha = "da1560886d4f094c3e6c9ef40349f7d38b5d27d7"
      assert_wf_schedule_valid(req, webhook, branch_name, commit_sha)

      %ScheduleResponse{wf_id: webhook.id, ppl_id: webhook.project_id, status: %{code: :OK}}
    end)

    # wait for worker to finish and check results

    assert {:ok, pid} = WorkersSupervisor.start_worker_for_webhook(webhook.id)

    Test.Helpers.wait_for_worker_to_finish(pid, 15_000)

    assert {:ok, webhook} = HooksQueries.get_by_id(webhook.id)
    assert webhook.state == "launching"
    assert webhook.result == "OK"
    assert webhook.wf_id == webhook.id
    assert webhook.ppl_id == webhook.project_id
    assert webhook.branch_id == webhook.id
    assert webhook.commit_sha == "da1560886d4f094c3e6c9ef40349f7d38b5d27d7"
    assert webhook.commit_author == "GitLab dev user"
    assert webhook.git_ref == "refs/heads/master"

    GrpcMock.verify!(ProjectHubServiceMock)
    GrpcMock.verify!(BranchServiceMock)
    GrpcMock.verify!(WorkflowServiceMock)
  end

  defp assert_wf_schedule_valid(req, webhook, branch_name, commit_sha) do
    assert req.requester_id == ""
    assert req.organization_id == webhook.organization_id
    assert req.project_id == webhook.project_id
    assert req.branch_id == webhook.id
    assert req.hook_id == webhook.id
    assert req.request_token == webhook.id
    assert req.triggered_by == :HOOK
    assert req.service == :GITLAB
    assert req.definition_file == ".semaphore/semaphore.yml"
    assert req.label == label(branch_name)
    assert req.repo.owner != ""
    assert req.repo.repo_name != ""
    assert req.repo.branch_name == branch_name
    assert req.repo.commit_sha == commit_sha
    assert req.repo.repository_id == webhook.repository_id
  end

  defp label("refs/tags/" <> rest), do: rest
  defp label("pull-request-" <> rest), do: rest
  defp label(branch_name), do: branch_name

  test "valid branch-push hook => workflow is scheduled" do
    params = %{
      received_at: DateTime.utc_now(),
      webhook: GitlabHooks.push_commit(),
      repository_id: UUID.uuid4(),
      project_id: UUID.uuid4(),
      organization_id: UUID.uuid4(),
      provider: "gitlab"
    }

    assert {:ok, webhook} = HooksQueries.insert(params)

    # setup mocks

    ProjectHubServiceMock
    |> GrpcMock.expect(:describe, fn req, _ ->
      assert req.id == webhook.project_id

      %Projecthub.DescribeResponse{
        project: %{
          metadata: %{
            id: req.id,
            org_id: UUID.uuid4()
          },
          spec: %{
            repository: %{
              pipeline_file: ".semaphore/semaphore.yml",
              run_on: [:BRANCHES, :TAGS],
              whitelist: %{tags: ["/v1.*/", "/release-.*/"]}
            }
          }
        },
        metadata: %{status: %{code: :OK}}
      }
    end)

    BranchServiceMock
    |> GrpcMock.expect(:find_or_create, fn req, _ ->
      assert req.project_id == webhook.project_id
      assert req.repository_id == webhook.repository_id
      assert req.name == "master"
      assert req.display_name == "master"
      assert req.ref_type == :BRANCH

      %FindOrCreateResponse{branch: %{id: webhook.id, name: "master"}, status: %{code: :OK}}
    end)

    WorkflowServiceMock
    |> GrpcMock.expect(:schedule, fn req, _ ->
      branch_name = "master"
      commit_sha = "da1560886d4f094c3e6c9ef40349f7d38b5d27d7"
      assert_wf_schedule_valid(req, webhook, branch_name, commit_sha)

      %ScheduleResponse{wf_id: webhook.id, ppl_id: webhook.project_id, status: %{code: :OK}}
    end)

    # wait for worker to finish and check results

    assert {:ok, pid} = WorkersSupervisor.start_worker_for_webhook(webhook.id)

    Test.Helpers.wait_for_worker_to_finish(pid, 15_000)

    assert {:ok, webhook} = HooksQueries.get_by_id(webhook.id)
    assert webhook.state == "launching"
    assert webhook.result == "OK"
    assert webhook.wf_id == webhook.id
    assert webhook.ppl_id == webhook.project_id
    assert webhook.branch_id == webhook.id
    assert webhook.commit_sha == "da1560886d4f094c3e6c9ef40349f7d38b5d27d7"
    assert webhook.commit_author == "GitLab dev user"
    assert webhook.git_ref == "refs/heads/master"

    GrpcMock.verify!(ProjectHubServiceMock)
    GrpcMock.verify!(BranchServiceMock)
    GrpcMock.verify!(WorkflowServiceMock)
  end

  test "valid branch-deleted hook => branch is archived" do
    params = %{
      received_at: DateTime.utc_now(),
      webhook: GitlabHooks.push_delete_branch(),
      repository_id: UUID.uuid4(),
      project_id: UUID.uuid4(),
      organization_id: UUID.uuid4(),
      provider: "gitlab"
    }

    assert {:ok, webhook} = HooksQueries.insert(params)

    # setup mocks

    ProjectHubServiceMock
    |> GrpcMock.expect(:describe, fn req, _ ->
      assert req.id == webhook.project_id

      %Projecthub.DescribeResponse{
        project: %{
          metadata: %{
            id: req.id,
            org_id: UUID.uuid4()
          },
          spec: %{
            repository: %{
              pipeline_file: ".semaphore/semaphore.yml",
              run_on: [:BRANCHES, :TAGS],
              whitelist: %{tags: ["/v1.*/", "/release-.*/"]}
            }
          }
        },
        metadata: %{status: %{code: :OK}}
      }
    end)

    AdminServiceMock
    |> GrpcMock.expect(:terminate_all, fn req, _ ->
      assert req.project_id == webhook.project_id
      assert req.branch_name == "master"
      assert req.reason == :BRANCH_DELETION

      %TerminateAllResponse{response_status: %{code: :OK}}
    end)

    BranchServiceMock
    |> GrpcMock.expect(:describe, fn req, _ ->
      assert req.project_id == webhook.project_id
      assert req.branch_name == "master"

      %DescribeResponse{branch: %{id: webhook.id, name: "master"}, status: %{code: :OK}}
    end)
    |> GrpcMock.expect(:archive, fn req, _ ->
      assert req.branch_id == webhook.id

      %ArchiveResponse{status: %{code: :OK, message: "Success"}}
    end)

    # wait for worker to finish and check results

    assert {:ok, pid} = WorkersSupervisor.start_worker_for_webhook(webhook.id)

    Test.Helpers.wait_for_worker_to_finish(pid, 15_000)

    assert {:ok, webhook} = HooksQueries.get_by_id(webhook.id)
    assert webhook.state == "deleting_branch"
    assert webhook.result == "OK"
    assert webhook.wf_id == nil
    assert webhook.ppl_id == nil
    assert webhook.branch_id == webhook.id
    assert webhook.commit_sha == "b6568db1bc1dcd7f8b4d5a946b0b91f9dacd7327"
    assert webhook.commit_author == "Jordi Mallach"
    assert webhook.git_ref == "refs/heads/master"

    GrpcMock.verify!(ProjectHubServiceMock)
    GrpcMock.verify!(BranchServiceMock)
  end

  test "valid tag-push hook => tag is created and workflow is scheduled" do
    params = %{
      received_at: DateTime.utc_now(),
      webhook: GitlabHooks.tag_push(),
      repository_id: UUID.uuid4(),
      project_id: UUID.uuid4(),
      organization_id: UUID.uuid4(),
      provider: "gitlab"
    }

    assert {:ok, webhook} = HooksQueries.insert(params)

    # setup mocks

    ProjectHubServiceMock
    |> GrpcMock.expect(:describe, fn req, _ ->
      assert req.id == webhook.project_id

      %Projecthub.DescribeResponse{
        project: %{
          metadata: %{
            id: req.id,
            org_id: UUID.uuid4()
          },
          spec: %{
            repository: %{
              pipeline_file: ".semaphore/semaphore.yml",
              run_on: [:BRANCHES, :TAGS],
              whitelist: %{tags: ["/v1.*/", "/release-.*/"]}
            }
          }
        },
        metadata: %{status: %{code: :OK}}
      }
    end)

    BranchServiceMock
    |> GrpcMock.expect(:find_or_create, fn req, _ ->
      assert req.project_id == webhook.project_id
      assert req.repository_id == webhook.repository_id
      assert req.name == "refs/tags/v1.0.0"
      assert req.display_name == "v1.0.0"
      assert req.ref_type == :TAG

      %FindOrCreateResponse{branch: %{id: webhook.id, name: "refs/tags/v1.0.0"}, status: %{code: :OK}}
    end)

    WorkflowServiceMock
    |> GrpcMock.expect(:schedule, fn req, _ ->
      branch_name = "refs/tags/v1.0.0"
      commit_sha = "82b3d5ae55f7080f1e6022629cdb57bfae7cccc7"
      assert_wf_schedule_valid(req, webhook, branch_name, commit_sha)

      %ScheduleResponse{wf_id: webhook.id, ppl_id: webhook.project_id, status: %{code: :OK}}
    end)

    # wait for worker to finish and check results

    assert {:ok, pid} = WorkersSupervisor.start_worker_for_webhook(webhook.id)

    Test.Helpers.wait_for_worker_to_finish(pid, 15_000)

    assert {:ok, webhook} = HooksQueries.get_by_id(webhook.id)
    assert webhook.state == "launching"
    assert webhook.result == "OK"
    assert webhook.wf_id == webhook.id
    assert webhook.ppl_id == webhook.project_id
    assert webhook.branch_id == webhook.id
    assert webhook.commit_sha == "82b3d5ae55f7080f1e6022629cdb57bfae7cccc7"
    assert webhook.commit_author == "GitLab dev user"
    assert webhook.git_ref == "refs/tags/v1.0.0"

    GrpcMock.verify!(ProjectHubServiceMock)
    GrpcMock.verify!(BranchServiceMock)
    GrpcMock.verify!(WorkflowServiceMock)
  end

  test "[skip ci] flag in branch-push hook => hook in skip_ci state" do
    params = %{
      received_at: DateTime.utc_now(),
      webhook: GitlabHooks.push_skip_ci(),
      repository_id: UUID.uuid4(),
      project_id: UUID.uuid4(),
      organization_id: UUID.uuid4(),
      provider: "gitlab"
    }

    assert {:ok, webhook} = HooksQueries.insert(params)

    # setup mocks

    ProjectHubServiceMock
    |> GrpcMock.expect(:describe, fn req, _ ->
      assert req.id == webhook.project_id

      %Projecthub.DescribeResponse{
        project: %{
          metadata: %{
            id: req.id,
            org_id: UUID.uuid4()
          },
          spec: %{
            repository: %{
              pipeline_file: ".semaphore/semaphore.yml",
              run_on: [:BRANCHES, :TAGS],
              whitelist: %{tags: ["/v1.*/", "/release-.*/"]}
            }
          }
        },
        metadata: %{status: %{code: :OK}}
      }
    end)

    # wait for worker to finish and check results

    assert {:ok, pid} = WorkersSupervisor.start_worker_for_webhook(webhook.id)

    Test.Helpers.wait_for_worker_to_finish(pid, 15_000)

    assert {:ok, webhook} = HooksQueries.get_by_id(webhook.id)
    assert webhook.state == "skip_ci"
    assert webhook.result == "OK"
    assert webhook.wf_id == nil
    assert webhook.ppl_id == nil
    assert webhook.branch_id == nil
    assert webhook.commit_sha == "da1560886d4f094c3e6c9ef40349f7d38b5d27d7"
    assert webhook.commit_author == "GitLab dev user"
    assert webhook.git_ref == "refs/heads/master"

    GrpcMock.verify!(ProjectHubServiceMock)
  end

  test "[skip ci] flag in tag-push hook => hook in skip_ci state" do
    params = %{
      received_at: DateTime.utc_now(),
      webhook: GitlabHooks.tag_push_skip_ci(),
      repository_id: UUID.uuid4(),
      project_id: UUID.uuid4(),
      organization_id: UUID.uuid4(),
      provider: "gitlab"
    }

    assert {:ok, webhook} = HooksQueries.insert(params)

    # setup mocks

    ProjectHubServiceMock
    |> GrpcMock.expect(:describe, fn req, _ ->
      assert req.id == webhook.project_id

      %Projecthub.DescribeResponse{
        project: %{
          metadata: %{
            id: req.id,
            org_id: UUID.uuid4()
          },
          spec: %{
            repository: %{
              pipeline_file: ".semaphore/semaphore.yml",
              run_on: [:BRANCHES, :TAGS],
              whitelist: %{tags: ["/v1.*/", "/release-.*/"]}
            }
          }
        },
        metadata: %{status: %{code: :OK}}
      }
    end)

    # wait for worker to finish and check results

    assert {:ok, pid} = WorkersSupervisor.start_worker_for_webhook(webhook.id)

    Test.Helpers.wait_for_worker_to_finish(pid, 15_000)

    assert {:ok, webhook} = HooksQueries.get_by_id(webhook.id)
    assert webhook.state == "skip_ci"
    assert webhook.result == "OK"
    assert webhook.wf_id == nil
    assert webhook.ppl_id == nil
    assert webhook.branch_id == nil
    assert webhook.commit_sha == "82b3d5ae55f7080f1e6022629cdb57bfae7cccc7"
    assert webhook.commit_author == "GitLab dev user"
    assert webhook.git_ref == "refs/tags/v1.0.0"

    GrpcMock.verify!(ProjectHubServiceMock)
  end

  test "branch-push hook but project doesn't run on branches => hook in skip_branch state" do
    params = %{
      received_at: DateTime.utc_now(),
      webhook: GitlabHooks.push_commit(),
      repository_id: UUID.uuid4(),
      project_id: UUID.uuid4(),
      organization_id: UUID.uuid4(),
      provider: "gitlab"
    }

    assert {:ok, webhook} = HooksQueries.insert(params)

    # setup mocks

    ProjectHubServiceMock
    |> GrpcMock.expect(:describe, fn req, _ ->
      assert req.id == webhook.project_id

      %Projecthub.DescribeResponse{
        project: %{
          metadata: %{
            id: req.id,
            org_id: UUID.uuid4()
          },
          spec: %{
            repository: %{
              pipeline_file: ".semaphore/semaphore.yml",
              run_on: [:TAGS],
              whitelist: %{tags: ["/v1.*/", "/release-.*/"]}
            }
          }
        },
        metadata: %{status: %{code: :OK}}
      }
    end)

    # wait for worker to finish and check results

    assert {:ok, pid} = WorkersSupervisor.start_worker_for_webhook(webhook.id)

    Test.Helpers.wait_for_worker_to_finish(pid, 15_000)

    assert {:ok, webhook} = HooksQueries.get_by_id(webhook.id)
    assert webhook.state == "skip_branch"
    assert webhook.result == "OK"
    assert webhook.wf_id == nil
    assert webhook.ppl_id == nil
    assert webhook.branch_id == nil
    assert webhook.commit_sha == "da1560886d4f094c3e6c9ef40349f7d38b5d27d7"
    assert webhook.commit_author == "GitLab dev user"
    assert webhook.git_ref == "refs/heads/master"

    GrpcMock.verify!(ProjectHubServiceMock)
  end

  test "tag-push hook but project doesn't run on tags => hook in skip_tag state" do
    params = %{
      received_at: DateTime.utc_now(),
      webhook: GitlabHooks.tag_push(),
      repository_id: UUID.uuid4(),
      project_id: UUID.uuid4(),
      organization_id: UUID.uuid4(),
      provider: "gitlab"
    }

    assert {:ok, webhook} = HooksQueries.insert(params)

    # setup mocks

    ProjectHubServiceMock
    |> GrpcMock.expect(:describe, fn req, _ ->
      assert req.id == webhook.project_id

      %Projecthub.DescribeResponse{
        project: %{
          metadata: %{
            id: req.id,
            org_id: UUID.uuid4()
          },
          spec: %{
            repository: %{
              pipeline_file: ".semaphore/semaphore.yml",
              run_on: [:BRANCHES],
              whitelist: %{branches: ["main", "/release-.*/"]}
            }
          }
        },
        metadata: %{status: %{code: :OK}}
      }
    end)

    # wait for worker to finish and check results

    assert {:ok, pid} = WorkersSupervisor.start_worker_for_webhook(webhook.id)

    Test.Helpers.wait_for_worker_to_finish(pid, 15_000)

    assert {:ok, webhook} = HooksQueries.get_by_id(webhook.id)
    assert webhook.state == "skip_tag"
    assert webhook.result == "OK"
    assert webhook.wf_id == nil
    assert webhook.ppl_id == nil
    assert webhook.branch_id == nil
    assert webhook.commit_sha == "82b3d5ae55f7080f1e6022629cdb57bfae7cccc7"
    assert webhook.commit_author == "GitLab dev user"
    assert webhook.git_ref == "refs/tags/v1.0.0"

    GrpcMock.verify!(ProjectHubServiceMock)
  end

  test "branch-push hook but branch is not whitelisted => hook in whitelisted_branch state" do
    params = %{
      received_at: DateTime.utc_now(),
      webhook: GitlabHooks.push_commit(),
      repository_id: UUID.uuid4(),
      project_id: UUID.uuid4(),
      organization_id: UUID.uuid4(),
      provider: "gitlab"
    }

    assert {:ok, webhook} = HooksQueries.insert(params)

    # setup mocks

    ProjectHubServiceMock
    |> GrpcMock.expect(:describe, fn req, _ ->
      assert req.id == webhook.project_id

      %Projecthub.DescribeResponse{
        project: %{
          metadata: %{
            id: req.id,
            org_id: UUID.uuid4()
          },
          spec: %{
            repository: %{
              pipeline_file: ".semaphore/semaphore.yml",
              run_on: [:BRANCHES, :TAGS],
              whitelist: %{branches: ["main", "/release-.*/"]}
            }
          }
        },
        metadata: %{status: %{code: :OK}}
      }
    end)

    # wait for worker to finish and check results

    assert {:ok, pid} = WorkersSupervisor.start_worker_for_webhook(webhook.id)

    Test.Helpers.wait_for_worker_to_finish(pid, 15_000)

    assert {:ok, webhook} = HooksQueries.get_by_id(webhook.id)
    assert webhook.state == "whitelist_branch"
    assert webhook.result == "OK"
    assert webhook.wf_id == nil
    assert webhook.ppl_id == nil
    assert webhook.branch_id == nil
    assert webhook.commit_sha == "da1560886d4f094c3e6c9ef40349f7d38b5d27d7"
    assert webhook.commit_author == "GitLab dev user"
    assert webhook.git_ref == "refs/heads/master"

    GrpcMock.verify!(ProjectHubServiceMock)
  end

  test "tag-push hook but tag is not whitelisted => hook in whitelisted_tag state" do
    params = %{
      received_at: DateTime.utc_now(),
      webhook: GitlabHooks.tag_push(),
      repository_id: UUID.uuid4(),
      project_id: UUID.uuid4(),
      organization_id: UUID.uuid4(),
      provider: "gitlab"
    }

    assert {:ok, webhook} = HooksQueries.insert(params)

    # setup mocks

    ProjectHubServiceMock
    |> GrpcMock.expect(:describe, fn req, _ ->
      assert req.id == webhook.project_id

      %Projecthub.DescribeResponse{
        project: %{
          metadata: %{
            id: req.id,
            org_id: UUID.uuid4()
          },
          spec: %{
            repository: %{
              pipeline_file: ".semaphore/semaphore.yml",
              run_on: [:BRANCHES, :TAGS],
              whitelist: %{tags: ["/release-.*/"]}
            }
          }
        },
        metadata: %{status: %{code: :OK}}
      }
    end)

    # wait for worker to finish and check results

    assert {:ok, pid} = WorkersSupervisor.start_worker_for_webhook(webhook.id)

    Test.Helpers.wait_for_worker_to_finish(pid, 15_000)

    assert {:ok, webhook} = HooksQueries.get_by_id(webhook.id)
    assert webhook.state == "whitelist_tag"
    assert webhook.result == "OK"
    assert webhook.wf_id == nil
    assert webhook.ppl_id == nil
    assert webhook.branch_id == nil
    assert webhook.commit_sha == "82b3d5ae55f7080f1e6022629cdb57bfae7cccc7"
    assert webhook.commit_author == "GitLab dev user"
    assert webhook.git_ref == "refs/tags/v1.0.0"

    GrpcMock.verify!(ProjectHubServiceMock)
  end

  test "unsupported hook type => hook is recorded as failed" do
    params = %{
      received_at: DateTime.utc_now(),
      webhook: GitlabHooks.merge_request_open(),
      repository_id: UUID.uuid4(),
      project_id: UUID.uuid4(),
      organization_id: UUID.uuid4(),
      provider: "gitlab"
    }

    assert {:ok, webhook} = HooksQueries.insert(params)

    # setup mocks

    ProjectHubServiceMock
    |> GrpcMock.expect(:describe, fn req, _ ->
      assert req.id == webhook.project_id

      %Projecthub.DescribeResponse{
        project: %{
          metadata: %{
            id: req.id,
            org_id: UUID.uuid4()
          },
          spec: %{
            repository: %{
              pipeline_file: ".semaphore/semaphore.yml",
              run_on: [:BRANCHES, :TAGS],
              whitelist: %{tags: ["/release-.*/"]}
            }
          }
        },
        metadata: %{status: %{code: :OK}}
      }
    end)

    # wait for worker to finish and check results

    assert {:ok, pid} = WorkersSupervisor.start_worker_for_webhook(webhook.id)

    Test.Helpers.wait_for_worker_to_finish(pid, 15_000)

    assert {:ok, webhook} = HooksQueries.get_by_id(webhook.id)
    assert webhook.state == "failed"
    assert webhook.result == "BAD REQUEST"
    assert webhook.wf_id == nil
    assert webhook.ppl_id == nil
    assert webhook.branch_id == nil
    assert webhook.commit_sha == nil
    assert webhook.commit_author == nil
    assert webhook.git_ref == nil

    GrpcMock.verify!(ProjectHubServiceMock)
  end
end
