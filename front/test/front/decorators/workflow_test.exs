defmodule Front.Decorators.WorkflowTest do
  use Front.TestCase

  alias Front.Decorators
  alias Support.Stubs.DB

  @moduletag :skip

  setup do
    Support.Stubs.init()
    Support.Stubs.build_shared_factories()

    project = DB.first(:projects)

    GrpcMock.stub(PipelineMock, :list, fn _req, _stream ->
      InternalApi.Plumber.ListResponse.new(
        pipelines: [],
        response_status:
          InternalApi.Plumber.ResponseStatus.new(
            code: InternalApi.Plumber.ResponseStatus.ResponseCode.value(:OK)
          )
      )
    end)

    tag_hook =
      InternalApi.RepoProxy.Hook.new(
        hook_id: "af363c47-9b8a-46fc-a1f3-02e17d1bf063",
        head_commit_sha: "6b962d30e851eeaaa344c08ab5fc1a849d4fa892",
        commit_message: "Dummy semaphore yml update",
        repo_host_url: "https://github.com/octocat/vampyri-bot",
        repo_host_username: "octocat",
        repo_host_email: "octocat@github.com",
        repo_host_avatar_url: "https://avatars3.githubusercontent.com/u/0?v=4",
        tag_name: "v0.1",
        git_ref_type: InternalApi.RepoProxy.Hook.Type.value(:TAG),
        branch_name: "refs/tags/v0.1",
        repo_slug: "octocat/vampyri-bot",
        git_ref: "refs/tags/v0.1",
        commit_author: "octocat"
      )

    pr_hook =
      InternalApi.RepoProxy.Hook.new(
        hook_id: "4ab71575-2bcb-4fdb-9248-d922d1670719",
        head_commit_sha: "0b9995d5de71603dc2793d07914f0de16873159c",
        commit_message: "dummy pr",
        repo_host_url: "https://github.com/octocat/vampyri-bot",
        repo_host_username: "octocat",
        repo_host_avatar_url: "https://avatars3.githubusercontent.com/u/0?v=4",
        pr_name: "dummy pr",
        pr_number: "8",
        git_ref_type: InternalApi.RepoProxy.Hook.Type.value(:PR),
        branch_name: "master",
        repo_slug: "octocat/vampyri-bot",
        pr_slug: "octocat/vampyri-bot",
        pr_sha: "6b962d30e851eeaaa344c08ab5fc1a849d4fa892",
        git_ref: "refs/semaphoreci/0b9995d5de71603dc2793d07914f0de16873159c",
        commit_range:
          "89e7f39e45e803721d9e2eabcb1d1faed74df6e0...6b962d30e851eeaaa344c08ab5fc1a849d4fa892",
        pr_mergeable: true,
        pr_branch_name: "ms/branch-with-pr",
        commit_author: "octocat"
      )

    commit_hook =
      InternalApi.RepoProxy.Hook.new(
        hook_id: "935d121b-024b-471d-b03a-704851723f81",
        head_commit_sha: "60695a8784636328f4fce3c1359f962b6943568f",
        commit_message: "Dummy commit",
        repo_host_url: "https://github.com/octocat/vampyri-bot",
        repo_host_username: "octocat",
        repo_host_email: "octocat@github.com",
        repo_host_avatar_url: "https://avatars3.githubusercontent.com/u/0?v=4",
        branch_name: "test1",
        repo_slug: "octocat/vampyri-bot",
        git_ref: "refs/heads/test1",
        commit_range:
          "60695a8784636328f4fce3c1359f962b6943568f^...60695a8784636328f4fce3c1359f962b6943568f",
        commit_author: "octocat"
      )

    repo_proxy_describe_many_response =
      InternalApi.RepoProxy.DescribeManyResponse.new(
        status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
        hooks: [
          tag_hook,
          pr_hook,
          commit_hook
        ]
      )

    FunRegistry.set!(FS.RepoProxyService, :describe_many, repo_proxy_describe_many_response)

    [
      project: project
    ]
  end

  describe ".decorate_many" do
    test "it decorates the workflows", %{project: project} do
      tag_wf = %Front.Models.Workflow{
        branch_id: "176188b7-1f9d-46bc-af00-694ca21dfa4b",
        branch_name: "refs/tags/v0.1",
        commit_sha: "6b962d30e851eeaaa344c08ab5fc1a849d4fa892",
        created_at: DateTime.from_unix!(1_522_495_543),
        hook_id: "af363c47-9b8a-46fc-a1f3-02e17d1bf063",
        id: "2322a1f3-2fbb-40b4-aae0-314866ad57e9",
        project_id: project.id,
        requester_id: "8ba0cbf0-cb9a-428a-ae2b-694f8f19fba5",
        rerun_of: "",
        root_pipeline_id: "0579bbf6-181a-452f-8aa6-953bccec8f0b",
        short_commit_id: "6b962d3",
        triggered_by: :HOOK
      }

      pr_wf = %Front.Models.Workflow{
        branch_id: "557abda6-1a18-403f-878a-a393f3294a8b",
        branch_name: "pull-request-8",
        commit_sha: "0b9995d5de71603dc2793d07914f0de16873159c",
        created_at: DateTime.from_unix!(1_522_495_543),
        hook_id: "4ab71575-2bcb-4fdb-9248-d922d1670719",
        id: "7edd3bc2-67ef-4f71-b61f-367ed967a7a2",
        project_id: project.id,
        requester_id: "8ba0cbf0-cb9a-428a-ae2b-694f8f19fba5",
        rerun_of: "",
        root_pipeline_id: "241b8286-e6e0-42fa-ad76-b14b7b6af537",
        short_commit_id: "0b9995d",
        triggered_by: :HOOK
      }

      commit_wf = %Front.Models.Workflow{
        branch_id: "3fbcfe20-9bb8-46ce-80d6-c778e5a80895",
        branch_name: "test1",
        commit_sha: "2c47fba013f4a3c0068e3df5340f28836f972058",
        created_at: DateTime.from_unix!(1_522_495_543),
        hook_id: "935d121b-024b-471d-b03a-704851723f81",
        id: "2515138f-915f-4f54-8bcd-23e624b97d68",
        project_id: project.id,
        requester_id: "8ba0cbf0-cb9a-428a-ae2b-694f8f19fba5",
        rerun_of: "",
        root_pipeline_id: "5f0bd595-5def-4653-9967-995df5550bad",
        short_commit_id: "2c47fba",
        triggered_by: :HOOK
      }

      wfs = [tag_wf, pr_wf, commit_wf]

      decorated_wfs = Decorators.Workflow.decorate_many(wfs)

      assert Enum.sort(decorated_wfs) ==
               Enum.sort([
                 %Front.Decorators.Workflow{
                   created_at: DateTime.from_unix!(1_522_495_543),
                   pipelines: [],
                   pr_mergeable: false,
                   project_name: project.name,
                   project_url: "/projects/#{project.name}",
                   type: "tag",
                   author_avatar_url: "https://avatars3.githubusercontent.com/u/0?v=4",
                   author_name: "octocat",
                   branch_name: "refs/tags/v0.1",
                   hook_name: "v0.1",
                   hook_url: "/branches/176188b7-1f9d-46bc-af00-694ca21dfa4b",
                   name: "Dummy semaphore yml update",
                   pr_number: "",
                   tag_name: "v0.1",
                   url:
                     "/workflows/2322a1f3-2fbb-40b4-aae0-314866ad57e9?pipeline_id=0579bbf6-181a-452f-8aa6-953bccec8f0b"
                 },
                 %Front.Decorators.Workflow{
                   branch_name: "master",
                   created_at: DateTime.from_unix!(1_522_495_543),
                   pipelines: [],
                   project_name: project.name,
                   project_url: "/projects/#{project.name}",
                   author_avatar_url: "https://avatars3.githubusercontent.com/u/0?v=4",
                   author_name: "octocat",
                   hook_name: "dummy pr",
                   hook_url: "/branches/557abda6-1a18-403f-878a-a393f3294a8b",
                   name: "dummy pr",
                   pr_mergeable: true,
                   pr_number: "8",
                   tag_name: "",
                   type: "pr",
                   url:
                     "/workflows/7edd3bc2-67ef-4f71-b61f-367ed967a7a2?pipeline_id=241b8286-e6e0-42fa-ad76-b14b7b6af537"
                 },
                 %Front.Decorators.Workflow{
                   author_avatar_url: "https://avatars3.githubusercontent.com/u/0?v=4",
                   author_name: "octocat",
                   branch_name: "test1",
                   created_at: DateTime.from_unix!(1_522_495_543),
                   hook_name: "test1",
                   hook_url: "/branches/3fbcfe20-9bb8-46ce-80d6-c778e5a80895",
                   name: "Dummy commit",
                   pipelines: [],
                   pr_mergeable: false,
                   pr_number: "",
                   project_name: project.name,
                   project_url: "/projects/#{project.name}",
                   tag_name: "",
                   type: "branch",
                   url:
                     "/workflows/2515138f-915f-4f54-8bcd-23e624b97d68?pipeline_id=5f0bd595-5def-4653-9967-995df5550bad"
                 }
               ])
    end
  end
end
