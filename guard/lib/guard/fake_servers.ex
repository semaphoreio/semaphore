defmodule Guard.FakeServers do
  def fake_grpc_servers do
    {:ok, _} = FunRegistry.start()

    services = [
      Support.Fake.OrganizationService,
      Support.Fake.SecretService,
      Support.Fake.RepositoryService,
      Support.Fake.RbacService,
      Support.Fake.OktaService
    ]

    GRPC.Server.start(services, 50_052)
  end

  def setup_responses_for_development do
    code = InternalApi.ResponseStatus.Code.value(:OK)
    status = InternalApi.ResponseStatus.new(code: code)

    secret_describe =
      InternalApi.Secrethub.DescribeResponse.new(
        metadata:
          InternalApi.Secrethub.ResponseMeta.new(
            api_version: "1",
            kind: "1",
            req_id: "1",
            org_id: "34736546-839c-4bae-b285-f2af2bb07fa2",
            user_id: "78114608-be8a-465a-b9cd-81970fb802c6",
            status:
              InternalApi.Secrethub.ResponseMeta.Status.new(
                code: InternalApi.Secrethub.ResponseMeta.Code.value(:OK),
                message: "It's OK"
              )
          ),
        secret:
          InternalApi.Secrethub.Secret.new(
            metadata:
              InternalApi.Secrethub.Secret.Metadata.new(
                name: "a9n",
                id: "78114608-be8a-465a-b9cd-91970fb802c6"
              ),
            data:
              InternalApi.Secrethub.Secret.Data.new(
                env_vars: [
                  InternalApi.Secrethub.Secret.EnvVar.new(
                    name: "foo",
                    value: "bar"
                  )
                ]
              )
          )
      )

    secret_describe_many =
      InternalApi.Secrethub.DescribeManyResponse.new(
        metadata:
          InternalApi.Secrethub.ResponseMeta.new(
            api_version: "1",
            kind: "1",
            req_id: "1",
            org_id: "34736546-839c-4bae-b285-f2af2bb07fa2",
            user_id: "78114608-be8a-465a-b9cd-81970fb802c6",
            status:
              InternalApi.Secrethub.ResponseMeta.Status.new(
                code: InternalApi.Secrethub.ResponseMeta.Code.value(:OK),
                message: "It's OK"
              )
          ),
        secrets: [
          InternalApi.Secrethub.Secret.new(
            metadata:
              InternalApi.Secrethub.Secret.Metadata.new(
                name: "a9n",
                id: "78114608-be8a-465a-b9cd-91970fb802c6",
                org_id: "34736546-839c-4bae-b285-f2af2bb07fa2"
              ),
            data:
              InternalApi.Secrethub.Secret.Data.new(
                env_vars: [
                  InternalApi.Secrethub.Secret.EnvVar.new(
                    name: "foo",
                    value: "bar"
                  )
                ]
              )
          )
        ]
      )

    organization_describe =
      InternalApi.Organization.DescribeResponse.new(
        status: status,
        organization:
          InternalApi.Organization.Organization.new(
            org_id: "78114608-be8a-465a-b9cd-81970fb802c6",
            org_username: "renderedtext",
            created_at: Google.Protobuf.Timestamp.new(seconds: 1),
            avatar_url: "https://s.gravatar.com/avatar/19fdbead2f7e3477649214240ff1540c",
            creator_id: "78114608-be8a-465a-b9cd-81970fb802c6"
          )
      )

    alias InternalApi.Repository.Collaborator
    alias InternalApi.Repository.Collaborator.Permission

    list_collaborators =
      InternalApi.Repository.ListCollaboratorsResponse.new(
        next_page_token: "",
        collaborators: [
          Collaborator.new(id: "2", login: "bar", permission: Permission.value(:ADMIN)),
          Collaborator.new(id: "3", login: "baz", permission: Permission.value(:WRITE)),
          Collaborator.new(id: "4", login: "bam", permission: Permission.value(:READ))
        ]
      )

    assign_role = InternalApi.RBAC.AssignRoleResponse.new()

    list_roles =
      InternalApi.RBAC.ListRolesResponse.new(
        roles: [
          InternalApi.RBAC.Role.new(
            id: "78114608-be8a-465a-b9cd-81970fb802c6",
            name: "Member",
            org_id: "78114608-be8a-465a-b9cd-81970fb802c6",
            scope: InternalApi.RBAC.Scope.value(:SCOPE_ORG)
          )
        ]
      )

    list_accessible_orgs =
      InternalApi.RBAC.ListAccessibleOrgsResponse.new(
        org_ids: ["78114608-be8a-465a-b9cd-81970fb802c6"]
      )

    list_members =
      InternalApi.RBAC.ListMembersResponse.new(
        members: [
          InternalApi.RBAC.ListMembersResponse.Member.new(
            subject:
              InternalApi.RBAC.Subject.new(
                subject_id: "78114608-be8a-465a-b9cd-81970fb802c6",
                subject_type: InternalApi.RBAC.SubjectType.value(:USER),
                display_name: "John Doe"
              ),
            subject_role_bindings: [
              InternalApi.RBAC.SubjectRoleBinding.new(
                role:
                  InternalApi.RBAC.Role.new(
                    id: "78114608-be8a-465a-b9cd-81970fb802c6",
                    name: "Member",
                    org_id: "78114608-be8a-465a-b9cd-81970fb802c6",
                    scope: InternalApi.RBAC.Scope.value(:SCOPE_ORG)
                  )
              )
            ]
          )
        ],
        total_pages: 1
      )

    list_okta_integrations =
      InternalApi.Okta.ListResponse.new(
        integrations: [
          InternalApi.Okta.OktaIntegration.new(
            id: "78114608-be8a-465a-b9cd-81970fb802c6",
            org_id: "78114608-be8a-465a-b9cd-81970fb802c6",
            creator_id: "78114608-be8a-465a-b9cd-81970fb802c6",
            created_at: Google.Protobuf.Timestamp.new(seconds: 1),
            updated_at: Google.Protobuf.Timestamp.new(seconds: 1),
            idempotency_token: "78114608-be8a-465a-b9cd-81970fb802c6",
            saml_issuer: "https://test_org.okta.com/asdf",
            sso_url: "https://test_org.okta.com/asdf"
          )
        ]
      )

    default_features =
      {:ok,
       [
         Support.StubbedProvider.feature("max_people_in_org", [:enabled, {:quantity, 500}])
       ]}

    default_machines = {:ok, []}

    FunRegistry.set!(Support.StubbedProvider, :provide_features, default_features)
    FunRegistry.set!(Support.StubbedProvider, :provide_machines, default_machines)
    FunRegistry.set!(Support.Fake.SecretService, :describe, secret_describe)
    FunRegistry.set!(Support.Fake.SecretService, :describe_many, secret_describe_many)
    FunRegistry.set!(Support.Fake.OrganizationService, :describe, organization_describe)
    FunRegistry.set!(Support.Fake.RepositoryService, :list_collaborators, list_collaborators)
    FunRegistry.set!(Support.Fake.RbacService, :assign_role, assign_role)
    FunRegistry.set!(Support.Fake.RbacService, :list_roles, list_roles)
    FunRegistry.set!(Support.Fake.RbacService, :list_accessible_orgs, list_accessible_orgs)
    FunRegistry.set!(Support.Fake.RbacService, :list_members, list_members)
    FunRegistry.set!(Support.Fake.OktaService, :list, list_okta_integrations)
  end
end
