defmodule Front.Models.ProjectTest do
  use ExUnit.Case

  import Mock

  alias Front.Models.Project

  describe ".find" do
    test "when the project can be found by name => returns the project" do
      project = Support.Factories.projecthub_api_described_project([], false)

      response =
        InternalApi.Projecthub.DescribeResponse.new(
          metadata: Support.Factories.response_meta(),
          project: project
        )

      GrpcMock.stub(ProjecthubMock, :describe, fn req, _stream ->
        assert req.name == project.metadata.name

        response
      end)

      assert Project.find(project.metadata.name, "231312312312-123-12-312-312") == %Project{
               :id => project.metadata.id,
               :name => project.metadata.name,
               :owner_id => project.metadata.owner_id,
               :organization_id => project.metadata.org_id,
               :description => project.metadata.description,
               :created_at => Timex.from_unix(project.metadata.created_at.seconds),
               :repo_owner => project.spec.repository.owner,
               :repo_name => project.spec.repository.name,
               :repo_url => project.spec.repository.url,
               :repo_public => project.spec.repository.public,
               :repo_id => project.spec.repository.id,
               :repo_default_branch => project.spec.repository.default_branch,
               :run => true,
               :build_branches => false,
               :build_forked_prs => true,
               :build_draft_prs => true,
               :build_prs => false,
               :build_tags => true,
               :expose_secrets => true,
               :allowed_secrets => "secret-1, secret-2",
               :filter_contributors => false,
               :allowed_contributors => "",
               :initial_pipeline_file => ".semaphore/semaphore.yml",
               :branch_whitelist => "",
               :tag_whitelist => "/v.*/, foo",
               :whitelist_branches => false,
               :whitelist_tags => true,
               :public => false,
               :state => :READY,
               :state_reason => "",
               :cache_state => :READY,
               :artifact_store_state => :READY,
               :repository_state => :READY,
               :analysis_state => :READY,
               :permissions_state => :READY,
               :integration_type => :GITHUB_OAUTH_TOKEN,
               :repo_connected => false,
               :custom_permissions => false,
               :allow_debug_empty_session => false,
               :allow_debug_default_branch => false,
               :allow_debug_non_default_branch => false,
               :allow_debug_pr => false,
               :allow_debug_forked_pr => false,
               :allow_debug_tag => false,
               :allow_attach_default_branch => false,
               :allow_attach_non_default_branch => false,
               :allow_attach_pr => false,
               :allow_attach_forked_pr => false,
               :allow_attach_tag => false,
               :cache_id => "65a16553-69d9-480f-b52b-c56e6b12063e",
               :artifact_store_id => "118dcd98-97cc-4b31-8690-9c897b0adf46"
             }
    end

    test "when the project can't be found => it returns nil" do
      response =
        InternalApi.Projecthub.DescribeResponse.new(
          metadata: Support.Factories.response_meta(:NOT_FOUND)
        )

      GrpcMock.stub(ProjecthubMock, :describe, response)

      assert Project.find("231312312312-123-12-312-312", "231312312312-123-12-312-312") == nil
    end

    test "when there is something wrong on the backend => it raises an error" do
      assert_raise CaseClauseError, fn ->
        response =
          InternalApi.Projecthub.DescribeResponse.new(
            metadata: Support.Factories.response_meta(:FAILED_PRECONDITION)
          )

        GrpcMock.stub(ProjecthubMock, :describe, response)

        Project.find("231312312312-123-12-312-312", "231312312312-123-12-312-312")
      end
    end
  end

  describe ".destroy" do
    alias InternalApi.Projecthub.DestroyResponse
    alias InternalApi.Projecthub.ProjectService.Stub
    alias InternalApi.Projecthub.ResponseMeta

    test "when the user is not authorized to delete the project, it returns not authorized" do
      project_id = "ee2e6241-pppp-4b67-a417-f31f2fa0f104"
      user_id = "ee2e6241-uuuu-4b67-a417-f31f2fa0f105"
      org_id = "ee2e6241-oooo-4b67-a417-f31f2fa0f105"

      Support.Stubs.PermissionPatrol.remove_all_permissions()

      assert Project.destroy(project_id, user_id, org_id) == {:error, "not-authorized"}
    end

    test "when request fails, it returns an error" do
      project_id = "ee2e6241-pppp-4b67-a417-f31f2fa0f103"
      user_id = "ee2e6241-uuuu-4b67-a417-f31f2fa0f105"
      org_id = "ee2e6241-oooo-4b67-a417-f31f2fa0f105"

      response =
        DestroyResponse.new(
          metadata:
            ResponseMeta.new(
              status:
                ResponseMeta.Status.new(
                  code: ResponseMeta.Code.value(:FAILED_PRECONDITION),
                  message: "Internal error msg"
                )
            )
        )

      Support.Stubs.PermissionPatrol.allow_everything(org_id, user_id)

      with_mock Stub, destroy: fn _c, _r, _o -> response end do
        assert Project.destroy(project_id, user_id, org_id) == {:error, :grpc_req_failed}
      end
    end

    test "when project is deleted, it returns the response" do
      project_id = "ee2e6241-pppp-4b67-a417-f31f2fa0f102"
      user_id = "ee2e6241-uuuu-4b67-a417-f31f2fa0f105"
      org_id = "ee2e6241-oooo-4b67-a417-f31f2fa0f105"

      response =
        DestroyResponse.new(
          metadata:
            ResponseMeta.new(status: ResponseMeta.Status.new(code: ResponseMeta.Code.value(:OK)))
        )

      Support.Stubs.PermissionPatrol.allow_everything(org_id, user_id)

      with_mock Stub, destroy: fn _c, _r, _o -> {:ok, response} end do
        assert Project.destroy(project_id, user_id, org_id) == {:ok, response}
      end
    end
  end

  describe ".create" do
    test "when there is a problem with creating project => returns errors" do
      alias InternalApi.Projecthub.CreateResponse, as: Response
      alias InternalApi.Projecthub.ResponseMeta

      project = Support.Factories.projecthub_api_described_project()

      resp =
        Response.new(
          project: nil,
          metadata:
            ResponseMeta.new(
              status:
                ResponseMeta.Status.new(
                  code: ResponseMeta.Code.value(:FAILED_PRECONDITION),
                  message: "Error occurred"
                )
            )
        )

      GrpcMock.stub(ProjecthubMock, :create, resp)

      assert Project.create(
               project.metadata.org_id,
               project.metadata.owner_id,
               project.metadata.name,
               "",
               "github_oauth_token"
             ) == {:error, "Error occurred"}
    end

    test "when project is created => returns project" do
      alias InternalApi.Projecthub.CreateResponse, as: Response
      alias InternalApi.Projecthub.ResponseMeta

      project = Support.Factories.projecthub_api_described_project()

      resp =
        Response.new(
          project: project,
          metadata:
            ResponseMeta.new(status: ResponseMeta.Status.new(code: ResponseMeta.Code.value(:OK)))
        )

      GrpcMock.stub(ProjecthubMock, :create, resp)

      assert Project.create(
               project.metadata.org_id,
               project.metadata.owner_id,
               project.metadata.name,
               project.spec.repository.url,
               "github_oauth_token"
             ) ==
               {:ok,
                %Project{
                  :name => project.metadata.name,
                  :description => project.metadata.description,
                  :created_at => Timex.from_unix(project.metadata.created_at.seconds),
                  :owner_id => project.metadata.owner_id,
                  :organization_id => project.metadata.org_id,
                  :id => project.metadata.id,
                  :repo_owner => project.spec.repository.owner,
                  :repo_name => project.spec.repository.name,
                  :repo_url => project.spec.repository.url,
                  :repo_public => project.spec.repository.public,
                  :repo_id => project.spec.repository.id,
                  :repo_default_branch => project.spec.repository.default_branch,
                  :run => true,
                  :build_branches => false,
                  :build_forked_prs => true,
                  :build_draft_prs => true,
                  :build_prs => false,
                  :build_tags => true,
                  :expose_secrets => true,
                  :allowed_secrets => "secret-1, secret-2",
                  :filter_contributors => false,
                  :allowed_contributors => "",
                  :initial_pipeline_file => ".semaphore/semaphore.yml",
                  :branch_whitelist => "",
                  :tag_whitelist => "/v.*/, foo",
                  :whitelist_branches => false,
                  :whitelist_tags => true,
                  :public => true,
                  :state => :READY,
                  :state_reason => "",
                  :cache_id => "65a16553-69d9-480f-b52b-c56e6b12063e",
                  :cache_state => :READY,
                  :artifact_store_id => "118dcd98-97cc-4b31-8690-9c897b0adf46",
                  :artifact_store_state => :READY,
                  :repository_state => :READY,
                  :analysis_state => :READY,
                  :permissions_state => :READY,
                  :integration_type => :GITHUB_OAUTH_TOKEN,
                  :repo_connected => false,
                  :custom_permissions => false,
                  :allow_debug_empty_session => false,
                  :allow_debug_default_branch => false,
                  :allow_debug_non_default_branch => false,
                  :allow_debug_pr => false,
                  :allow_debug_forked_pr => false,
                  :allow_debug_tag => false,
                  :allow_attach_default_branch => false,
                  :allow_attach_non_default_branch => false,
                  :allow_attach_pr => false,
                  :allow_attach_forked_pr => false,
                  :allow_attach_tag => false
                }}
    end
  end

  describe ".list" do
    test "when the responses are succesfull => it returns a list of readable projects" do
      projects = [
        Support.Factories.listed_project(),
        Support.Factories.listed_project(name: "hello-world", id: "123")
      ]

      project_list_response =
        InternalApi.Projecthub.ListResponse.new(
          metadata: Support.Factories.response_meta(),
          projects: projects,
          pagination: InternalApi.Projecthub.PaginationResponse.new(total_pages: 1)
        )

      GrpcMock.stub(ProjecthubMock, :list, project_list_response)

      GrpcMock.stub(
        RBACMock,
        :list_accessible_projects,
        InternalApi.RBAC.ListAccessibleProjectsResponse.new(
          project_ids: [Support.Factories.listed_project().metadata.id]
        )
      )

      assert Project.list("78114608-be8a-465a-b9cd-81970fb802c7", "123", 1) ==
               {[
                  %Project{
                    :name => "octocat",
                    :id => "78114608-be8a-465a-b9cd-81970fb802c6",
                    :description => "The coolest project"
                  }
                ], 1}
    end

    test "when the Guard response is unsuccesfull => it returns empty project list" do
      projects = [
        Support.Factories.listed_project(),
        Support.Factories.listed_project(name: "hello-world", id: "1237777")
      ]

      project_list_response =
        InternalApi.Projecthub.ListResponse.new(
          metadata:
            InternalApi.Projecthub.ResponseMeta.new(
              status:
                InternalApi.Projecthub.ResponseMeta.Status.new(
                  code: InternalApi.ResponseStatus.Code.value(:OK)
                )
            ),
          projects: projects,
          pagination: InternalApi.Projecthub.PaginationResponse.new(total_pages: 3)
        )

      GrpcMock.stub(ProjecthubMock, :list, project_list_response)

      GrpcMock.stub(
        RBACMock,
        :list_accessible_projects,
        InternalApi.RBAC.ListAccessibleProjectsResponse.new(project_ids: [])
      )

      assert Project.list("78114608-be8a-465a-b9cd-81970fb802c7", "123777") == {[], 3}
    end
  end

  describe ".list_by_owner" do
    test "when the response is a success => returns the all org projects" do
      org_id = "0255c444-4347-4307-bf5b-2daf4dd37e9d"
      owner_id = "266f155a-dbe0-4f31-a141-aa2e743926b2"
      projects = [Support.Factories.listed_project()]

      project_list_response =
        InternalApi.Projecthub.ListResponse.new(
          metadata: Support.Factories.response_meta(),
          projects: projects,
          pagination:
            InternalApi.Projecthub.PaginationResponse.new(
              total_pages: 3,
              total_entries: 20
            )
        )

      GrpcMock.stub(ProjecthubMock, :list, project_list_response)

      {:ok, projects} = Project.list_by_owner(org_id, owner_id)
      assert Enum.count(projects) == 1
    end

    test "when the response is not ok => returns an error" do
      org_id = "0255c444-4347-4307-bf5b-2daf4dd37e9d"
      owner_id = "266f155a-dbe0-4f31-a141-aa2e743926b2"

      project_list_response =
        InternalApi.Projecthub.ListResponse.new(
          metadata:
            InternalApi.Projecthub.ResponseMeta.new(
              status:
                InternalApi.Projecthub.ResponseMeta.Status.new(
                  code: InternalApi.ResponseStatus.Code.value(:BAD_PARAM)
                )
            )
        )

      GrpcMock.stub(ProjecthubMock, :list, project_list_response)

      {:error, _} = Project.list_by_owner(org_id, owner_id)
    end
  end

  describe ".list_by_repo_url" do
    test "when the response is a success => returns the all org projects" do
      org_id = "0255c444-4347-4307-bf5b-2daf4dd37e9d"
      repo_url = "git@github.com/octocat/project.git"
      projects = [Support.Factories.listed_project()]

      project_list_response =
        InternalApi.Projecthub.ListResponse.new(
          metadata: Support.Factories.response_meta(),
          projects: projects,
          pagination:
            InternalApi.Projecthub.PaginationResponse.new(
              total_pages: 3,
              total_entries: 20
            )
        )

      GrpcMock.stub(ProjecthubMock, :list, project_list_response)

      {:ok, projects} = Project.list_by_repo_url(org_id, repo_url)
      assert Enum.count(projects) == 1
    end

    test "when the response is not ok => returns an error" do
      org_id = "0255c444-4347-4307-bf5b-2daf4dd37e9d"
      repo_url = "git@github.com/octocat/project.git"

      project_list_response =
        InternalApi.Projecthub.ListResponse.new(
          metadata:
            InternalApi.Projecthub.ResponseMeta.new(
              status:
                InternalApi.Projecthub.ResponseMeta.Status.new(
                  code: InternalApi.ResponseStatus.Code.value(:BAD_PARAM)
                )
            )
        )

      GrpcMock.stub(ProjecthubMock, :list, project_list_response)

      {:error, _} = Project.list_by_repo_url(org_id, repo_url)
    end
  end

  describe ".list_all" do
    test "when the response is a success => returns the all org projects" do
      projects = [Support.Factories.listed_project()]

      project_list_response =
        InternalApi.Projecthub.ListResponse.new(
          metadata: Support.Factories.response_meta(),
          projects: projects,
          pagination:
            InternalApi.Projecthub.PaginationResponse.new(
              total_pages: 3,
              total_entries: 20
            )
        )

      GrpcMock.stub(ProjecthubMock, :list, project_list_response)

      {:ok, projects} = Project.list_all("123")
      assert Enum.count(projects) == 1
    end

    test "when the response is not ok => returns an error" do
      project_list_response =
        InternalApi.Projecthub.ListResponse.new(
          metadata:
            InternalApi.Projecthub.ResponseMeta.new(
              status:
                InternalApi.Projecthub.ResponseMeta.Status.new(
                  code: InternalApi.ResponseStatus.Code.value(:BAD_PARAM)
                )
            )
        )

      GrpcMock.stub(ProjecthubMock, :list, project_list_response)

      {:error, _} = Project.list_all("123")
    end
  end

  describe ".count" do
    test "when the response is a success => returns the count of all org projects" do
      projects = [Support.Factories.listed_project()]

      project_list_response =
        InternalApi.Projecthub.ListResponse.new(
          metadata: Support.Factories.response_meta(),
          projects: projects,
          pagination:
            InternalApi.Projecthub.PaginationResponse.new(
              total_pages: 3,
              total_entries: 20
            )
        )

      GrpcMock.stub(ProjecthubMock, :list, project_list_response)

      {:ok, count} = Project.count("123")
      assert count == 20
    end

    test "when the response is not ok => returns an error" do
      project_list_response =
        InternalApi.Projecthub.ListResponse.new(
          metadata:
            InternalApi.Projecthub.ResponseMeta.new(
              status:
                InternalApi.Projecthub.ResponseMeta.Status.new(
                  code: InternalApi.ResponseStatus.Code.value(:BAD_PARAM)
                )
            )
        )

      GrpcMock.stub(ProjecthubMock, :list, project_list_response)

      {:error, _} = Project.count("123")
    end
  end
end
