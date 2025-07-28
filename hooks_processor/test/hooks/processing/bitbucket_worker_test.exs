# credo:disable-for-this-file Credo.Check.Design.DuplicatedCode
defmodule HooksProcessor.Hooks.Processing.BitbucketWorkerTest do
  use ExUnit.Case

  alias Support.BitbucketHooks
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
    Application.put_env(:hooks_processor, :webhook_provider, "bitbucket")

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
      webhook: BitbucketHooks.push_new_branch_with_commits(),
      repository_id: UUID.uuid4(),
      project_id: UUID.uuid4(),
      organization_id: UUID.uuid4(),
      provider: "bitbucket"
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
      assert req.name == "new-branch-push-new-commits"
      assert req.display_name == "new-branch-push-new-commits"
      assert req.ref_type == :BRANCH

      %FindOrCreateResponse{branch: %{id: webhook.id, name: "new-branch-push-new-commits"}, status: %{code: :OK}}
    end)

    WorkflowServiceMock
    |> GrpcMock.expect(:schedule, fn req, _ ->
      branch_name = "new-branch-push-new-commits"
      commit_sha = "2a585bde481f0d5b3a10b10997210b6eb4893897"
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
    assert webhook.commit_sha == "2a585bde481f0d5b3a10b10997210b6eb4893897"
    assert webhook.commit_author == "milana_stojadinov"
    assert webhook.git_ref == "refs/heads/new-branch-push-new-commits"

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
    assert req.service == :BITBUCKET
    assert req.definition_file == ".semaphore/semaphore.yml"
    assert req.label == label(branch_name)
    assert req.repo.owner == "milana_stojadinov"
    assert req.repo.repo_name == "elixir-project"
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
      webhook: BitbucketHooks.push_commit(),
      repository_id: UUID.uuid4(),
      project_id: UUID.uuid4(),
      organization_id: UUID.uuid4(),
      provider: "bitbucket"
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
      assert req.name == "new-branch-push-new-commits"
      assert req.display_name == "new-branch-push-new-commits"
      assert req.ref_type == :BRANCH

      %FindOrCreateResponse{branch: %{id: webhook.id, name: "new-branch-push-new-commits"}, status: %{code: :OK}}
    end)

    WorkflowServiceMock
    |> GrpcMock.expect(:schedule, fn req, _ ->
      branch_name = "new-branch-push-new-commits"
      commit_sha = "daf07dd85350b95d05a7fe898e07022c5dcd95b9"
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
    assert webhook.commit_sha == "daf07dd85350b95d05a7fe898e07022c5dcd95b9"
    assert webhook.commit_author == "milana_stojadinov"
    assert webhook.git_ref == "refs/heads/new-branch-push-new-commits"

    GrpcMock.verify!(ProjectHubServiceMock)
    GrpcMock.verify!(BranchServiceMock)
    GrpcMock.verify!(WorkflowServiceMock)
  end

  test "valid branch-deleted hook => branch is archived" do
    params = %{
      received_at: DateTime.utc_now(),
      webhook: BitbucketHooks.branch_deletion(),
      repository_id: UUID.uuid4(),
      project_id: UUID.uuid4(),
      organization_id: UUID.uuid4(),
      provider: "bitbucket"
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
      assert req.branch_name == "mtmp1123333333"
      assert req.reason == :BRANCH_DELETION

      %TerminateAllResponse{response_status: %{code: :OK}}
    end)

    BranchServiceMock
    |> GrpcMock.expect(:describe, fn req, _ ->
      assert req.project_id == webhook.project_id
      assert req.branch_name == "mtmp1123333333"

      %DescribeResponse{branch: %{id: webhook.id, name: "mtmp1123333333"}, status: %{code: :OK}}
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
    assert webhook.commit_sha == "d2b7d8ca15effafc1a24ac5fd099f34b5447c9ad"
    assert webhook.commit_author == "milana_stojadinov"
    assert webhook.git_ref == "refs/heads/mtmp1123333333"

    GrpcMock.verify!(ProjectHubServiceMock)
    GrpcMock.verify!(BranchServiceMock)
  end

  test "valid tag-push hook => tag is created and workflow is scheduled" do
    params = %{
      received_at: DateTime.utc_now(),
      webhook: BitbucketHooks.push_annoted_tag(),
      repository_id: UUID.uuid4(),
      project_id: UUID.uuid4(),
      organization_id: UUID.uuid4(),
      provider: "bitbucket"
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
      assert req.name == "refs/tags/v1.6"
      assert req.display_name == "v1.6"
      assert req.ref_type == :TAG

      %FindOrCreateResponse{branch: %{id: webhook.id, name: "refs/tags/v1.6"}, status: %{code: :OK}}
    end)

    WorkflowServiceMock
    |> GrpcMock.expect(:schedule, fn req, _ ->
      branch_name = "refs/tags/v1.6"
      commit_sha = "daf07dd85350b95d05a7fe898e07022c5dcd95b9"
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
    assert webhook.commit_sha == "daf07dd85350b95d05a7fe898e07022c5dcd95b9"
    assert webhook.commit_author == "milana_stojadinov"
    assert webhook.git_ref == "refs/tags/v1.6"

    GrpcMock.verify!(ProjectHubServiceMock)
    GrpcMock.verify!(BranchServiceMock)
    GrpcMock.verify!(WorkflowServiceMock)
  end

  test "[skip ci] flag in branch-push hook => hook in skip_ci state" do
    params = %{
      received_at: DateTime.utc_now(),
      webhook: BitbucketHooks.branch_push_skip_ci(),
      repository_id: UUID.uuid4(),
      project_id: UUID.uuid4(),
      organization_id: UUID.uuid4(),
      provider: "bitbucket"
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
    assert webhook.commit_sha == "175d0109daf6f1bb2489b9bb4ac6809a3ea2c11d"
    assert webhook.commit_author == "milana_stojadinov"
    assert webhook.git_ref == "refs/heads/new-branch-push-new-commits"

    GrpcMock.verify!(ProjectHubServiceMock)
  end

  test "[skip ci] flag in tag-push hook => hook in skip_ci state" do
    params = %{
      received_at: DateTime.utc_now(),
      webhook: BitbucketHooks.tag_push_skip_ci(),
      repository_id: UUID.uuid4(),
      project_id: UUID.uuid4(),
      organization_id: UUID.uuid4(),
      provider: "bitbucket"
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
    assert webhook.commit_sha == "175d0109daf6f1bb2489b9bb4ac6809a3ea2c11d"
    assert webhook.commit_author == "milana_stojadinov"
    assert webhook.git_ref == "refs/tags/v1.6"

    GrpcMock.verify!(ProjectHubServiceMock)
  end

  test "branch-push hook but project doesn't run on branches => hook in skip_branch state" do
    params = %{
      received_at: DateTime.utc_now(),
      webhook: BitbucketHooks.push_commit(),
      repository_id: UUID.uuid4(),
      project_id: UUID.uuid4(),
      organization_id: UUID.uuid4(),
      provider: "bitbucket"
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
    assert webhook.commit_sha == "daf07dd85350b95d05a7fe898e07022c5dcd95b9"
    assert webhook.commit_author == "milana_stojadinov"
    assert webhook.git_ref == "refs/heads/new-branch-push-new-commits"

    GrpcMock.verify!(ProjectHubServiceMock)
  end

  test "tag-push hook but project doesn't run on tags => hook in skip_tag state" do
    params = %{
      received_at: DateTime.utc_now(),
      webhook: BitbucketHooks.push_annoted_tag(),
      repository_id: UUID.uuid4(),
      project_id: UUID.uuid4(),
      organization_id: UUID.uuid4(),
      provider: "bitbucket"
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
              whitelist: %{branches: ["master", "/release-.*/"]}
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
    assert webhook.commit_sha == "daf07dd85350b95d05a7fe898e07022c5dcd95b9"
    assert webhook.commit_author == "milana_stojadinov"
    assert webhook.git_ref == "refs/tags/v1.6"

    GrpcMock.verify!(ProjectHubServiceMock)
  end

  test "branch-push hook but branch is not whitelisted => hook in whitelisted_branch state" do
    params = %{
      received_at: DateTime.utc_now(),
      webhook: BitbucketHooks.push_commit(),
      repository_id: UUID.uuid4(),
      project_id: UUID.uuid4(),
      organization_id: UUID.uuid4(),
      provider: "bitbucket"
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
              whitelist: %{branches: ["master", "/release-.*/"]}
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
    assert webhook.commit_sha == "daf07dd85350b95d05a7fe898e07022c5dcd95b9"
    assert webhook.commit_author == "milana_stojadinov"
    assert webhook.git_ref == "refs/heads/new-branch-push-new-commits"

    GrpcMock.verify!(ProjectHubServiceMock)
  end

  test "tag-push hook but tag is not whitelisted => hook in whitelisted_tag state" do
    params = %{
      received_at: DateTime.utc_now(),
      webhook: BitbucketHooks.push_annoted_tag(),
      repository_id: UUID.uuid4(),
      project_id: UUID.uuid4(),
      organization_id: UUID.uuid4(),
      provider: "bitbucket"
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
    assert webhook.commit_sha == "daf07dd85350b95d05a7fe898e07022c5dcd95b9"
    assert webhook.commit_author == "milana_stojadinov"
    assert webhook.git_ref == "refs/tags/v1.6"

    GrpcMock.verify!(ProjectHubServiceMock)
  end

  test "unsupported hook type => hook is recorded as failed" do
    params = %{
      received_at: DateTime.utc_now(),
      webhook: BitbucketHooks.pull_request_open(),
      repository_id: UUID.uuid4(),
      project_id: UUID.uuid4(),
      organization_id: UUID.uuid4(),
      provider: "bitbucket"
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
    assert webhook.provider == "bitbucket"
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
