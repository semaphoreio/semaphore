# credo:disable-for-this-file Credo.Check.Design.DuplicatedCode
defmodule Projecthub.Api.GrpcServerTest do
  use Projecthub.DataCase
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney
  require Logger

  alias InternalApi.Projecthub.ProjectService.Stub
  alias Projecthub.Models.Project
  alias Projecthub.Models.User
  alias Projecthub.Models.Organization
  alias Projecthub.{RepoChecker, ParamsChecker, Fork}
  alias Projecthub.Api.GrpcServer

  setup do
    Support.FakeServices.stub_responses()
  end

  describe ".describe" do
    test "when parameters are correct => returns the project" do
      artifact_store_id = Ecto.UUID.generate()

      {:ok, project} =
        Support.Factories.Project.create_with_repo(%{
          artifact_store_id: artifact_store_id
        })

      repository = project.repository

      {:ok, channel} =
        GRPC.Stub.connect("localhost:50051",
          interceptors: [
            Projecthub.Util.GRPC.ClientRequestIdInterceptor,
            Projecthub.Util.GRPC.ClientLoggerInterceptor,
            Projecthub.Util.GRPC.ClientRunAsyncInterceptor
          ]
        )

      request =
        InternalApi.Projecthub.DescribeRequest.new(
          metadata:
            InternalApi.Projecthub.RequestMeta.new(
              api_version: "",
              kind: "",
              req_id: "",
              org_id: "",
              user_id: "12345678-1234-5678-1234-567812345678"
            ),
          id: project.id,
          name: project.name
        )

      {:ok, response} = Stub.describe(channel, request)

      assert response ==
               InternalApi.Projecthub.DescribeResponse.new(
                 metadata:
                   InternalApi.Projecthub.ResponseMeta.new(
                     api_version: "",
                     kind: "",
                     req_id: "",
                     org_id: "",
                     user_id: "12345678-1234-5678-1234-567812345678",
                     status: InternalApi.Projecthub.ResponseMeta.Status.new(code: :OK)
                   ),
                 project:
                   InternalApi.Projecthub.Project.new(
                     metadata:
                       InternalApi.Projecthub.Project.Metadata.new(
                         name: project.name,
                         id: project.id,
                         owner_id: project.creator_id,
                         org_id: project.organization_id,
                         description: project.description,
                         created_at: Google.Protobuf.Timestamp.new(seconds: DateTime.to_unix(project.created_at))
                       ),
                     spec:
                       InternalApi.Projecthub.Project.Spec.new(
                         repository:
                           InternalApi.Projecthub.Project.Spec.Repository.new(
                             id: repository.id,
                             url: repository.url,
                             name: repository.name,
                             owner: repository.owner,
                             forked_pull_requests:
                               InternalApi.Projecthub.Project.Spec.Repository.ForkedPullRequests.new(
                                 allowed_secrets: []
                               ),
                             run_on: [:TAGS, :BRANCHES, :DRAFT_PULL_REQUESTS],
                             pipeline_file: ".semaphore/semaphore.yml",
                             status:
                               InternalApi.Projecthub.Project.Spec.Repository.Status.new(
                                 pipeline_files: [
                                   InternalApi.Projecthub.Project.Spec.Repository.Status.PipelineFile.new(
                                     path: ".semaphore/semaphore.yml",
                                     level: :PIPELINE
                                   )
                                 ]
                               ),
                             whitelist:
                               InternalApi.Projecthub.Project.Spec.Repository.Whitelist.new(
                                 branches: ["master", "/feature-*/"],
                                 tags: []
                               ),
                             public: true,
                             connected: true
                           ),
                         private: true,
                         public: false,
                         visibility: :PRIVATE,
                         custom_permissions: true,
                         debug_permissions: [:EMPTY],
                         attach_permissions: [],
                         artifact_store_id: artifact_store_id
                       ),
                     status:
                       InternalApi.Projecthub.Project.Status.new(
                         state: :READY,
                         cache: InternalApi.Projecthub.Project.Status.Cache.new(state: :INITIALIZING),
                         artifact_store: InternalApi.Projecthub.Project.Status.ArtifactStore.new(state: :READY),
                         repository: InternalApi.Projecthub.Project.Status.Repository.new(state: :INITIALIZING),
                         analysis: InternalApi.Projecthub.Project.Status.Analysis.new(state: :INITIALIZING),
                         permissions: InternalApi.Projecthub.Project.Status.Permissions.new(state: :INITIALIZING)
                       )
                   )
               )
    end

    test "when a detailed project is requested => returns the project with schedulers" do
      artifact_store_id = Ecto.UUID.generate()

      {:ok, project} =
        Support.Factories.Project.create_with_repo(%{
          artifact_store_id: artifact_store_id,
          permissions_setup: true
        })

      repository = project.repository

      {:ok, channel} =
        GRPC.Stub.connect("localhost:50051",
          interceptors: [
            Projecthub.Util.GRPC.ClientRequestIdInterceptor,
            Projecthub.Util.GRPC.ClientLoggerInterceptor,
            Projecthub.Util.GRPC.ClientRunAsyncInterceptor
          ]
        )

      request =
        InternalApi.Projecthub.DescribeRequest.new(
          metadata:
            InternalApi.Projecthub.RequestMeta.new(
              api_version: "",
              kind: "",
              req_id: "",
              org_id: project.organization_id,
              user_id: "12345678-1234-5678-1234-567812345678"
            ),
          id: project.id,
          name: project.name,
          detailed: true
        )

      {:ok, response} = Stub.describe(channel, request)

      assert response ==
               InternalApi.Projecthub.DescribeResponse.new(
                 metadata:
                   InternalApi.Projecthub.ResponseMeta.new(
                     api_version: "",
                     kind: "",
                     req_id: "",
                     org_id: project.organization_id,
                     user_id: "12345678-1234-5678-1234-567812345678",
                     status: InternalApi.Projecthub.ResponseMeta.Status.new(code: :OK)
                   ),
                 project:
                   InternalApi.Projecthub.Project.new(
                     metadata:
                       InternalApi.Projecthub.Project.Metadata.new(
                         name: project.name,
                         id: project.id,
                         owner_id: project.creator_id,
                         org_id: project.organization_id,
                         description: project.description,
                         created_at: Google.Protobuf.Timestamp.new(seconds: DateTime.to_unix(project.created_at))
                       ),
                     spec:
                       InternalApi.Projecthub.Project.Spec.new(
                         repository:
                           InternalApi.Projecthub.Project.Spec.Repository.new(
                             id: repository.id,
                             url: repository.url,
                             name: repository.name,
                             owner: repository.owner,
                             forked_pull_requests:
                               InternalApi.Projecthub.Project.Spec.Repository.ForkedPullRequests.new(
                                 allowed_secrets: []
                               ),
                             run_on: [:TAGS, :BRANCHES, :DRAFT_PULL_REQUESTS],
                             pipeline_file: ".semaphore/semaphore.yml",
                             status:
                               InternalApi.Projecthub.Project.Spec.Repository.Status.new(
                                 pipeline_files: [
                                   InternalApi.Projecthub.Project.Spec.Repository.Status.PipelineFile.new(
                                     path: ".semaphore/semaphore.yml",
                                     level: :PIPELINE
                                   )
                                 ]
                               ),
                             whitelist:
                               InternalApi.Projecthub.Project.Spec.Repository.Whitelist.new(
                                 branches: ["master", "/feature-*/"],
                                 tags: []
                               ),
                             public: true,
                             connected: true
                           ),
                         schedulers: [],
                         private: true,
                         public: false,
                         visibility: :PRIVATE,
                         custom_permissions: true,
                         debug_permissions: [:EMPTY],
                         attach_permissions: [],
                         artifact_store_id: artifact_store_id
                       ),
                     status:
                       InternalApi.Projecthub.Project.Status.new(
                         state: :READY,
                         cache: InternalApi.Projecthub.Project.Status.Cache.new(state: :INITIALIZING),
                         artifact_store: InternalApi.Projecthub.Project.Status.ArtifactStore.new(state: :READY),
                         repository: InternalApi.Projecthub.Project.Status.Repository.new(state: :INITIALIZING),
                         analysis: InternalApi.Projecthub.Project.Status.Analysis.new(state: :INITIALIZING),
                         permissions: InternalApi.Projecthub.Project.Status.Permissions.new(state: :READY)
                       )
                   )
               )
    end

    test "when a detailed project is requested and just run is disabled => returns the project with schedulers" do
      artifact_store_id = Ecto.UUID.generate()

      FunRegistry.set!(
        Support.FakeServices.PeriodicSchedulerService,
        :list,
        InternalApi.PeriodicScheduler.ListResponse.new(
          status: InternalApi.Status.new(code: Google.Rpc.Code.value(:OK)),
          periodics: [
            InternalApi.PeriodicScheduler.Periodic.new(
              id: "12345678-1234-5678-1234-567812345678",
              name: "test",
              project_id: "12345678-1234-5678-1234-567812345678",
              branch: "master",
              at: "0 0 * * *",
              pipeline_file: ".semaphore/semaphore.yml",
              requester_id: "12345678-1234-5678-1234-567812345678",
              recurring: true,
              parameters: []
            )
          ]
        )
      )

      on_exit(fn ->
        FunRegistry.set!(
          Support.FakeServices.PeriodicSchedulerService,
          :list,
          InternalApi.PeriodicScheduler.ListResponse.new(
            status: InternalApi.Status.new(code: Google.Rpc.Code.value(:OK)),
            periodics: []
          )
        )
      end)

      {:ok, project} =
        Support.Factories.Project.create_with_repo(%{
          artifact_store_id: artifact_store_id,
          permissions_setup: true
        })

      repository = project.repository

      {:ok, channel} =
        GRPC.Stub.connect("localhost:50051",
          interceptors: [
            Projecthub.Util.GRPC.ClientRequestIdInterceptor,
            Projecthub.Util.GRPC.ClientLoggerInterceptor,
            Projecthub.Util.GRPC.ClientRunAsyncInterceptor
          ]
        )

      request =
        InternalApi.Projecthub.DescribeRequest.new(
          metadata:
            InternalApi.Projecthub.RequestMeta.new(
              api_version: "",
              kind: "",
              req_id: "",
              org_id: project.organization_id,
              user_id: "12345678-1234-5678-1234-567812345678"
            ),
          id: project.id,
          name: project.name,
          detailed: true
        )

      {:ok, response} = Stub.describe(channel, request)

      assert response ==
               InternalApi.Projecthub.DescribeResponse.new(
                 metadata:
                   InternalApi.Projecthub.ResponseMeta.new(
                     api_version: "",
                     kind: "",
                     req_id: "",
                     org_id: project.organization_id,
                     user_id: "12345678-1234-5678-1234-567812345678",
                     status: InternalApi.Projecthub.ResponseMeta.Status.new(code: :OK)
                   ),
                 project:
                   InternalApi.Projecthub.Project.new(
                     metadata:
                       InternalApi.Projecthub.Project.Metadata.new(
                         name: project.name,
                         id: project.id,
                         owner_id: project.creator_id,
                         org_id: project.organization_id,
                         description: project.description,
                         created_at: Google.Protobuf.Timestamp.new(seconds: DateTime.to_unix(project.created_at))
                       ),
                     spec:
                       InternalApi.Projecthub.Project.Spec.new(
                         repository:
                           InternalApi.Projecthub.Project.Spec.Repository.new(
                             id: repository.id,
                             url: repository.url,
                             name: repository.name,
                             owner: repository.owner,
                             forked_pull_requests:
                               InternalApi.Projecthub.Project.Spec.Repository.ForkedPullRequests.new(
                                 allowed_secrets: []
                               ),
                             run_on: [:TAGS, :BRANCHES, :DRAFT_PULL_REQUESTS],
                             pipeline_file: ".semaphore/semaphore.yml",
                             status:
                               InternalApi.Projecthub.Project.Spec.Repository.Status.new(
                                 pipeline_files: [
                                   InternalApi.Projecthub.Project.Spec.Repository.Status.PipelineFile.new(
                                     path: ".semaphore/semaphore.yml",
                                     level: :PIPELINE
                                   )
                                 ]
                               ),
                             whitelist:
                               InternalApi.Projecthub.Project.Spec.Repository.Whitelist.new(
                                 branches: ["master", "/feature-*/"],
                                 tags: []
                               ),
                             public: true,
                             connected: true
                           ),
                         schedulers: [
                           InternalApi.Projecthub.Project.Spec.Scheduler.new(
                             id: "12345678-1234-5678-1234-567812345678",
                             name: "test",
                             branch: "master",
                             at: "0 0 * * *",
                             pipeline_file: ".semaphore/semaphore.yml",
                             status: :STATUS_ACTIVE
                           )
                         ],
                         private: true,
                         public: false,
                         visibility: :PRIVATE,
                         custom_permissions: true,
                         debug_permissions: [:EMPTY],
                         attach_permissions: [],
                         artifact_store_id: artifact_store_id
                       ),
                     status:
                       InternalApi.Projecthub.Project.Status.new(
                         state: :READY,
                         cache: InternalApi.Projecthub.Project.Status.Cache.new(state: :INITIALIZING),
                         artifact_store: InternalApi.Projecthub.Project.Status.ArtifactStore.new(state: :READY),
                         repository: InternalApi.Projecthub.Project.Status.Repository.new(state: :INITIALIZING),
                         analysis: InternalApi.Projecthub.Project.Status.Analysis.new(state: :INITIALIZING),
                         permissions: InternalApi.Projecthub.Project.Status.Permissions.new(state: :READY)
                       )
                   )
               )
    end

    test "when a detailed project is requested and just run is enabled => returns the project with schedulers" do
      artifact_store_id = Ecto.UUID.generate()

      FunRegistry.set!(Support.FakeServices.FeatureService, :list_organization_features, fn _req, _ ->
        availability = InternalApi.Feature.Availability.new(state: :ENABLED, quantity: 10)

        InternalApi.Feature.ListOrganizationFeaturesResponse.new(
          organization_features: [
            [feature: %{type: "max_projects_in_org"}, availability: availability],
            [
              feature: %{type: "just_run"},
              availability: InternalApi.Feature.Availability.new(state: :ENABLED, quantity: 1)
            ]
          ]
        )
      end)

      FunRegistry.set!(
        Support.FakeServices.PeriodicSchedulerService,
        :list,
        InternalApi.PeriodicScheduler.ListResponse.new(
          status: InternalApi.Status.new(code: Google.Rpc.Code.value(:OK)),
          periodics: [
            InternalApi.PeriodicScheduler.Periodic.new(
              id: "12345678-1234-5678-1234-567812345678",
              name: "test",
              description: "test description",
              project_id: "12345678-1234-5678-1234-567812345678",
              branch: "master",
              at: "",
              pipeline_file: ".semaphore/semaphore.yml",
              requester_id: "12345678-1234-5678-1234-567812345678",
              recurring: false,
              parameters: [
                InternalApi.PeriodicScheduler.Periodic.Parameter.new(
                  name: "parameter",
                  required: true,
                  description: "description",
                  default_value: "default_value",
                  options: ["default_value", "other_value"]
                )
              ]
            )
          ]
        )
      )

      on_exit(fn ->
        FunRegistry.set!(
          Support.FakeServices.PeriodicSchedulerService,
          :list,
          InternalApi.PeriodicScheduler.ListResponse.new(
            status: InternalApi.Status.new(code: Google.Rpc.Code.value(:OK)),
            periodics: []
          )
        )

        FunRegistry.set!(Support.FakeServices.FeatureService, :list_organization_features, fn _req, _ ->
          availability = InternalApi.Feature.Availability.new(state: :ENABLED, quantity: 10)

          InternalApi.Feature.ListOrganizationFeaturesResponse.new(
            organization_features: [
              [feature: %{type: "max_projects_in_org"}, availability: availability]
            ]
          )
        end)
      end)

      {:ok, project} =
        Support.Factories.Project.create_with_repo(%{
          artifact_store_id: artifact_store_id,
          permissions_setup: true
        })

      repository = project.repository

      {:ok, channel} =
        GRPC.Stub.connect("localhost:50051",
          interceptors: [
            Projecthub.Util.GRPC.ClientRequestIdInterceptor,
            Projecthub.Util.GRPC.ClientLoggerInterceptor,
            Projecthub.Util.GRPC.ClientRunAsyncInterceptor
          ]
        )

      request =
        InternalApi.Projecthub.DescribeRequest.new(
          metadata:
            InternalApi.Projecthub.RequestMeta.new(
              api_version: "",
              kind: "",
              req_id: "",
              org_id: project.organization_id,
              user_id: "12345678-1234-5678-1234-567812345678"
            ),
          id: project.id,
          name: project.name,
          detailed: true
        )

      {:ok, response} = Stub.describe(channel, request)

      assert response ==
               InternalApi.Projecthub.DescribeResponse.new(
                 metadata:
                   InternalApi.Projecthub.ResponseMeta.new(
                     api_version: "",
                     kind: "",
                     req_id: "",
                     org_id: project.organization_id,
                     user_id: "12345678-1234-5678-1234-567812345678",
                     status: InternalApi.Projecthub.ResponseMeta.Status.new(code: :OK)
                   ),
                 project:
                   InternalApi.Projecthub.Project.new(
                     metadata:
                       InternalApi.Projecthub.Project.Metadata.new(
                         name: project.name,
                         id: project.id,
                         owner_id: project.creator_id,
                         org_id: project.organization_id,
                         description: project.description,
                         created_at: Google.Protobuf.Timestamp.new(seconds: DateTime.to_unix(project.created_at))
                       ),
                     spec:
                       InternalApi.Projecthub.Project.Spec.new(
                         repository:
                           InternalApi.Projecthub.Project.Spec.Repository.new(
                             id: repository.id,
                             url: repository.url,
                             name: repository.name,
                             owner: repository.owner,
                             forked_pull_requests:
                               InternalApi.Projecthub.Project.Spec.Repository.ForkedPullRequests.new(
                                 allowed_secrets: []
                               ),
                             run_on: [:TAGS, :BRANCHES, :DRAFT_PULL_REQUESTS],
                             pipeline_file: ".semaphore/semaphore.yml",
                             status:
                               InternalApi.Projecthub.Project.Spec.Repository.Status.new(
                                 pipeline_files: [
                                   InternalApi.Projecthub.Project.Spec.Repository.Status.PipelineFile.new(
                                     path: ".semaphore/semaphore.yml",
                                     level: :PIPELINE
                                   )
                                 ]
                               ),
                             whitelist:
                               InternalApi.Projecthub.Project.Spec.Repository.Whitelist.new(
                                 branches: ["master", "/feature-*/"],
                                 tags: []
                               ),
                             public: true,
                             connected: true
                           ),
                         tasks: [
                           InternalApi.Projecthub.Project.Spec.Task.new(
                             id: "12345678-1234-5678-1234-567812345678",
                             name: "test",
                             description: "test description",
                             branch: "master",
                             at: "",
                             pipeline_file: ".semaphore/semaphore.yml",
                             status: :STATUS_ACTIVE,
                             recurring: false,
                             parameters: [
                               InternalApi.Projecthub.Project.Spec.Task.Parameter.new(
                                 name: "parameter",
                                 required: true,
                                 description: "description",
                                 default_value: "default_value",
                                 options: ["default_value", "other_value"]
                               )
                             ]
                           )
                         ],
                         private: true,
                         public: false,
                         visibility: :PRIVATE,
                         custom_permissions: true,
                         debug_permissions: [:EMPTY],
                         attach_permissions: [],
                         artifact_store_id: artifact_store_id
                       ),
                     status:
                       InternalApi.Projecthub.Project.Status.new(
                         state: :READY,
                         cache: InternalApi.Projecthub.Project.Status.Cache.new(state: :INITIALIZING),
                         artifact_store: InternalApi.Projecthub.Project.Status.ArtifactStore.new(state: :READY),
                         repository: InternalApi.Projecthub.Project.Status.Repository.new(state: :INITIALIZING),
                         analysis: InternalApi.Projecthub.Project.Status.Analysis.new(state: :INITIALIZING),
                         permissions: InternalApi.Projecthub.Project.Status.Permissions.new(state: :READY)
                       )
                   )
               )
    end

    test "when project is requested by id => returns the project" do
      {:ok, project} = Support.Factories.Project.create_with_repo()

      {:ok, channel} =
        GRPC.Stub.connect("localhost:50051",
          interceptors: [
            Projecthub.Util.GRPC.ClientRequestIdInterceptor,
            Projecthub.Util.GRPC.ClientLoggerInterceptor,
            Projecthub.Util.GRPC.ClientRunAsyncInterceptor
          ]
        )

      request =
        InternalApi.Projecthub.DescribeRequest.new(
          metadata:
            InternalApi.Projecthub.RequestMeta.new(
              api_version: "",
              kind: "",
              req_id: "",
              org_id: "",
              user_id: "12345678-1234-5678-1234-567812345678"
            ),
          id: project.id,
          name: ""
        )

      {:ok, response} = Stub.describe(channel, request)

      assert response.metadata.status ==
               InternalApi.Projecthub.ResponseMeta.Status.new(code: :OK)

      assert response.project.metadata.name == project.name
      assert response.project.metadata.id == project.id
      assert response.project.metadata.org_id == project.organization_id
      assert response.project.metadata.description == project.description
      assert response.project.spec.repository.url == project.repository.url
      assert response.project.spec.repository.name == project.repository.name
      assert response.project.spec.repository.owner == project.repository.owner
    end

    test "when a soft_deleted project is requested by id and soft_deleted param is true => returns the project" do
      {:ok, project} = Support.Factories.Project.create_with_repo()
      {:ok, _} = Project.soft_destroy(project, %User{github_token: "token"})

      {:ok, channel} =
        GRPC.Stub.connect("localhost:50051",
          interceptors: [
            Projecthub.Util.GRPC.ClientRequestIdInterceptor,
            Projecthub.Util.GRPC.ClientLoggerInterceptor,
            Projecthub.Util.GRPC.ClientRunAsyncInterceptor
          ]
        )

      request =
        InternalApi.Projecthub.DescribeRequest.new(
          metadata:
            InternalApi.Projecthub.RequestMeta.new(
              api_version: "",
              kind: "",
              req_id: "",
              org_id: "",
              user_id: "12345678-1234-5678-1234-567812345678"
            ),
          id: project.id,
          name: "",
          soft_deleted: true
        )

      {:ok, response} = Stub.describe(channel, request)

      assert response.metadata.status ==
               InternalApi.Projecthub.ResponseMeta.Status.new(code: :OK)

      cut_timestamp = create_cut_timestamp()
      assert response.project.metadata.name =~ "#{project.name}-deleted-#{cut_timestamp}"
      assert response.project.metadata.id == project.id
      assert response.project.metadata.org_id == project.organization_id
      assert response.project.metadata.description == project.description
      assert response.project.spec.repository.url == project.repository.url
      assert response.project.spec.repository.name == project.repository.name
      assert response.project.spec.repository.owner == project.repository.owner
    end

    test "when the project is requested by id and valid org_id => returns a project" do
      {:ok, project} = Support.Factories.Project.create_with_repo()

      {:ok, channel} =
        GRPC.Stub.connect("localhost:50051",
          interceptors: [
            Projecthub.Util.GRPC.ClientRequestIdInterceptor,
            Projecthub.Util.GRPC.ClientLoggerInterceptor,
            Projecthub.Util.GRPC.ClientRunAsyncInterceptor
          ]
        )

      request =
        InternalApi.Projecthub.DescribeRequest.new(
          metadata:
            InternalApi.Projecthub.RequestMeta.new(
              api_version: "",
              kind: "",
              req_id: "",
              org_id: project.organization_id,
              user_id: "12345678-1234-5678-1234-567812345678"
            ),
          id: project.id,
          name: ""
        )

      {:ok, response} = Stub.describe(channel, request)

      assert response.metadata.status ==
               InternalApi.Projecthub.ResponseMeta.Status.new(code: :OK)

      assert response.project.metadata.name == project.name
      assert response.project.metadata.id == project.id
      assert response.project.metadata.org_id == project.organization_id
      assert response.project.metadata.description == project.description
      assert response.project.spec.repository.url == project.repository.url
      assert response.project.spec.repository.name == project.repository.name
      assert response.project.spec.repository.owner == project.repository.owner
    end

    test "when the project is requested by id and wrong org_id => returns a not found response" do
      {:ok, project} = Support.Factories.Project.create_with_repo()

      {:ok, channel} =
        GRPC.Stub.connect("localhost:50051",
          interceptors: [
            Projecthub.Util.GRPC.ClientRequestIdInterceptor,
            Projecthub.Util.GRPC.ClientLoggerInterceptor,
            Projecthub.Util.GRPC.ClientRunAsyncInterceptor
          ]
        )

      request =
        InternalApi.Projecthub.DescribeRequest.new(
          metadata:
            InternalApi.Projecthub.RequestMeta.new(
              api_version: "",
              kind: "",
              req_id: "",
              org_id: Ecto.UUID.generate(),
              user_id: Ecto.UUID.generate()
            ),
          id: project.id,
          name: ""
        )

      {:ok, response} = Stub.describe(channel, request)

      assert response.metadata.status ==
               InternalApi.Projecthub.ResponseMeta.Status.new(
                 code: :NOT_FOUND,
                 message: "project #{project.id} not found"
               )
    end

    test "when the project is requested by name and wrong org_id => returns a not found response" do
      {:ok, project} = Support.Factories.Project.create_with_repo()

      {:ok, channel} =
        GRPC.Stub.connect("localhost:50051",
          interceptors: [
            Projecthub.Util.GRPC.ClientRequestIdInterceptor,
            Projecthub.Util.GRPC.ClientLoggerInterceptor,
            Projecthub.Util.GRPC.ClientRunAsyncInterceptor
          ]
        )

      request =
        InternalApi.Projecthub.DescribeRequest.new(
          metadata:
            InternalApi.Projecthub.RequestMeta.new(
              api_version: "",
              kind: "",
              req_id: "",
              org_id: Ecto.UUID.generate(),
              user_id: Ecto.UUID.generate()
            ),
          name: project.name
        )

      {:ok, response} = Stub.describe(channel, request)

      assert response.metadata.status ==
               InternalApi.Projecthub.ResponseMeta.Status.new(
                 code: :NOT_FOUND,
                 message: "project #{project.name} not found"
               )
    end

    test "when the project is requested by name => returns the project" do
      {:ok, project} = Support.Factories.Project.create_with_repo()

      {:ok, _project_with_same_name} =
        Support.Factories.Project.create(%{
          name: project.name
        })

      {:ok, channel} =
        GRPC.Stub.connect("localhost:50051",
          interceptors: [
            Projecthub.Util.GRPC.ClientRequestIdInterceptor,
            Projecthub.Util.GRPC.ClientLoggerInterceptor,
            Projecthub.Util.GRPC.ClientRunAsyncInterceptor
          ]
        )

      request =
        InternalApi.Projecthub.DescribeRequest.new(
          metadata:
            InternalApi.Projecthub.RequestMeta.new(
              api_version: "",
              kind: "",
              req_id: "",
              org_id: project.organization_id,
              user_id: Ecto.UUID.generate()
            ),
          id: "",
          name: project.name
        )

      {:ok, response} = Stub.describe(channel, request)

      assert response.metadata.status ==
               InternalApi.Projecthub.ResponseMeta.Status.new(code: :OK)

      assert response.project.metadata.name == project.name
      assert response.project.metadata.id == project.id
      assert response.project.metadata.org_id == project.organization_id
      assert response.project.metadata.description == project.description
      assert response.project.spec.repository.url == project.repository.url
      assert response.project.spec.repository.name == project.repository.name
      assert response.project.spec.repository.owner == project.repository.owner
    end

    test "when a soft_deleted project is requested by name and soft_deleted param is true => returns the project" do
      {:ok, project} = Support.Factories.Project.create_with_repo()
      {:ok, nil} = Project.soft_destroy(project, %User{github_token: "token"})
      {:ok, soft_deleted_project} = Project.find(project.id, true)

      {:ok, _project_with_same_name} =
        Support.Factories.Project.create(%{
          name: soft_deleted_project.name
        })

      {:ok, channel} =
        GRPC.Stub.connect("localhost:50051",
          interceptors: [
            Projecthub.Util.GRPC.ClientRequestIdInterceptor,
            Projecthub.Util.GRPC.ClientLoggerInterceptor,
            Projecthub.Util.GRPC.ClientRunAsyncInterceptor
          ]
        )

      request =
        InternalApi.Projecthub.DescribeRequest.new(
          metadata:
            InternalApi.Projecthub.RequestMeta.new(
              api_version: "",
              kind: "",
              req_id: "",
              org_id: soft_deleted_project.organization_id,
              user_id: Ecto.UUID.generate()
            ),
          id: "",
          name: soft_deleted_project.name,
          soft_deleted: true
        )

      {:ok, response} = Stub.describe(channel, request)

      assert response.metadata.status ==
               InternalApi.Projecthub.ResponseMeta.Status.new(code: :OK)

      cut_timestamp = create_cut_timestamp()
      assert response.project.metadata.name == soft_deleted_project.name
      assert response.project.metadata.name =~ "#{project.name}-deleted-#{cut_timestamp}"
      assert response.project.metadata.id == soft_deleted_project.id
      assert response.project.metadata.org_id == soft_deleted_project.organization_id
      assert response.project.metadata.description == soft_deleted_project.description
      assert response.project.spec.repository.url == soft_deleted_project.repository.url
      assert response.project.spec.repository.name == soft_deleted_project.repository.name
      assert response.project.spec.repository.owner == soft_deleted_project.repository.owner
    end

    test "when the project description is empty => returns the project" do
      {:ok, project} =
        Support.Factories.Project.create_with_repo(%{
          description: ""
        })

      {:ok, channel} =
        GRPC.Stub.connect("localhost:50051",
          interceptors: [
            Projecthub.Util.GRPC.ClientRequestIdInterceptor,
            Projecthub.Util.GRPC.ClientLoggerInterceptor,
            Projecthub.Util.GRPC.ClientRunAsyncInterceptor
          ]
        )

      request =
        InternalApi.Projecthub.DescribeRequest.new(
          metadata:
            InternalApi.Projecthub.RequestMeta.new(
              api_version: "",
              kind: "",
              req_id: "",
              org_id: project.organization_id,
              user_id: "12345678-1234-5678-1234-567812345678"
            ),
          id: project.id,
          name: ""
        )

      {:ok, response} = Stub.describe(channel, request)

      assert response.metadata.status ==
               InternalApi.Projecthub.ResponseMeta.Status.new(code: :OK)

      assert response.project.metadata.name == project.name
      assert response.project.metadata.id == project.id
      assert response.project.metadata.org_id == project.organization_id
      assert response.project.metadata.description == ""
      assert response.project.spec.repository.url == project.repository.url
      assert response.project.spec.repository.name == project.repository.name
      assert response.project.spec.repository.owner == project.repository.owner
    end

    test "when the project doesn't exist => returns a not found response" do
      {:ok, channel} =
        GRPC.Stub.connect("localhost:50051",
          interceptors: [
            Projecthub.Util.GRPC.ClientRequestIdInterceptor,
            Projecthub.Util.GRPC.ClientLoggerInterceptor,
            Projecthub.Util.GRPC.ClientRunAsyncInterceptor
          ]
        )

      org_id = Ecto.UUID.generate()

      request =
        InternalApi.Projecthub.DescribeRequest.new(
          metadata:
            InternalApi.Projecthub.RequestMeta.new(
              api_version: "",
              kind: "",
              req_id: "",
              org_id: org_id,
              user_id: "12345678-1234-5678-1234-567812345678"
            ),
          id: "",
          name: "myproject"
        )

      {:ok, response} = Stub.describe(channel, request)

      assert response ==
               InternalApi.Projecthub.DescribeResponse.new(
                 metadata:
                   InternalApi.Projecthub.ResponseMeta.new(
                     api_version: "",
                     kind: "",
                     req_id: "",
                     org_id: org_id,
                     user_id: "12345678-1234-5678-1234-567812345678",
                     status:
                       InternalApi.Projecthub.ResponseMeta.Status.new(
                         code: :NOT_FOUND,
                         message: "project myproject not found"
                       )
                   )
               )
    end

    test "when the project doesn't exist and there is a retry => returns a not found response" do
      {:ok, channel} =
        GRPC.Stub.connect("localhost:50051",
          interceptors: [
            Projecthub.Util.GRPC.ClientRequestIdInterceptor,
            Projecthub.Util.GRPC.ClientLoggerInterceptor,
            Projecthub.Util.GRPC.ClientRunAsyncInterceptor
          ]
        )

      org_id = Ecto.UUID.generate()

      request =
        InternalApi.Projecthub.DescribeRequest.new(
          metadata:
            InternalApi.Projecthub.RequestMeta.new(
              api_version: "",
              kind: "",
              req_id: "",
              org_id: org_id,
              user_id: "12345678-1234-5678-1234-567812345678"
            ),
          id: "myproject",
          name: ""
        )

      {:ok, response} = Stub.describe(channel, request)

      assert response ==
               InternalApi.Projecthub.DescribeResponse.new(
                 metadata:
                   InternalApi.Projecthub.ResponseMeta.new(
                     api_version: "",
                     kind: "",
                     req_id: "",
                     org_id: org_id,
                     user_id: "12345678-1234-5678-1234-567812345678",
                     status:
                       InternalApi.Projecthub.ResponseMeta.Status.new(
                         code: :NOT_FOUND,
                         message: "project myproject not found"
                       )
                   )
               )
    end

    test "when the project is soft deleted => returns a not found response" do
      org_id = Ecto.UUID.generate()
      {:ok, project} = Support.Factories.Project.create_with_repo(%{organization_id: org_id})
      {:ok, _} = Project.soft_destroy(project, %User{github_token: "token"})

      {:ok, channel} =
        GRPC.Stub.connect("localhost:50051",
          interceptors: [
            Projecthub.Util.GRPC.ClientRequestIdInterceptor,
            Projecthub.Util.GRPC.ClientLoggerInterceptor,
            Projecthub.Util.GRPC.ClientRunAsyncInterceptor
          ]
        )

      request =
        InternalApi.Projecthub.DescribeRequest.new(
          metadata:
            InternalApi.Projecthub.RequestMeta.new(
              api_version: "",
              kind: "",
              req_id: "",
              org_id: "",
              user_id: "12345678-1234-5678-1234-567812345678"
            ),
          id: project.id,
          name: ""
        )

      {:ok, response} = Stub.describe(channel, request)

      assert response ==
               InternalApi.Projecthub.DescribeResponse.new(
                 metadata:
                   InternalApi.Projecthub.ResponseMeta.new(
                     api_version: "",
                     kind: "",
                     req_id: "",
                     org_id: "",
                     user_id: "12345678-1234-5678-1234-567812345678",
                     status:
                       InternalApi.Projecthub.ResponseMeta.Status.new(
                         code: :NOT_FOUND,
                         message: "project #{project.id} not found"
                       )
                   )
               )
    end
  end

  describe ".describe_many" do
    test "it returns the projects" do
      {:ok, channel} =
        GRPC.Stub.connect("localhost:50051",
          interceptors: [
            Projecthub.Util.GRPC.ClientRequestIdInterceptor,
            Projecthub.Util.GRPC.ClientLoggerInterceptor,
            Projecthub.Util.GRPC.ClientRunAsyncInterceptor
          ]
        )

      org_id = Ecto.UUID.generate()

      {:ok, project1} =
        Support.Factories.Project.create_with_repo(%{
          organization_id: org_id
        })

      {:ok, project2} =
        Support.Factories.Project.create_with_repo(%{
          organization_id: org_id
        })

      {:ok, project3} =
        Support.Factories.Project.create_with_repo(%{
          organization_id: org_id
        })

      {:ok, project4} = Support.Factories.Project.create()
      {:ok, _project5} = Support.Factories.Project.create()

      # Project 3 should not be returned
      {:ok, _} = Project.soft_destroy(project3, %User{github_token: "token"})

      request =
        InternalApi.Projecthub.DescribeManyRequest.new(
          metadata:
            InternalApi.Projecthub.RequestMeta.new(
              api_version: "",
              kind: "",
              req_id: "",
              org_id: org_id,
              user_id: "12345678-1234-5678-1234-567812345678"
            ),
          ids: [project1.id, project2.id, project3.id, project4.id]
        )

      {:ok, response} = Stub.describe_many(channel, request)

      assert response.metadata ==
               InternalApi.Projecthub.ResponseMeta.new(
                 api_version: "",
                 kind: "",
                 req_id: "",
                 org_id: org_id,
                 user_id: "12345678-1234-5678-1234-567812345678",
                 status: InternalApi.Projecthub.ResponseMeta.Status.new(code: :OK)
               )

      assert Enum.count(response.projects) == 2

      names = Enum.map(response.projects, fn p -> p.metadata.name end)
      assert Enum.member?(names, project1.name)
      assert Enum.member?(names, project2.name)
    end

    test "it returns the soft_deleted projects when soft_deleted param is true" do
      {:ok, channel} =
        GRPC.Stub.connect("localhost:50051",
          interceptors: [
            Projecthub.Util.GRPC.ClientRequestIdInterceptor,
            Projecthub.Util.GRPC.ClientLoggerInterceptor,
            Projecthub.Util.GRPC.ClientRunAsyncInterceptor
          ]
        )

      org_id = Ecto.UUID.generate()

      {:ok, project1} =
        Support.Factories.Project.create_with_repo(%{
          organization_id: org_id
        })

      {:ok, project2} =
        Support.Factories.Project.create_with_repo(%{
          organization_id: org_id
        })

      # Not soft deleted
      {:ok, project3} =
        Support.Factories.Project.create_with_repo(%{
          organization_id: org_id
        })

      {:ok, project4} = Support.Factories.Project.create()
      {:ok, _project5} = Support.Factories.Project.create()

      {:ok, _} = Project.soft_destroy(project1, %User{github_token: "token"})
      {:ok, _} = Project.soft_destroy(project2, %User{github_token: "token"})

      request =
        InternalApi.Projecthub.DescribeManyRequest.new(
          metadata:
            InternalApi.Projecthub.RequestMeta.new(
              api_version: "",
              kind: "",
              req_id: "",
              org_id: org_id,
              user_id: "12345678-1234-5678-1234-567812345678"
            ),
          ids: [project1.id, project2.id, project3.id, project4.id],
          soft_deleted: true
        )

      {:ok, response} = Stub.describe_many(channel, request)

      assert response.metadata ==
               InternalApi.Projecthub.ResponseMeta.new(
                 api_version: "",
                 kind: "",
                 req_id: "",
                 org_id: org_id,
                 user_id: "12345678-1234-5678-1234-567812345678",
                 status: InternalApi.Projecthub.ResponseMeta.Status.new(code: :OK)
               )

      assert Enum.count(response.projects) == 2

      cut_timestamp = create_cut_timestamp()
      names = Enum.map(response.projects, fn p -> p.metadata.name end)
      assert Enum.any?(names, fn name -> name =~ "#{project1.name}-deleted-#{cut_timestamp}" end)
      assert Enum.any?(names, fn name -> name =~ "#{project2.name}-deleted-#{cut_timestamp}" end)
      assert Enum.all?(names, fn name -> name =~ "-deleted-#{cut_timestamp}" end)
    end

    test "when there are no projects => returns empty list" do
      {:ok, channel} =
        GRPC.Stub.connect("localhost:50051",
          interceptors: [
            Projecthub.Util.GRPC.ClientRequestIdInterceptor,
            Projecthub.Util.GRPC.ClientLoggerInterceptor,
            Projecthub.Util.GRPC.ClientRunAsyncInterceptor
          ]
        )

      request =
        InternalApi.Projecthub.DescribeManyRequest.new(
          metadata:
            InternalApi.Projecthub.RequestMeta.new(
              api_version: "",
              kind: "",
              req_id: "",
              org_id: Ecto.UUID.generate(),
              user_id: "12345678-1234-5678-1234-567812345678"
            ),
          ids: [Ecto.UUID.generate()]
        )

      {:ok, response} = Stub.describe_many(channel, request)

      assert response.metadata.status.code == :OK
      assert Enum.empty?(response.projects)
    end
  end

  describe ".list" do
    test "returns a paginated project list" do
      {:ok, channel} =
        GRPC.Stub.connect("localhost:50051",
          interceptors: [
            Projecthub.Util.GRPC.ClientRequestIdInterceptor,
            Projecthub.Util.GRPC.ClientLoggerInterceptor,
            Projecthub.Util.GRPC.ClientRunAsyncInterceptor
          ]
        )

      org_id = Ecto.UUID.generate()

      {:ok, _project1} =
        Support.Factories.Project.create_with_repo(%{
          organization_id: org_id
        })

      {:ok, _project2} =
        Support.Factories.Project.create_with_repo(%{
          organization_id: org_id
        })

      {:ok, _project3} =
        Support.Factories.Project.create_with_repo(%{
          organization_id: org_id
        })

      {:ok, _non_org_project} = Support.Factories.Project.create()

      request =
        InternalApi.Projecthub.ListRequest.new(
          metadata:
            InternalApi.Projecthub.RequestMeta.new(
              api_version: "",
              kind: "",
              req_id: "",
              org_id: org_id,
              user_id: "12345678-1234-5678-1234-567812345678"
            ),
          pagination:
            InternalApi.Projecthub.PaginationRequest.new(
              page: 1,
              page_size: 2
            )
        )

      {:ok, response} = Stub.list(channel, request)

      assert response.metadata.status.code == :OK

      assert response.pagination ==
               InternalApi.Projecthub.PaginationResponse.new(
                 page_number: 1,
                 page_size: 2,
                 total_entries: 3,
                 total_pages: 2
               )

      assert Enum.count(response.projects) == 2
    end

    test "returns a paginated project list of soft deleted projects" do
      {:ok, channel} =
        GRPC.Stub.connect("localhost:50051",
          interceptors: [
            Projecthub.Util.GRPC.ClientRequestIdInterceptor,
            Projecthub.Util.GRPC.ClientLoggerInterceptor,
            Projecthub.Util.GRPC.ClientRunAsyncInterceptor
          ]
        )

      org_id = Ecto.UUID.generate()

      {:ok, project1} =
        Support.Factories.Project.create_with_repo(%{
          organization_id: org_id
        })

      {:ok, project2} =
        Support.Factories.Project.create_with_repo(%{
          organization_id: org_id
        })

      {:ok, _project3} =
        Support.Factories.Project.create_with_repo(%{
          organization_id: org_id
        })

      {:ok, _non_org_project} = Support.Factories.Project.create()

      {:ok, _} = Project.soft_destroy(project1, %User{github_token: "token"})
      {:ok, _} = Project.soft_destroy(project2, %User{github_token: "token"})

      request =
        InternalApi.Projecthub.ListRequest.new(
          soft_deleted: true,
          metadata:
            InternalApi.Projecthub.RequestMeta.new(
              api_version: "",
              kind: "",
              req_id: "",
              org_id: org_id,
              user_id: "12345678-1234-5678-1234-567812345678"
            ),
          pagination:
            InternalApi.Projecthub.PaginationRequest.new(
              page: 1,
              page_size: 2
            )
        )

      {:ok, response} = Stub.list(channel, request)

      assert response.metadata.status.code == :OK

      assert response.pagination ==
               InternalApi.Projecthub.PaginationResponse.new(
                 page_number: 1,
                 page_size: 2,
                 total_entries: 2,
                 total_pages: 1
               )

      assert Enum.count(response.projects) == 2
    end

    test "returns a paginated project list filtered by repo url" do
      {:ok, channel} =
        GRPC.Stub.connect("localhost:50051",
          interceptors: [
            Projecthub.Util.GRPC.ClientRequestIdInterceptor,
            Projecthub.Util.GRPC.ClientLoggerInterceptor,
            Projecthub.Util.GRPC.ClientRunAsyncInterceptor
          ]
        )

      url = "git@github.com:myorg/projecthub.git"
      org_id = Ecto.UUID.generate()

      {:ok, _project1} =
        Support.Factories.Project.create_with_repo(
          %{
            organization_id: org_id
          },
          %{
            url: url
          }
        )

      {:ok, _project2} =
        Support.Factories.Project.create_with_repo(
          %{
            organization_id: org_id
          },
          %{
            url: url
          }
        )

      {:ok, _project3} =
        Support.Factories.Project.create_with_repo(%{
          organization_id: org_id
        })

      {:ok, _project4} =
        Support.Factories.Project.create_with_repo(%{}, %{
          url: url
        })

      request =
        InternalApi.Projecthub.ListRequest.new(
          metadata:
            InternalApi.Projecthub.RequestMeta.new(
              api_version: "",
              kind: "",
              req_id: "",
              org_id: org_id,
              user_id: "12345678-1234-5678-1234-567812345678"
            ),
          pagination:
            InternalApi.Projecthub.PaginationRequest.new(
              page: 1,
              page_size: 2
            ),
          repo_url: "git://github.com/myorg/projecthub.git"
        )

      {:ok, response} = Stub.list(channel, request)

      assert response.metadata.status.code == :OK

      assert response.pagination ==
               InternalApi.Projecthub.PaginationResponse.new(
                 page_number: 1,
                 page_size: 2,
                 total_entries: 2,
                 total_pages: 1
               )

      assert Enum.count(response.projects) == 2
    end

    test "returns precondition error when url is invalid" do
      {:ok, channel} =
        GRPC.Stub.connect("localhost:50051",
          interceptors: [
            Projecthub.Util.GRPC.ClientRequestIdInterceptor,
            Projecthub.Util.GRPC.ClientLoggerInterceptor,
            Projecthub.Util.GRPC.ClientRunAsyncInterceptor
          ]
        )

      url = "git@foo.com:myorg/projecthub.git"
      org_id = Ecto.UUID.generate()

      request =
        InternalApi.Projecthub.ListRequest.new(
          metadata:
            InternalApi.Projecthub.RequestMeta.new(
              api_version: "",
              kind: "",
              req_id: "",
              org_id: org_id,
              user_id: "12345678-1234-5678-1234-567812345678"
            ),
          pagination:
            InternalApi.Projecthub.PaginationRequest.new(
              page: 1,
              page_size: 2
            ),
          repo_url: url
        )

      {:ok, response} = Stub.list(channel, request)

      assert response.metadata.status.code ==
               :FAILED_PRECONDITION

      assert response.metadata.status.message ==
               "Repository host must be GitHub.com or Bitbucket.org"
    end

    test "returns a paginated project list filtered by owner" do
      {:ok, channel} =
        GRPC.Stub.connect("localhost:50051",
          interceptors: [
            Projecthub.Util.GRPC.ClientRequestIdInterceptor,
            Projecthub.Util.GRPC.ClientLoggerInterceptor,
            Projecthub.Util.GRPC.ClientRunAsyncInterceptor
          ]
        )

      owner_id = Ecto.UUID.generate()
      org_id = Ecto.UUID.generate()

      {:ok, _project1} =
        Support.Factories.Project.create_with_repo(%{
          organization_id: org_id,
          creator_id: owner_id
        })

      {:ok, _project2} =
        Support.Factories.Project.create_with_repo(%{
          organization_id: org_id,
          creator_id: owner_id
        })

      {:ok, _project3} =
        Support.Factories.Project.create_with_repo(%{
          organization_id: org_id
        })

      {:ok, _project4} =
        Support.Factories.Project.create_with_repo(%{
          organization_id: org_id,
          creator_id: owner_id
        })

      {:ok, _non_org_project} = Support.Factories.Project.create()

      request =
        InternalApi.Projecthub.ListRequest.new(
          metadata:
            InternalApi.Projecthub.RequestMeta.new(
              api_version: "",
              kind: "",
              req_id: "",
              org_id: org_id,
              user_id: "12345678-1234-5678-1234-567812345678"
            ),
          pagination:
            InternalApi.Projecthub.PaginationRequest.new(
              page: 1,
              page_size: 2
            ),
          owner_id: owner_id
        )

      {:ok, response} = Stub.list(channel, request)

      assert response.metadata.status.code == :OK

      assert response.pagination ==
               InternalApi.Projecthub.PaginationResponse.new(
                 page_number: 1,
                 page_size: 2,
                 total_entries: 3,
                 total_pages: 2
               )

      assert Enum.count(response.projects) == 2
    end

    test "whrn there are no projects => returns an empty projects list" do
      {:ok, channel} =
        GRPC.Stub.connect("localhost:50051",
          interceptors: [
            Projecthub.Util.GRPC.ClientRequestIdInterceptor,
            Projecthub.Util.GRPC.ClientLoggerInterceptor,
            Projecthub.Util.GRPC.ClientRunAsyncInterceptor
          ]
        )

      org_id = Ecto.UUID.generate()

      request =
        InternalApi.Projecthub.ListRequest.new(
          metadata:
            InternalApi.Projecthub.RequestMeta.new(
              api_version: "",
              kind: "",
              req_id: "",
              org_id: org_id,
              user_id: "12345678-1234-5678-1234-567812345678"
            ),
          pagination:
            InternalApi.Projecthub.PaginationRequest.new(
              page: 1,
              page_size: 2
            )
        )

      {:ok, response} = Stub.list(channel, request)

      assert response.metadata.status.code == :OK

      assert response.pagination ==
               InternalApi.Projecthub.PaginationResponse.new(
                 page_number: 1,
                 page_size: 2,
                 total_entries: 0,
                 total_pages: 1
               )

      assert Enum.empty?(response.projects)
    end
  end

  describe ".list_keyset" do
    test "returns a paginated project list" do
      {:ok, channel} =
        GRPC.Stub.connect("localhost:50051",
          interceptors: [
            Projecthub.Util.GRPC.ClientRequestIdInterceptor,
            Projecthub.Util.GRPC.ClientLoggerInterceptor,
            Projecthub.Util.GRPC.ClientRunAsyncInterceptor
          ]
        )

      org_id = Ecto.UUID.generate()

      {:ok, _project1} =
        Support.Factories.Project.create_with_repo(%{
          organization_id: org_id,
          name: "A"
        })

      {:ok, _project2} =
        Support.Factories.Project.create_with_repo(%{
          organization_id: org_id,
          name: "B"
        })

      {:ok, _project3} =
        Support.Factories.Project.create_with_repo(%{
          organization_id: org_id,
          name: "C"
        })

      {:ok, _project4} =
        Support.Factories.Project.create_with_repo(%{
          organization_id: org_id,
          name: "D"
        })

      {:ok, _non_org_project} = Support.Factories.Project.create()

      request =
        InternalApi.Projecthub.ListKeysetRequest.new(
          metadata:
            InternalApi.Projecthub.RequestMeta.new(
              api_version: "",
              kind: "",
              req_id: "",
              org_id: org_id,
              user_id: "12345678-1234-5678-1234-567812345678"
            ),
          page_token: "",
          page_size: 2
        )

      {:ok, response} = Stub.list_keyset(channel, request)

      assert response.metadata.status.code == :OK
      assert response.previous_page_token == ""

      # check if projects are sorted
      projects = Enum.map(response.projects, fn p -> p.metadata.name end)
      assert projects == ["A", "B"]

      # now fetch 2nd page
      request = %{request | page_token: response.next_page_token}
      {:ok, response} = Stub.list_keyset(channel, request)

      assert response.metadata.status.code == :OK
      assert response.next_page_token == ""

      # check if next page of projects is returned
      projects = Enum.map(response.projects, fn p -> p.metadata.name end)
      assert projects == ["C", "D"]
    end

    test "returns a paginated project list created after" do
      {:ok, channel} =
        GRPC.Stub.connect("localhost:50051",
          interceptors: [
            Projecthub.Util.GRPC.ClientRequestIdInterceptor,
            Projecthub.Util.GRPC.ClientLoggerInterceptor,
            Projecthub.Util.GRPC.ClientRunAsyncInterceptor
          ]
        )

      org_id = "12345678-1234-5678-1234-010101010101"

      {:ok, _project1} =
        Support.Factories.Project.create_with_repo(%{
          organization_id: org_id,
          name: "A"
        })

      {:ok, _project2} =
        Support.Factories.Project.create_with_repo(%{
          organization_id: org_id,
          name: "B"
        })

      {:ok, project3} =
        Support.Factories.Project.create_with_repo(%{
          organization_id: org_id,
          name: "C"
        })

      {:ok, _project4} =
        Support.Factories.Project.create_with_repo(%{
          organization_id: org_id,
          name: "D"
        })

      {:ok, _project5} =
        Support.Factories.Project.create_with_repo(%{
          organization_id: "12345678-1234-5678-1234-567812345678",
          name: "E"
        })

      now = project3.created_at
      one_hour_ago = Timex.shift(now, hours: -1)
      one_minute_ago = Timex.shift(now, minutes: -1)
      {:ok, _} = Support.Factories.Project.move_in_time(project3, one_hour_ago)

      request =
        InternalApi.Projecthub.ListKeysetRequest.new(
          metadata:
            InternalApi.Projecthub.RequestMeta.new(
              api_version: "",
              kind: "",
              req_id: "",
              org_id: "",
              user_id: "12345678-1234-5678-1234-567812345678"
            ),
          page_token: "",
          page_size: 2,
          created_after: Google.Protobuf.Timestamp.new(seconds: DateTime.to_unix(one_minute_ago))
        )

      {:ok, response} = Stub.list_keyset(channel, request)

      assert response.metadata.status.code == :OK
      assert response.previous_page_token == ""

      # check if projects are sorted
      projects = Enum.map(response.projects, fn p -> p.metadata.name end)
      assert projects == ["A", "B"]

      # now fetch 2nd page
      request = %{request | page_token: response.next_page_token}
      {:ok, response} = Stub.list_keyset(channel, request)

      assert response.metadata.status.code == :OK
      assert response.next_page_token == ""

      # check if next page of projects is returned
      projects = Enum.map(response.projects, fn p -> p.metadata.name end)
      assert projects == ["D", "E"]
    end

    test "returns a paginated project list filtered by repo url" do
      {:ok, channel} =
        GRPC.Stub.connect("localhost:50051",
          interceptors: [
            Projecthub.Util.GRPC.ClientRequestIdInterceptor,
            Projecthub.Util.GRPC.ClientLoggerInterceptor,
            Projecthub.Util.GRPC.ClientRunAsyncInterceptor
          ]
        )

      url = "git@github.com:myorg/projecthub.git"
      org_id = Ecto.UUID.generate()

      {:ok, _project1} =
        Support.Factories.Project.create_with_repo(
          %{
            organization_id: org_id
          },
          %{
            url: url
          }
        )

      {:ok, _project2} =
        Support.Factories.Project.create_with_repo(
          %{
            organization_id: org_id
          },
          %{
            url: url
          }
        )

      {:ok, _project3} =
        Support.Factories.Project.create_with_repo(%{
          organization_id: org_id
        })

      {:ok, _project4} =
        Support.Factories.Project.create_with_repo(%{}, %{
          url: url
        })

      request =
        InternalApi.Projecthub.ListKeysetRequest.new(
          metadata:
            InternalApi.Projecthub.RequestMeta.new(
              api_version: "",
              kind: "",
              req_id: "",
              org_id: org_id,
              user_id: "12345678-1234-5678-1234-567812345678"
            ),
          page_cursor: "",
          page_size: 2,
          repo_url: "git://github.com/myorg/projecthub.git"
        )

      {:ok, response} = Stub.list_keyset(channel, request)

      assert response.metadata.status.code == :OK

      assert Enum.count(response.projects) == 2
    end

    test "returns precondition error when url is invalid" do
      {:ok, channel} =
        GRPC.Stub.connect("localhost:50051",
          interceptors: [
            Projecthub.Util.GRPC.ClientRequestIdInterceptor,
            Projecthub.Util.GRPC.ClientLoggerInterceptor,
            Projecthub.Util.GRPC.ClientRunAsyncInterceptor
          ]
        )

      url = "git@foo.com:myorg/projecthub.git"
      org_id = Ecto.UUID.generate()

      request =
        InternalApi.Projecthub.ListKeysetRequest.new(
          metadata:
            InternalApi.Projecthub.RequestMeta.new(
              api_version: "",
              kind: "",
              req_id: "",
              org_id: org_id,
              user_id: "12345678-1234-5678-1234-567812345678"
            ),
          page_cursor: "",
          page_size: 2,
          repo_url: url
        )

      {:ok, response} = Stub.list_keyset(channel, request)

      assert response.metadata.status.code ==
               :FAILED_PRECONDITION

      assert response.metadata.status.message ==
               "Repository host must be GitHub.com or Bitbucket.org"
    end

    test "returns a paginated project list filtered by owner" do
      {:ok, channel} =
        GRPC.Stub.connect("localhost:50051",
          interceptors: [
            Projecthub.Util.GRPC.ClientRequestIdInterceptor,
            Projecthub.Util.GRPC.ClientLoggerInterceptor,
            Projecthub.Util.GRPC.ClientRunAsyncInterceptor
          ]
        )

      owner_id = Ecto.UUID.generate()
      org_id = Ecto.UUID.generate()

      {:ok, _project1} =
        Support.Factories.Project.create_with_repo(%{
          organization_id: org_id,
          creator_id: owner_id
        })

      {:ok, _project2} =
        Support.Factories.Project.create_with_repo(%{
          organization_id: org_id,
          creator_id: owner_id
        })

      {:ok, _project3} =
        Support.Factories.Project.create_with_repo(%{
          organization_id: org_id
        })

      {:ok, _project4} =
        Support.Factories.Project.create_with_repo(%{
          organization_id: org_id,
          creator_id: owner_id
        })

      {:ok, _non_org_project} = Support.Factories.Project.create()

      request =
        InternalApi.Projecthub.ListKeysetRequest.new(
          metadata:
            InternalApi.Projecthub.RequestMeta.new(
              api_version: "",
              kind: "",
              req_id: "",
              org_id: org_id,
              user_id: "12345678-1234-5678-1234-567812345678"
            ),
          page_cursor: "",
          page_size: 2,
          owner_id: owner_id
        )

      {:ok, response} = Stub.list_keyset(channel, request)

      assert response.metadata.status.code == :OK

      assert Enum.count(response.projects) == 2
    end

    test "when there are projects in onboarding state => they are included" do
      {:ok, channel} =
        GRPC.Stub.connect("localhost:50051",
          interceptors: [
            Projecthub.Util.GRPC.ClientRequestIdInterceptor,
            Projecthub.Util.GRPC.ClientLoggerInterceptor,
            Projecthub.Util.GRPC.ClientRunAsyncInterceptor
          ]
        )

      owner_id = Ecto.UUID.generate()
      org_id = Ecto.UUID.generate()

      {:ok, _project1} =
        Support.Factories.Project.create_with_repo(%{
          organization_id: org_id,
          creator_id: owner_id
        })

      {:ok, _project2} =
        Support.Factories.Project.create_with_repo(%{
          organization_id: org_id,
          creator_id: owner_id,
          state: Projecthub.Models.Project.StateMachine.onboarding()
        })

      {:ok, _non_org_project} = Support.Factories.Project.create()

      request =
        InternalApi.Projecthub.ListKeysetRequest.new(
          metadata:
            InternalApi.Projecthub.RequestMeta.new(
              api_version: "",
              kind: "",
              req_id: "",
              org_id: org_id,
              user_id: "12345678-1234-5678-1234-567812345678"
            ),
          page_cursor: "",
          page_size: 2,
          owner_id: owner_id
        )

      {:ok, response} = Stub.list_keyset(channel, request)

      assert response.metadata.status.code == :OK

      assert Enum.count(response.projects) == 2
      assert Enum.any?(response.projects, fn p -> p.status.state == :ONBOARDING end)
    end

    test "whrn there are no projects => returns an empty projects list" do
      {:ok, channel} =
        GRPC.Stub.connect("localhost:50051",
          interceptors: [
            Projecthub.Util.GRPC.ClientRequestIdInterceptor,
            Projecthub.Util.GRPC.ClientLoggerInterceptor,
            Projecthub.Util.GRPC.ClientRunAsyncInterceptor
          ]
        )

      org_id = Ecto.UUID.generate()

      request =
        InternalApi.Projecthub.ListKeysetRequest.new(
          metadata:
            InternalApi.Projecthub.RequestMeta.new(
              api_version: "",
              kind: "",
              req_id: "",
              org_id: org_id,
              user_id: "12345678-1234-5678-1234-567812345678"
            ),
          page_cursor: "",
          page_size: 2
        )

      {:ok, response} = Stub.list_keyset(channel, request)

      assert response.metadata.status.code == :OK

      assert response.next_page_token == ""

      assert Enum.empty?(response.projects)
    end
  end

  describe ".finish_onboarding" do
    test "when the project is in onboarding state => finishes the onboarding" do
      {:ok, project} =
        Support.Factories.Project.create_with_repo(%{state: Projecthub.Models.Project.StateMachine.onboarding()})

      {:ok, channel} =
        GRPC.Stub.connect("localhost:50051",
          interceptors: [
            Projecthub.Util.GRPC.ClientRequestIdInterceptor,
            Projecthub.Util.GRPC.ClientLoggerInterceptor,
            Projecthub.Util.GRPC.ClientRunAsyncInterceptor
          ]
        )

      request =
        InternalApi.Projecthub.FinishOnboardingRequest.new(
          metadata:
            InternalApi.Projecthub.RequestMeta.new(
              api_version: "",
              kind: "",
              req_id: "",
              org_id: project.organization_id,
              user_id: "12345678-1234-5678-1234-567812345678"
            ),
          id: project.id
        )

      {:ok, response} = Stub.finish_onboarding(channel, request)

      assert response.metadata.status.code == :OK

      {:ok, project} = Projecthub.Models.Project.find(project.id)
      assert project.state == Projecthub.Models.Project.StateMachine.ready()
    end

    test "when the project is in ready state => noop and ok response" do
      {:ok, project} =
        Support.Factories.Project.create_with_repo(%{state: Projecthub.Models.Project.StateMachine.ready()})

      {:ok, channel} =
        GRPC.Stub.connect("localhost:50051",
          interceptors: [
            Projecthub.Util.GRPC.ClientRequestIdInterceptor,
            Projecthub.Util.GRPC.ClientLoggerInterceptor,
            Projecthub.Util.GRPC.ClientRunAsyncInterceptor
          ]
        )

      request =
        InternalApi.Projecthub.FinishOnboardingRequest.new(
          metadata:
            InternalApi.Projecthub.RequestMeta.new(
              api_version: "",
              kind: "",
              req_id: "",
              org_id: project.organization_id,
              user_id: "12345678-1234-5678-1234-567812345678"
            ),
          id: project.id
        )

      {:ok, response} = Stub.finish_onboarding(channel, request)

      assert response.metadata.status.code == :OK

      {:ok, project} = Projecthub.Models.Project.find(project.id)
      assert project.state == Projecthub.Models.Project.StateMachine.ready()
    end
  end

  describe ".change_project_owner" do
    # TODO
  end

  describe ".regenerate_deploy_key" do
    # TODO
  end

  describe ".check_deploy_key" do
    # TODO
  end

  describe ".check_webhook" do
    # TODO
  end

  describe ".regenerate_webhook" do
    # TODO
  end

  describe ".create" do
    def create_request(name: name, org_id: org_id, request_id: request_id) do
      InternalApi.Projecthub.CreateRequest.new(
        metadata:
          InternalApi.Projecthub.RequestMeta.new(
            api_version: "",
            kind: "",
            req_id: request_id,
            org_id: org_id,
            user_id: "12345678-1234-5678-1234-567812345678"
          ),
        project:
          InternalApi.Projecthub.Project.new(
            metadata:
              InternalApi.Projecthub.Project.Metadata.new(
                name: name,
                id: "12345678-1234-5678-1234-567812345678",
                owner_id: "12345678-1234-5678-1234-567812345678",
                org_id: org_id,
                description: "A repo for testing SemaphoreCI features"
              ),
            spec:
              InternalApi.Projecthub.Project.Spec.new(
                repository:
                  InternalApi.Projecthub.Project.Spec.Repository.new(
                    url: "repo_url",
                    name: "repo_name",
                    owner: "repo_owner"
                  )
              )
          )
      )
    end

    test "when there are errors with the repo => returns a failed precondition, project is removed" do
      {:ok, channel} =
        GRPC.Stub.connect("localhost:50051",
          interceptors: [
            Projecthub.Util.GRPC.ClientRequestIdInterceptor,
            Projecthub.Util.GRPC.ClientLoggerInterceptor,
            Projecthub.Util.GRPC.ClientRunAsyncInterceptor
          ]
        )

      request =
        create_request(
          name: "organization",
          org_id: Ecto.UUID.generate(),
          request_id: Ecto.UUID.generate()
        )

      with_mock Projecthub.Models.Repository, [:passthrough], create: fn _ -> {:error, "Some error"} end do
        {:ok, response} = Stub.create(channel, request)

        assert response.metadata.status ==
                 InternalApi.Projecthub.ResponseMeta.Status.new(
                   code: :FAILED_PRECONDITION,
                   message: "Some error"
                 )

        assert Repo.aggregate(Project, :count, :id) == 0
      end
    end

    test "when the org already has a project with the same name => returns a failed precondition" do
      org_id = Ecto.UUID.generate()

      {:ok, _project} =
        Support.Factories.Project.create(%{
          organization_id: org_id,
          name: "some_project"
        })

      request = create_request(name: "some_project", org_id: org_id, request_id: Ecto.UUID.generate())

      assert Repo.aggregate(Project, :count, :id) == 1

      response = GrpcServer.create(request, nil)

      assert response.metadata.status ==
               InternalApi.Projecthub.ResponseMeta.Status.new(
                 code: InternalApi.Projecthub.ResponseMeta.Code.value(:FAILED_PRECONDITION),
                 message: "Project name 'some_project' is already taken"
               )

      assert Repo.aggregate(Project, :count, :id) == 1
    end

    test "when the org hits the quota limit for number of projects => returns a failed precondition" do
      org_id = Ecto.UUID.generate()

      Enum.each(1..8, fn _ ->
        Support.Factories.Project.create_with_repo(%{
          organization_id: org_id
        })
      end)

      {:ok, project} = Support.Factories.Project.create_with_repo(%{organization_id: org_id})

      request1 =
        create_request(
          name: "some_other_project",
          org_id: org_id,
          request_id: Ecto.UUID.generate()
        )

      request2 =
        create_request(
          name: "some_other_project_2",
          org_id: org_id,
          request_id: Ecto.UUID.generate()
        )

      with_mocks([
        {Project, [:passthrough], [create: fn _a, _u, _o, _p, _r, _i, _s -> {:ok, project} end]}
      ]) do
        assert Repo.aggregate(Project, :count, :id) == 9

        response = GrpcServer.create(request1, nil)

        assert response.metadata.status ==
                 InternalApi.Projecthub.ResponseMeta.Status.new(
                   code: InternalApi.Projecthub.ResponseMeta.Code.value(:OK),
                   message: ""
                 )

        {:ok, _project} = Support.Factories.Project.create_with_repo(%{organization_id: org_id})
        response = GrpcServer.create(request2, nil)

        assert response.metadata.status ==
                 InternalApi.Projecthub.ResponseMeta.Status.new(
                   code: InternalApi.Projecthub.ResponseMeta.Code.value(:FAILED_PRECONDITION),
                   message:
                     "The organization has reached a maximum number of projects. To increase the quota, please contact support"
                 )

        assert Repo.aggregate(Project, :count, :id) == 10
      end
    end

    test "when the org is open source => creates public project" do
      {:ok, channel} =
        GRPC.Stub.connect("localhost:50051",
          interceptors: [
            Projecthub.Util.GRPC.ClientRequestIdInterceptor,
            Projecthub.Util.GRPC.ClientLoggerInterceptor,
            Projecthub.Util.GRPC.ClientRunAsyncInterceptor
          ]
        )

      org_id = Ecto.UUID.generate()

      org_response =
        InternalApi.Organization.DescribeResponse.new(
          status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
          organization:
            InternalApi.Organization.Organization.new(
              org_username: "organization",
              org_id: org_id,
              open_source: true
            )
        )

      FunRegistry.set!(Support.FakeServices.OrganizationService, :describe, org_response)
      FunRegistry.set!(Support.FakeServices.FeatureService, :organization_features, org_response)

      request =
        InternalApi.Projecthub.CreateRequest.new(
          metadata:
            InternalApi.Projecthub.RequestMeta.new(
              api_version: "",
              kind: "",
              req_id: "",
              org_id: org_id,
              user_id: "12345678-1234-5678-1234-567812345678"
            ),
          project:
            InternalApi.Projecthub.Project.new(
              metadata:
                InternalApi.Projecthub.Project.Metadata.new(
                  name: "organization",
                  id: "12345678-1234-5678-1234-567812345678",
                  owner_id: "12345678-1234-5678-1234-567812345678",
                  org_id: org_id,
                  description: "A repo for testing SemaphoreCI features"
                ),
              spec:
                InternalApi.Projecthub.Project.Spec.new(
                  repository:
                    InternalApi.Projecthub.Project.Spec.Repository.new(
                      url: "repo_url",
                      name: "repo_name",
                      owner: "repo_owner"
                    ),
                  visibility: :PRIVATE
                )
            )
        )

      {:ok, response} = Stub.create(channel, request)

      assert response.metadata.status ==
               InternalApi.Projecthub.ResponseMeta.Status.new(code: :OK)

      assert response.project.spec.visibility == :PUBLIC
    end

    test "when everything is in order with request => creates the project and returns ok" do
      {:ok, channel} =
        GRPC.Stub.connect("localhost:50051",
          interceptors: [
            Projecthub.Util.GRPC.ClientRequestIdInterceptor,
            Projecthub.Util.GRPC.ClientLoggerInterceptor,
            Projecthub.Util.GRPC.ClientRunAsyncInterceptor
          ]
        )

      org_id = Ecto.UUID.generate()

      org_response =
        InternalApi.Organization.DescribeResponse.new(
          status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
          organization:
            InternalApi.Organization.Organization.new(
              org_username: "organization",
              org_id: org_id
            )
        )

      FunRegistry.set!(Support.FakeServices.OrganizationService, :describe, org_response)

      FunRegistry.set!(Support.FakeServices.FeatureService, :organization_features, org_response)

      request =
        InternalApi.Projecthub.CreateRequest.new(
          metadata:
            InternalApi.Projecthub.RequestMeta.new(
              api_version: "",
              kind: "",
              req_id: "",
              org_id: org_id,
              user_id: "12345678-1234-5678-1234-567812345678"
            ),
          project:
            InternalApi.Projecthub.Project.new(
              metadata:
                InternalApi.Projecthub.Project.Metadata.new(
                  name: "organization",
                  id: "12345678-1234-5678-1234-567812345678",
                  owner_id: "12345678-1234-5678-1234-567812345678",
                  org_id: org_id,
                  description: "A repo for testing SemaphoreCI features"
                ),
              spec:
                InternalApi.Projecthub.Project.Spec.new(
                  repository:
                    InternalApi.Projecthub.Project.Spec.Repository.new(
                      url: "repo_url",
                      name: "repo_name",
                      owner: "repo_owner"
                    )
                )
            )
        )

      {:ok, response} = Stub.create(channel, request)

      assert response.metadata.status ==
               InternalApi.Projecthub.ResponseMeta.Status.new(code: :OK)

      assert response.project
      {:ok, project} = Projecthub.Models.Project.find(response.project.metadata.id)
      assert project.state == Projecthub.Models.Project.StateMachine.initializing_skip()
    end

    test "when creating fails with specific error message => returns the error message" do
      {:ok, channel} =
        GRPC.Stub.connect("localhost:50051",
          interceptors: [
            Projecthub.Util.GRPC.ClientRequestIdInterceptor,
            Projecthub.Util.GRPC.ClientLoggerInterceptor,
            Projecthub.Util.GRPC.ClientRunAsyncInterceptor
          ]
        )

      org_id = Ecto.UUID.generate()

      org_response =
        InternalApi.Organization.DescribeResponse.new(
          status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
          organization:
            InternalApi.Organization.Organization.new(
              org_username: "organization",
              org_id: org_id
            )
        )

      FunRegistry.set!(Support.FakeServices.OrganizationService, :describe, org_response)

      request =
        InternalApi.Projecthub.CreateRequest.new(
          metadata:
            InternalApi.Projecthub.RequestMeta.new(
              api_version: "",
              kind: "",
              req_id: "",
              org_id: org_id,
              user_id: "12345678-1234-5678-1234-567812345678"
            ),
          project:
            InternalApi.Projecthub.Project.new(
              metadata:
                InternalApi.Projecthub.Project.Metadata.new(
                  name: "organization",
                  id: "12345678-1234-5678-1234-567812345678",
                  owner_id: "12345678-1234-5678-1234-567812345678",
                  org_id: org_id,
                  description: "A repo for testing SemaphoreCI features"
                ),
              spec:
                InternalApi.Projecthub.Project.Spec.new(
                  repository:
                    InternalApi.Projecthub.Project.Spec.Repository.new(
                      url: "repo_url",
                      name: "repo_name",
                      owner: "repo_owner"
                    ),
                  public: true
                )
            )
        )

      {:ok, project} = Support.Factories.Project.create()

      {:ok, _} =
        Support.Factories.Repository.create(%{
          project_id: project.id
        })

      with_mocks([
        {Project, [:passthrough], [create: fn _a, _u, _o, _p, _r, _i, _s -> {:error, "Custom error message"} end]}
      ]) do
        {:ok, response} = Stub.create(channel, request)

        assert response.metadata.status ==
                 InternalApi.Projecthub.ResponseMeta.Status.new(
                   code: :FAILED_PRECONDITION,
                   message: "Custom error message"
                 )
      end
    end

    test "when project with the same request_id already exists => returns that project" do
      request_id = Ecto.UUID.generate()

      request = create_request(name: "organization", org_id: Ecto.UUID.generate(), request_id: request_id)

      {:ok, _project} = Support.Factories.Project.create_with_repo(%{request_id: request_id})

      response = GrpcServer.create(request, nil)

      assert response.metadata.status ==
               InternalApi.Projecthub.ResponseMeta.Status.new(
                 code: InternalApi.Projecthub.ResponseMeta.Code.value(:OK),
                 message: ""
               )

      assert response.project
    end

    test "when the new_project_onboarding is enabled, skip_onboarding is false, initial project state is initializing" do
      {:ok, channel} =
        GRPC.Stub.connect("localhost:50051",
          interceptors: [
            Projecthub.Util.GRPC.ClientRequestIdInterceptor,
            Projecthub.Util.GRPC.ClientLoggerInterceptor,
            Projecthub.Util.GRPC.ClientRunAsyncInterceptor
          ]
        )

      org_id = Ecto.UUID.generate()

      org_response =
        InternalApi.Organization.DescribeResponse.new(
          status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
          organization:
            InternalApi.Organization.Organization.new(
              org_username: "organization",
              org_id: org_id
            )
        )

      FunRegistry.set!(Support.FakeServices.OrganizationService, :describe, org_response)

      FunRegistry.set!(Support.FakeServices.FeatureService, :organization_features, org_response)

      FunRegistry.set!(Support.FakeServices.FeatureService, :list_organization_features, fn _req, _ ->
        availability = InternalApi.Feature.Availability.new(state: :ENABLED, quantity: 10)

        InternalApi.Feature.ListOrganizationFeaturesResponse.new(
          organization_features: [
            [feature: %{type: "max_projects_in_org"}, availability: availability],
            [feature: %{type: "new_project_onboarding"}, availability: availability]
          ]
        )
      end)

      request = create_request(name: "organization", org_id: org_id, request_id: Ecto.UUID.generate())

      {:ok, response} = Stub.create(channel, request)

      assert response.metadata.status ==
               InternalApi.Projecthub.ResponseMeta.Status.new(code: :OK)

      {:ok, project} = Projecthub.Models.Project.find(response.project.metadata.id)
      assert project.state == Projecthub.Models.Project.StateMachine.initializing()
    end
  end

  describe ".update" do
    test "updates the project and returns it" do
      {:ok, channel} =
        GRPC.Stub.connect("localhost:50051",
          interceptors: [
            Projecthub.Util.GRPC.ClientRequestIdInterceptor,
            Projecthub.Util.GRPC.ClientLoggerInterceptor,
            Projecthub.Util.GRPC.ClientRunAsyncInterceptor
          ]
        )

      {:ok, project} = Support.Factories.Project.create_with_repo()

      project_params =
        InternalApi.Projecthub.Project.Metadata.new(
          name: "organization",
          id: project.id,
          owner_id: project.creator_id,
          org_id: project.organization_id,
          description: "A repo for testing SemaphoreCI features"
        )

      request =
        InternalApi.Projecthub.UpdateRequest.new(
          metadata:
            InternalApi.Projecthub.RequestMeta.new(
              api_version: "",
              kind: "",
              req_id: "",
              org_id: project.organization_id,
              user_id: "12345678-1234-5678-1234-567812345678"
            ),
          project:
            InternalApi.Projecthub.Project.new(
              metadata: project_params,
              spec:
                InternalApi.Projecthub.Project.Spec.new(
                  repository:
                    InternalApi.Projecthub.Project.Spec.Repository.new(
                      url: "git@github.com:myorg/hello-world.git",
                      forked_pull_requests:
                        InternalApi.Projecthub.Project.Spec.Repository.ForkedPullRequests.new(
                          allowed_secrets: ["aws-secret"]
                        ),
                      run_on: [:BRANCHES, :PULL_REQUESTS],
                      owner: "",
                      pipeline_file: ".semaphore/b.yml",
                      status:
                        InternalApi.Projecthub.Project.Spec.Repository.Status.new(
                          pipeline_files: [
                            InternalApi.Projecthub.Project.Spec.Repository.Status.PipelineFile.new(
                              path: ".semaphore/b.yml",
                              level: :BLOCK
                            )
                          ]
                        ),
                      whitelist:
                        InternalApi.Projecthub.Project.Spec.Repository.Whitelist.new(
                          branches: ["master", "/feature-*/"],
                          tags: []
                        ),
                      connected: true
                    ),
                  schedulers: [],
                  visibility: :PUBLIC,
                  custom_permissions: false,
                  debug_permissions: [:DEFAULT_BRANCH],
                  attach_permissions: []
                )
            )
        )

      {:ok, response} = Stub.update(channel, request)

      assert response.metadata.status ==
               InternalApi.Projecthub.ResponseMeta.Status.new(code: :OK)

      assert response.project.metadata.name == "organization"
      assert response.project.metadata.id == project.id
      assert response.project.metadata.owner_id == project.creator_id
      assert response.project.metadata.org_id == project.organization_id
      assert response.project.metadata.description == "A repo for testing SemaphoreCI features"
      assert response.project.spec.public == true

      assert response.project.spec.visibility == :PUBLIC

      assert response.project.spec.custom_permissions == false
      assert response.project.spec.debug_permissions == []

      assert response.project.spec.attach_permissions == []
    end

    test "when allowed_secrets are ommited => set default empty value" do
      {:ok, channel} =
        GRPC.Stub.connect("localhost:50051",
          interceptors: [
            Projecthub.Util.GRPC.ClientRequestIdInterceptor,
            Projecthub.Util.GRPC.ClientLoggerInterceptor,
            Projecthub.Util.GRPC.ClientRunAsyncInterceptor
          ]
        )

      {:ok, project} = Support.Factories.Project.create_with_repo()

      project_metadata =
        InternalApi.Projecthub.Project.Metadata.new(
          name: "organization",
          id: project.id,
          owner_id: project.creator_id,
          org_id: project.organization_id,
          description: "A repo for testing SemaphoreCI features"
        )

      request =
        InternalApi.Projecthub.UpdateRequest.new(
          metadata:
            InternalApi.Projecthub.RequestMeta.new(
              api_version: "",
              kind: "",
              req_id: "",
              org_id: project.organization_id,
              user_id: "12345678-1234-5678-1234-567812345678"
            ),
          project:
            InternalApi.Projecthub.Project.new(
              metadata: project_metadata,
              spec:
                InternalApi.Projecthub.Project.Spec.new(
                  repository:
                    InternalApi.Projecthub.Project.Spec.Repository.new(url: "git@github.com:myorg/hello-world.git"),
                  schedulers: []
                )
            )
        )

      with_mock Projecthub.Models.Repository, [:passthrough], update: fn repository, _params -> {:ok, repository} end do
        {:ok, response} = Stub.update(channel, request)

        assert response.metadata.status ==
                 InternalApi.Projecthub.ResponseMeta.Status.new(code: :OK)

        assert response.project.spec.public == false
        assert_called(Projecthub.Models.Repository.update(project.repository, %{}))
      end
    end

    test "when the project can't be found => returns not found" do
      {:ok, channel} =
        GRPC.Stub.connect("localhost:50051",
          interceptors: [
            Projecthub.Util.GRPC.ClientRequestIdInterceptor,
            Projecthub.Util.GRPC.ClientLoggerInterceptor,
            Projecthub.Util.GRPC.ClientRunAsyncInterceptor
          ]
        )

      project_id = Ecto.UUID.generate()

      request =
        InternalApi.Projecthub.UpdateRequest.new(
          metadata:
            InternalApi.Projecthub.RequestMeta.new(
              api_version: "",
              kind: "",
              req_id: "",
              org_id: "12345678-1234-5678-1234-567812345678",
              user_id: "12345678-1234-5678-1234-567812345678"
            ),
          project:
            InternalApi.Projecthub.Project.new(
              metadata:
                InternalApi.Projecthub.Project.Metadata.new(
                  name: "organization",
                  id: project_id,
                  owner_id: "12345678-1234-5678-1234-567812345678",
                  org_id: "12345678-1234-5678-1234-567812345678",
                  description: "A repo for testing SemaphoreCI features"
                ),
              spec:
                InternalApi.Projecthub.Project.Spec.new(
                  repository:
                    InternalApi.Projecthub.Project.Spec.Repository.new(
                      url: "repo_url",
                      name: "repo_name",
                      owner: "repo_owner"
                    )
                )
            )
        )

      {:ok, response} = Stub.update(channel, request)

      assert response.metadata.status ==
               InternalApi.Projecthub.ResponseMeta.Status.new(
                 code: :NOT_FOUND,
                 message: "project #{project_id} not found"
               )
    end

    test "when the project update fails because of invalid params => returns an error response" do
      {:ok, channel} =
        GRPC.Stub.connect("localhost:50051",
          interceptors: [
            Projecthub.Util.GRPC.ClientRequestIdInterceptor,
            Projecthub.Util.GRPC.ClientLoggerInterceptor,
            Projecthub.Util.GRPC.ClientRunAsyncInterceptor
          ]
        )

      {:ok, project} = Support.Factories.Project.create()

      project_metadata =
        InternalApi.Projecthub.Project.Metadata.new(
          name: "organization",
          id: project.id,
          owner_id: project.creator_id,
          org_id: project.organization_id,
          description: "A repo for testing SemaphoreCI features"
        )

      request =
        InternalApi.Projecthub.UpdateRequest.new(
          metadata:
            InternalApi.Projecthub.RequestMeta.new(
              api_version: "",
              kind: "",
              req_id: "",
              org_id: project.organization_id,
              user_id: "12345678-1234-5678-1234-567812345678"
            ),
          project:
            InternalApi.Projecthub.Project.new(
              metadata: project_metadata,
              spec:
                InternalApi.Projecthub.Project.Spec.new(
                  repository:
                    InternalApi.Projecthub.Project.Spec.Repository.new(
                      url: "repo_url",
                      name: "repo_name",
                      owner: "repo_owner",
                      run_on: [:PULL_REQUESTS]
                    ),
                  schedulers: []
                )
            )
        )

      _project_params = %{
        allowed_secrets: "",
        build_branch: false,
        build_forked_pr: false,
        build_pr: true,
        build_tag: false,
        description: project_metadata.description,
        name: project_metadata.name
      }

      with_mock ParamsChecker, run: fn _spec, _os -> {:error, ["message1", "message2"]} end do
        {:ok, response} = Stub.update(channel, request)

        assert_called(ParamsChecker.run(request.project.spec, false))

        assert response.metadata.status ==
                 InternalApi.Projecthub.ResponseMeta.Status.new(
                   code: :FAILED_PRECONDITION,
                   message: "message1, message2"
                 )
      end
    end

    test "when the project update fails for some reason => returns an error response" do
      {:ok, channel} =
        GRPC.Stub.connect("localhost:50051",
          interceptors: [
            Projecthub.Util.GRPC.ClientRequestIdInterceptor,
            Projecthub.Util.GRPC.ClientLoggerInterceptor,
            Projecthub.Util.GRPC.ClientRunAsyncInterceptor
          ]
        )

      {:ok, project} = Support.Factories.Project.create()

      project_metadata =
        InternalApi.Projecthub.Project.Metadata.new(
          name: "organization",
          id: project.id,
          owner_id: project.creator_id,
          org_id: project.organization_id,
          description: "A repo for testing SemaphoreCI features"
        )

      request =
        InternalApi.Projecthub.UpdateRequest.new(
          metadata:
            InternalApi.Projecthub.RequestMeta.new(
              api_version: "",
              kind: "",
              req_id: "",
              org_id: project.organization_id,
              user_id: "12345678-1234-5678-1234-567812345678"
            ),
          project:
            InternalApi.Projecthub.Project.new(
              metadata: project_metadata,
              spec:
                InternalApi.Projecthub.Project.Spec.new(
                  repository:
                    InternalApi.Projecthub.Project.Spec.Repository.new(
                      url: "repo_url",
                      name: "repo_name",
                      owner: "repo_owner",
                      run_on: [
                        InternalApi.Projecthub.Project.Spec.Repository.RunType.value(:PULL_REQUESTS)
                      ]
                    ),
                  schedulers: []
                )
            )
        )

      project_params = %{
        allowed_secrets: "",
        build_branch: false,
        build_forked_pr: false,
        build_pr: true,
        build_tag: false,
        description: project_metadata.description,
        name: project_metadata.name
      }

      with_mock Project, [:passthrough], update: fn _p, _pp, _r, _s, _t, _req, _omit -> {:error, ["oops"]} end do
        {:ok, response} = Stub.update(channel, request)

        repo_params = %{
          url: request.project.spec.repository.url,
          name: request.project.spec.repository.name,
          owner: request.project.spec.repository.owner
        }

        assert_called(
          Project.update(project, project_params, repo_params, [], [], "12345678-1234-5678-1234-567812345678", false)
        )

        assert response.metadata.status ==
                 InternalApi.Projecthub.ResponseMeta.Status.new(
                   code: :FAILED_PRECONDITION,
                   message: "oops"
                 )
      end
    end
  end

  describe ".destroy" do
    test "destroys the project" do
      {:ok, channel} =
        GRPC.Stub.connect("localhost:50051",
          interceptors: [
            Projecthub.Util.GRPC.ClientRequestIdInterceptor,
            Projecthub.Util.GRPC.ClientLoggerInterceptor,
            Projecthub.Util.GRPC.ClientRunAsyncInterceptor
          ]
        )

      org_id = Ecto.UUID.generate()

      {:ok, project} =
        Support.Factories.Project.create_with_repo(%{
          organization_id: org_id
        })

      request =
        InternalApi.Projecthub.DestroyRequest.new(
          metadata:
            InternalApi.Projecthub.RequestMeta.new(
              api_version: "",
              kind: "",
              req_id: "",
              org_id: org_id,
              user_id: "12345678-1234-5678-1234-567812345678"
            ),
          id: project.id,
          name: ""
        )

      with_mock Project, [:passthrough], soft_destroy: fn _p, _u -> {:ok, nil} end do
        {:ok, response} = Stub.destroy(channel, request)

        assert_called(Project.soft_destroy(:_, :_))

        assert response.metadata.status.code ==
                 :OK
      end
    end

    test "when the request has the project name => destroys the project" do
      {:ok, channel} =
        GRPC.Stub.connect("localhost:50051",
          interceptors: [
            Projecthub.Util.GRPC.ClientRequestIdInterceptor,
            Projecthub.Util.GRPC.ClientLoggerInterceptor,
            Projecthub.Util.GRPC.ClientRunAsyncInterceptor
          ]
        )

      org_id = Ecto.UUID.generate()

      {:ok, project} =
        Support.Factories.Project.create_with_repo(%{
          organization_id: org_id
        })

      {:ok, _project_with_same_name} =
        Support.Factories.Project.create_with_repo(%{
          name: project.name
        })

      request =
        InternalApi.Projecthub.DestroyRequest.new(
          metadata:
            InternalApi.Projecthub.RequestMeta.new(
              api_version: "",
              kind: "",
              req_id: "",
              org_id: org_id,
              user_id: "12345678-1234-5678-1234-567812345678"
            ),
          id: "",
          name: project.name
        )

      with_mock Project, [:passthrough], soft_destroy: fn _p, _u -> {:ok, nil} end do
        {:ok, response} = Stub.destroy(channel, request)

        assert_called(Project.soft_destroy(:_, :_))

        assert response.metadata.status.code ==
                 :OK
      end
    end

    test "when the project doesn't exist => returns a not found response" do
      {:ok, channel} =
        GRPC.Stub.connect("localhost:50051",
          interceptors: [
            Projecthub.Util.GRPC.ClientRequestIdInterceptor,
            Projecthub.Util.GRPC.ClientLoggerInterceptor,
            Projecthub.Util.GRPC.ClientRunAsyncInterceptor
          ]
        )

      org_id = Ecto.UUID.generate()

      request =
        InternalApi.Projecthub.DestroyRequest.new(
          metadata:
            InternalApi.Projecthub.RequestMeta.new(
              api_version: "",
              kind: "",
              req_id: "",
              org_id: org_id,
              user_id: "12345678-1234-5678-1234-567812345678"
            ),
          id: Ecto.UUID.generate(),
          name: ""
        )

      {:ok, response} = Stub.destroy(channel, request)

      assert response.metadata.status.code ==
               :NOT_FOUND
    end
  end

  describe ".restore" do
    test "when a soft deleted project is set to be restored => restores the project and returns ok" do
      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      org_id = Ecto.UUID.generate()

      {:ok, project} =
        Support.Factories.Project.create_with_repo(%{
          organization_id: org_id
        })

      {:ok, _} = Project.soft_destroy(project, %User{github_token: "token"})

      request =
        InternalApi.Projecthub.RestoreRequest.new(
          metadata:
            InternalApi.Projecthub.RequestMeta.new(
              api_version: "",
              kind: "",
              req_id: "",
              org_id: org_id,
              user_id: "12345678-1234-5678-1234-567812345678"
            ),
          id: project.id
        )

      {:ok, response} = Stub.restore(channel, request)

      assert response.metadata.status.code == :OK
    end

    test "when a project that is not soft deleted and it is requested to be restored => returns a not found response" do
      {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      org_id = Ecto.UUID.generate()

      {:ok, project} =
        Support.Factories.Project.create_with_repo(%{
          organization_id: org_id
        })

      request =
        InternalApi.Projecthub.RestoreRequest.new(
          metadata:
            InternalApi.Projecthub.RequestMeta.new(
              api_version: "",
              kind: "",
              req_id: "",
              org_id: org_id,
              user_id: "12345678-1234-5678-1234-567812345678"
            ),
          id: project.id
        )

      {:ok, response} = Stub.restore(channel, request)

      assert response.metadata.status.code == :NOT_FOUND
    end
  end

  describe ".users" do
    # TODO
  end

  describe ".fork_and_create" do
    @describetag :skip
    test "when everything is in order with request => forks and creates the project and returns ok" do
      {:ok, channel} =
        GRPC.Stub.connect("localhost:50051",
          interceptors: [
            Projecthub.Util.GRPC.ClientRequestIdInterceptor,
            Projecthub.Util.GRPC.ClientLoggerInterceptor,
            Projecthub.Util.GRPC.ClientRunAsyncInterceptor
          ]
        )

      org_id = Ecto.UUID.generate()

      org_response =
        InternalApi.Organization.DescribeResponse.new(
          status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
          organization:
            InternalApi.Organization.Organization.new(
              org_username: "organization",
              org_id: org_id
            )
        )

      FunRegistry.set!(Support.FakeServices.OrganizationService, :describe, org_response)

      request =
        InternalApi.Projecthub.ForkAndCreateRequest.new(
          metadata:
            InternalApi.Projecthub.RequestMeta.new(
              api_version: "",
              kind: "",
              req_id: "",
              org_id: org_id,
              user_id: "12345678-1234-5678-1234-567812345678"
            ),
          project:
            InternalApi.Projecthub.Project.new(
              metadata:
                InternalApi.Projecthub.Project.Metadata.new(
                  name: "organization",
                  id: "12345678-1234-5678-1234-567812345678",
                  owner_id: "12345678-1234-5678-1234-567812345678",
                  org_id: org_id,
                  description: "A repo for testing SemaphoreCI features"
                ),
              spec:
                InternalApi.Projecthub.Project.Spec.new(
                  repository:
                    InternalApi.Projecthub.Project.Spec.Repository.new(
                      url: "repo_url",
                      name: "repo_name",
                      owner: "repo_owner"
                    )
                )
            )
        )

      repo = %{url: "repo_forked_url"}
      repo_details = %{private: true}
      {:ok, project} = Support.Factories.Project.create()

      {:ok, _} =
        Support.Factories.Repository.create(%{
          project_id: project.id
        })

      with_mocks([
        {Fork, [], [fork: fn _repo, _token -> {:ok, repo} end]},
        {RepoChecker, [], [run: fn _, _user, _url, _ -> {:ok, repo_details} end]},
        {Project, [:passthrough], [create: fn _a, _u, _o, _p, _r, _i -> {:ok, project} end]}
      ]) do
        {:ok, response} = Stub.fork_and_create(channel, request)
        _user = %User{id: "12345678-1234-5678-1234-567812345678", name: "example", github_token: "token"}
        _org = %Organization{id: org_id, username: "organization", open_source: false}

        _project_params = %{
          allowed_contributors: "",
          allowed_secrets: "",
          build_branch: true,
          build_forked_pr: false,
          build_pr: false,
          build_tag: true,
          description: request.project.metadata.description,
          name: request.project.metadata.name,
          public: false
        }

        assert response.metadata.status ==
                 InternalApi.Projecthub.ResponseMeta.Status.new(code: :OK)

        assert response.project
      end
    end
  end

  describe ".github_app_switch" do
    @tag :skip
    test "when project exists -> switch it to github_app" do
      alias Projecthub.Models.Repository

      {:ok, channel} =
        GRPC.Stub.connect("localhost:50051",
          interceptors: [
            Projecthub.Util.GRPC.ClientRequestIdInterceptor,
            Projecthub.Util.GRPC.ClientLoggerInterceptor,
            Projecthub.Util.GRPC.ClientRunAsyncInterceptor
          ]
        )

      {:ok, project} = Support.Factories.Project.create()

      {:ok, repository} =
        Support.Factories.Repository.create(%{
          project_id: project.id
        })

      refute repository.hook_id == nil
      assert repository.integration_type == :GITHUB_OAUTH_TOKEN

      req =
        InternalApi.Projecthub.GithubAppSwitchRequest.new(
          metadata:
            InternalApi.Projecthub.RequestMeta.new(
              api_version: "",
              kind: "",
              req_id: "",
              org_id: project.organization_id,
              user_id: Ecto.UUID.generate()
            ),
          id: project.id
        )

      with_mocks([
        {Tentacat.Hooks, [],
         [
           remove: fn _, _, _, _ -> {204, nil, nil} end
         ]}
      ]) do
        {:ok, response} = Stub.github_app_switch(channel, req)

        {:ok, repo} = Repository.find_for_project(project.id)

        refute repository.hook_id == nil
        assert repo.integration_type == "github_app"

        assert response.metadata.status ==
                 InternalApi.Projecthub.ResponseMeta.Status.new(code: :OK)
      end
    end
  end

  defp create_cut_timestamp do
    DateTime.utc_now()
    |> DateTime.to_unix(:second)
    |> Integer.floor_div(1000)
  end
end
