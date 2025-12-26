defmodule Rbac.GrpcServers.OktaServer.Test do
  use Rbac.RepoCase, async: false

  import Mock

  describe "set_up" do
    test "permission denied if no organization.okta.manage for user" do
      {:ok, cert} = Support.Okta.Saml.PayloadBuilder.test_cert()

      request = %InternalApi.Okta.SetUpRequest{
        org_id: Ecto.UUID.generate(),
        creator_id: Ecto.UUID.generate(),
        idempotency_token: Ecto.UUID.generate(),
        saml_issuer: "https://otkta.something/very/secure",
        jit_provisioning_enabled: false,
        saml_certificate: cert
      }

      assert {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      assert {:error, res} = InternalApi.Okta.Okta.Stub.set_up(channel, request)
      assert res.status == GRPC.Status.permission_denied()
      assert res.message =~ "User unauthorized"
    end

    test "set up with proper values => returns a serialized okta integration" do
      {:ok, cert} = Support.Okta.Saml.PayloadBuilder.test_cert()

      request = %InternalApi.Okta.SetUpRequest{
        org_id: Ecto.UUID.generate(),
        creator_id: Ecto.UUID.generate(),
        idempotency_token: Ecto.UUID.generate(),
        saml_issuer: "https://otkta.something/very/secure",
        jit_provisioning_enabled: false,
        saml_certificate: cert
      }

      org_without_okta = %{
        org_id: request.org_id,
        allowed_id_providers: ["github"]
      }

      org_with_okta = %{
        org_id: request.org_id,
        allowed_id_providers: ["github", "okta"]
      }

      with_mocks([
        {Rbac.Store.UserPermissions, [],
         [read_user_permissions: fn _ -> "organization.okta.manage" end]},
        {Rbac.Api.Organization, [],
         [
           find_by_id: fn _ -> {:ok, org_without_okta} end,
           update: fn org ->
             assert "okta" in org.allowed_id_providers
             {:ok, org_with_okta}
           end
         ]}
      ]) do
        assert {:ok, channel} = GRPC.Stub.connect("localhost:50051")
        assert {:ok, res} = InternalApi.Okta.Okta.Stub.set_up(channel, request)

        #
        # Assert that the response is valid
        #
        assert %InternalApi.Okta.SetUpResponse{} = res

        assert res.integration.org_id == request.org_id
        assert res.integration.creator_id == request.creator_id
        assert res.integration.idempotency_token == request.idempotency_token
        assert res.integration.saml_issuer == request.saml_issuer

        assert res.integration.id != nil
        assert res.integration.created_at != nil
        assert res.integration.updated_at != nil

        #
        # Assert that the data was properly persisted
        #
        assert {:ok, integration} = Rbac.Okta.Integration.find(res.integration.id)
        assert integration.org_id == request.org_id
        assert integration.creator_id == request.creator_id
        assert integration.saml_issuer == request.saml_issuer
        assert integration.idempotency_token == request.idempotency_token

        {:ok, fingerprint} = Rbac.Okta.Saml.Certificate.fingerprint(cert)
        assert integration.saml_certificate_fingerprint == Base.encode64(fingerprint)

        # Verify that organization API was called to update allowed_id_providers
        assert_called(Rbac.Api.Organization.find_by_id(request.org_id))
        assert_called(Rbac.Api.Organization.update(:_))
      end
    end

    test "idempotent requests return the same response" do
      {:ok, cert} = Support.Okta.Saml.PayloadBuilder.test_cert()

      request = %InternalApi.Okta.SetUpRequest{
        org_id: Ecto.UUID.generate(),
        creator_id: Ecto.UUID.generate(),
        idempotency_token: Ecto.UUID.generate(),
        saml_issuer: "https://otkta.something/very/secure",
        jit_provisioning_enabled: false,
        saml_certificate: cert
      }

      org = %{
        org_id: request.org_id,
        allowed_id_providers: ["github", "okta"]
      }

      with_mocks([
        {Rbac.Store.UserPermissions, [],
         [read_user_permissions: fn _ -> "organization.okta.manage" end]},
        {Rbac.Api.Organization, [],
         [
           find_by_id: fn _ -> {:ok, org} end,
           update: fn org ->
             assert "okta" in org.allowed_id_providers
             {:ok, org}
           end
         ]}
      ]) do
        assert {:ok, channel} = GRPC.Stub.connect("localhost:50051")
        assert {:ok, res1} = InternalApi.Okta.Okta.Stub.set_up(channel, request)
        assert {:ok, res2} = InternalApi.Okta.Okta.Stub.set_up(channel, request)

        assert res1 == res2
      end
    end

    test "If org already has okta set_up, update it" do
      {:ok, cert} = Support.Okta.Saml.PayloadBuilder.test_cert()

      org_id = Ecto.UUID.generate()

      request = %InternalApi.Okta.SetUpRequest{
        org_id: org_id,
        creator_id: Ecto.UUID.generate(),
        idempotency_token: Ecto.UUID.generate(),
        saml_issuer: "https://otkta.something/very/secure",
        jit_provisioning_enabled: false,
        saml_certificate: cert
      }

      update_request = %InternalApi.Okta.SetUpRequest{
        org_id: org_id,
        creator_id: Ecto.UUID.generate(),
        idempotency_token: Ecto.UUID.generate(),
        saml_issuer: "https://otkta.something/else",
        jit_provisioning_enabled: false,
        saml_certificate: cert
      }

      org_without_okta = %{
        org_id: org_id,
        allowed_id_providers: ["github"]
      }

      with_mocks([
        {Rbac.Store.UserPermissions, [],
         [read_user_permissions: fn _ -> "organization.okta.manage" end]},
        {Rbac.Api.Organization, [],
         [
           find_by_id: fn ^org_id -> {:ok, org_without_okta} end,
           update: fn org ->
             assert "okta" in org.allowed_id_providers
             {:ok, org}
           end
         ]}
      ]) do
        assert {:ok, channel} = GRPC.Stub.connect("localhost:50051")
        assert {:ok, res} = InternalApi.Okta.Okta.Stub.set_up(channel, request)
        :timer.sleep(2_000)
        assert {:ok, update_res} = InternalApi.Okta.Okta.Stub.set_up(channel, update_request)

        assert update_res.integration.created_at == res.integration.created_at
        assert update_res.integration.updated_at != res.integration.updated_at
        assert update_res.integration.idempotency_token != res.integration.idempotency_token

        assert_called(Rbac.Api.Organization.find_by_id(org_id))
        assert_called_exactly(Rbac.Api.Organization.update(:_), 2)
      end
    end

    test "Integration is not created if updating allowed_id_providers fails" do
      import ExUnit.CaptureLog

      {:ok, cert} = Support.Okta.Saml.PayloadBuilder.test_cert()

      org_id = Ecto.UUID.generate()

      request = %InternalApi.Okta.SetUpRequest{
        org_id: org_id,
        creator_id: Ecto.UUID.generate(),
        idempotency_token: Ecto.UUID.generate(),
        saml_issuer: "https://otkta.something/very/secure",
        jit_provisioning_enabled: false,
        saml_certificate: cert
      }

      org_without_okta = %{
        org_id: org_id,
        allowed_id_providers: ["github"]
      }

      with_mocks([
        {Rbac.Store.UserPermissions, [],
         [read_user_permissions: fn _ -> "organization.okta.manage" end]},
        {Rbac.Api.Organization, [],
         [
           find_by_id: fn ^org_id -> {:ok, org_without_okta} end,
           update: fn org ->
             assert "okta" in org.allowed_id_providers
             {:error, nil}
           end
         ]}
      ]) do
        assert {:ok, channel} = GRPC.Stub.connect("localhost:50051")

        log =
          capture_log(fn ->
            assert match?({:error, _}, InternalApi.Okta.Okta.Stub.set_up(channel, request))
            assert {:error, :not_found} = Rbac.Okta.Integration.find_by_org_id(org_id)
          end)

        # Verify API calls and logging
        assert_called(Rbac.Api.Organization.find_by_id(org_id))
        assert_called(Rbac.Api.Organization.update(:_))

        assert log =~ "Failed to add okta provider for org"
      end
    end

    test "If certificate is not valid, return invalid_argument error" do
      request = %InternalApi.Okta.SetUpRequest{
        org_id: Ecto.UUID.generate(),
        creator_id: Ecto.UUID.generate(),
        idempotency_token: Ecto.UUID.generate(),
        saml_issuer: "https://otkta.something/very/secure",
        jit_provisioning_enabled: false,
        saml_certificate: "-----BEGIN CERTIFICATE-----"
      }

      with_mock Rbac.Store.UserPermissions, [:passthrough],
        read_user_permissions: fn _ -> "organization.okta.manage" end do
        assert {:ok, channel} = GRPC.Stub.connect("localhost:50051")
        assert {:error, resp} = InternalApi.Okta.Okta.Stub.set_up(channel, request)
        assert resp.status == 9
        assert resp.message == "SAML certificate is not valid."
      end
    end
  end

  describe "generate_scim_token" do
    test "invalid ID format is passed" do
      request = %InternalApi.Okta.GenerateScimTokenRequest{
        integration_id: "lol-deal-with-it-trololol"
      }

      assert {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      assert {:error, err} = InternalApi.Okta.Okta.Stub.generate_scim_token(channel, request)

      assert err == %GRPC.RPCError{
               message: "Invalid uuid passed as an argument where uuid v4 was expected.",
               status: 3
             }
    end

    test "integration with ID does not exists" do
      id = Ecto.UUID.generate()
      request = %InternalApi.Okta.GenerateScimTokenRequest{integration_id: id}

      assert {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      assert {:error, err} = InternalApi.Okta.Okta.Stub.generate_scim_token(channel, request)

      assert err == %GRPC.RPCError{message: "Okta integration with ID=#{id} not found", status: 5}
    end

    test "on success it returns a token" do
      {:ok, integration} = create_integration()

      request = %InternalApi.Okta.GenerateScimTokenRequest{integration_id: integration.id}

      assert {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      assert {:ok, res} = InternalApi.Okta.Okta.Stub.generate_scim_token(channel, request)

      assert res.token != nil
      assert res.token != ""
      assert String.length(res.token) > 60
    end

    test "on success it persists the token in the DB" do
      {:ok, integration} = create_integration()

      request = %InternalApi.Okta.GenerateScimTokenRequest{integration_id: integration.id}

      assert {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      assert {:ok, res} = InternalApi.Okta.Okta.Stub.generate_scim_token(channel, request)

      assert {:ok, persisted} = Rbac.Okta.Integration.find(integration.id)
      assert persisted.scim_token_hash == Base.encode64(Rbac.Okta.Scim.Token.hash(res.token))
    end
  end

  describe "list" do
    test "empty list if integration does not exist" do
      request = %InternalApi.Okta.ListRequest{org_id: Ecto.UUID.generate()}
      assert {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      assert {:ok, res} = InternalApi.Okta.Okta.Stub.list(channel, request)
      assert res.integrations == []
    end

    test "returns a serialized list of okta integrations for the org" do
      {:ok, integration} = create_integration()

      request = %InternalApi.Okta.ListRequest{org_id: integration.org_id}

      assert {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      assert {:ok, res} = InternalApi.Okta.Okta.Stub.list(channel, request)

      assert length(res.integrations) == 1

      assert Enum.at(res.integrations, 0).org_id == integration.org_id
      assert Enum.at(res.integrations, 0).creator_id == integration.creator_id
      assert Enum.at(res.integrations, 0).saml_issuer == integration.saml_issuer
      assert Enum.at(res.integrations, 0).sso_url == integration.sso_url
      assert Enum.at(res.integrations, 0).jit_provisioning_enabled == false
    end
  end

  describe "list_users" do
    test "empty list if integration does not exist" do
      request = %InternalApi.Okta.ListUsersRequest{org_id: Ecto.UUID.generate()}
      assert {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      assert {:ok, res} = InternalApi.Okta.Okta.Stub.list_users(channel, request)
      assert res.user_ids == []
    end

    test "returns empty list if no users exist for integration" do
      {:ok, integration} = create_integration()

      request = %InternalApi.Okta.ListUsersRequest{org_id: integration.org_id}
      assert {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      assert {:ok, res} = InternalApi.Okta.Okta.Stub.list_users(channel, request)
      assert res.user_ids == []
    end

    test "returns only active users" do
      {:ok, integration} = create_integration()
      active_user_id = Ecto.UUID.generate()
      inactive_user_id = Ecto.UUID.generate()

      [
        %Rbac.Repo.OktaUser{
          org_id: integration.org_id,
          integration_id: integration.id,
          state: :processed,
          user_id: active_user_id,
          payload: %{
            "active" => true,
            "displayName" => "John Whatever",
            "emails" => [
              %{"primary" => true, "value" => "whatever@whatever.com"}
            ]
          }
        },
        %Rbac.Repo.OktaUser{
          org_id: integration.org_id,
          integration_id: integration.id,
          state: :processed,
          user_id: inactive_user_id,
          payload: %{
            "active" => false,
            "displayName" => "John Whatever",
            "emails" => [
              %{"primary" => true, "value" => "whatever@whatever.com"}
            ]
          }
        }
      ]
      |> Enum.each(fn u -> Rbac.Repo.insert(u) end)

      request = %InternalApi.Okta.ListUsersRequest{org_id: integration.org_id}
      assert {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      assert {:ok, res} = InternalApi.Okta.Okta.Stub.list_users(channel, request)
      assert length(res.user_ids) == 1
    end
  end

  describe "destroy" do
    setup do
      {:ok, integration} = create_integration()
      Support.Factories.Scope.insert("org_scope")
      %{integration: integration}
    end

    test "integration does not exist" do
      with_mock Rbac.Store.UserPermissions, [:passthrough],
        read_user_permissions: fn _ -> "organization.okta.manage" end do
        request = %InternalApi.Okta.DestroyRequest{
          user_id: Ecto.UUID.generate(),
          integration_id: Ecto.UUID.generate()
        }

        assert {:ok, channel} = GRPC.Stub.connect("localhost:50051")
        assert {:error, res} = InternalApi.Okta.Okta.Stub.destroy(channel, request)
        assert res.message == "Integration does not exist"
        assert res.status == GRPC.Status.not_found()
      end
    end

    test "Remove from org only users provisioned by okta", %{integration: integration} do
      {:ok, okta_user} = Support.Factories.RbacUser.insert()
      {:ok, non_okta_user} = Support.Factories.RbacUser.insert()

      {:ok, _} =
        Support.Factories.OktaUser.insert(
          integration_id: integration.id,
          org_id: integration.org_id,
          user_id: okta_user.id
        )

      # Assigning org role to the okta user
      {:ok, _} =
        Support.Factories.SubjectRoleBinding.insert(
          org_id: integration.org_id,
          subject_id: okta_user.id,
          project_id: nil,
          binding_source: :okta
        )

      # Assigning org role to the non-okta user
      {:ok, _} =
        Support.Factories.SubjectRoleBinding.insert(
          org_id: integration.org_id,
          subject_id: non_okta_user.id,
          project_id: nil,
          binding_source: :manually_assigned
        )

      request = %InternalApi.Okta.DestroyRequest{
        user_id: okta_user.id,
        integration_id: integration.id
      }

      # Define the organization with okta in allowed_id_providers
      org_with_okta = %{
        org_id: integration.org_id,
        allowed_id_providers: ["github", "okta"]
      }

      assert {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      with_mocks([
        {Rbac.Store.UserPermissions, [:passthrough],
         [read_user_permissions: fn _ -> "organization.okta.manage" end]},
        {Rbac.Api.Organization, [],
         [
           find_by_id: fn _ ->
             {:ok, org_with_okta}
           end,
           update: fn org ->
             # Assert that okta is removed from allowed_id_providers
             refute "okta" in org.allowed_id_providers
             {:ok, nil}
           end
         ]}
      ]) do
        assert {:ok, _res} = InternalApi.Okta.Okta.Stub.destroy(channel, request)
        # The mocked function is executed async, hence the wait
        :timer.sleep(2_000)
        assert_called_exactly(Rbac.Api.Organization.find_by_id(:_), 1)
        assert_called_exactly(Rbac.Api.Organization.update(:_), 1)
      end

      assert user_has_one_role_assigned?(non_okta_user.id)
      refute user_has_one_role_assigned?(okta_user.id)
      assert {:error, :not_found} == Rbac.Repo.OktaUser.find(integration, okta_user.id)
      assert nil != Rbac.Store.RbacUser.fetch(okta_user.id)
      assert {:error, :not_found} == Rbac.Okta.Integration.find(integration.id)
    end

    test "If okta is not removed as provider, restore everything", %{integration: integration} do
      {:ok, okta_user} = Support.Factories.RbacUser.insert()

      {:ok, _} =
        Support.Factories.OktaUser.insert(
          integration_id: integration.id,
          org_id: integration.org_id,
          user_id: okta_user.id
        )

      # Assigning org role to the okta user
      {:ok, _} =
        Support.Factories.SubjectRoleBinding.insert(
          org_id: integration.org_id,
          subject_id: okta_user.id,
          project_id: nil,
          binding_source: :okta
        )

      request = %InternalApi.Okta.DestroyRequest{
        user_id: okta_user.id,
        integration_id: integration.id
      }

      assert {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      with_mocks([
        {Rbac.Store.UserPermissions, [:passthrough],
         [read_user_permissions: fn _ -> "organization.okta.manage" end]},
        {Rbac.Api.Organization, [],
         [
           find_by_id: fn _ -> {:error, :not_found} end,
           update: fn org ->
             # Assert that okta is removed from allowed_id_providers
             refute "okta" in org.allowed_id_providers
             {:ok, nil}
           end
         ]}
      ]) do
        assert {:ok, _res} = InternalApi.Okta.Okta.Stub.destroy(channel, request)
        # The mocked function is executed async, hence the wait
        :timer.sleep(2_000)
      end

      assert user_has_one_role_assigned?(okta_user.id)
      assert match?({:ok, _}, Rbac.Okta.Integration.find(integration.id))
    end

    test "Dont allow if user doesn't have permission", %{integration: integration} do
      request = %InternalApi.Okta.DestroyRequest{
        user_id: Ecto.UUID.generate(),
        integration_id: integration.id
      }

      assert {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      with_mock Rbac.Store.UserPermissions, [:passthrough],
        read_user_permissions: fn _ -> "random.pemission" end do
        assert {:error, res} = InternalApi.Okta.Okta.Stub.destroy(channel, request)
        assert res.status == GRPC.Status.permission_denied()
      end
    end
  end

  describe "set_up_mapping" do
    setup do
      {:ok, integration} = create_integration()
      %{integration: integration}
    end

    test "invalid org_id format" do
      request = %InternalApi.Okta.SetUpMappingRequest{
        org_id: "not-a-valid-uuid",
        group_mapping: [],
        role_mapping: []
      }

      assert {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      assert {:error, err} = InternalApi.Okta.Okta.Stub.set_up_mapping(channel, request)

      assert err == %GRPC.RPCError{
               message: "Invalid uuid passed as an argument where uuid v4 was expected.",
               status: 3
             }
    end

    test "can create and update mappings with default_role_id", %{integration: integration} do
      semaphore_group_id_1 = Ecto.UUID.generate()
      semaphore_group_id_2 = Ecto.UUID.generate()
      semaphore_role_id_1 = Ecto.UUID.generate()
      default_role_id = Ecto.UUID.generate()

      group_mapping = [
        %InternalApi.Okta.GroupMapping{
          okta_group_id: "okta_group_1",
          semaphore_group_id: semaphore_group_id_1
        },
        %InternalApi.Okta.GroupMapping{
          okta_group_id: "okta_group_2",
          semaphore_group_id: semaphore_group_id_2
        }
      ]

      role_mapping = [
        %InternalApi.Okta.RoleMapping{
          okta_role_id: "okta_role_1",
          semaphore_role_id: semaphore_role_id_1
        }
      ]

      request = %InternalApi.Okta.SetUpMappingRequest{
        org_id: integration.org_id,
        group_mapping: group_mapping,
        role_mapping: role_mapping,
        default_role_id: default_role_id
      }

      assert {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      assert {:ok, response} = InternalApi.Okta.Okta.Stub.set_up_mapping(channel, request)
      assert %InternalApi.Okta.SetUpMappingResponse{} = response

      {:ok, idp_mapping} = Rbac.Okta.IdpGroupMapping.get_for_organization(integration.org_id)

      assert length(idp_mapping.group_mapping) == 2
      assert length(idp_mapping.role_mapping) == 1
      assert idp_mapping.default_role_id == default_role_id

      assert Enum.any?(idp_mapping.group_mapping, fn mapping ->
               mapping.idp_group_id == "okta_group_1" &&
                 mapping.semaphore_group_id == semaphore_group_id_1
             end)

      assert Enum.any?(idp_mapping.group_mapping, fn mapping ->
               mapping.idp_group_id == "okta_group_2" &&
                 mapping.semaphore_group_id == semaphore_group_id_2
             end)

      assert Enum.any?(idp_mapping.role_mapping, fn mapping ->
               mapping.idp_role_id == "okta_role_1" &&
                 mapping.semaphore_role_id == semaphore_role_id_1
             end)

      # Update with a new default_role_id
      new_default_role_id = Ecto.UUID.generate()
      semaphore_group_id_3 = Ecto.UUID.generate()
      semaphore_role_id_2 = Ecto.UUID.generate()

      updated_group_mapping = [
        %InternalApi.Okta.GroupMapping{
          okta_group_id: "okta_group_1",
          semaphore_group_id: semaphore_group_id_3
        },
        %InternalApi.Okta.GroupMapping{
          okta_group_id: "okta_group_2",
          semaphore_group_id: semaphore_group_id_2
        }
      ]

      updated_role_mapping = [
        %InternalApi.Okta.RoleMapping{
          okta_role_id: "okta_role_2",
          semaphore_role_id: semaphore_role_id_2
        }
      ]

      update_request = %InternalApi.Okta.SetUpMappingRequest{
        org_id: integration.org_id,
        group_mapping: updated_group_mapping,
        role_mapping: updated_role_mapping,
        default_role_id: new_default_role_id
      }

      assert {:ok, update_response} =
               InternalApi.Okta.Okta.Stub.set_up_mapping(channel, update_request)

      assert %InternalApi.Okta.SetUpMappingResponse{} = update_response

      {:ok, updated_idp_mapping} =
        Rbac.Okta.IdpGroupMapping.get_for_organization(integration.org_id)

      assert length(updated_idp_mapping.group_mapping) == 2
      assert length(updated_idp_mapping.role_mapping) == 1
      assert updated_idp_mapping.default_role_id == new_default_role_id

      assert Enum.any?(updated_idp_mapping.group_mapping, fn mapping ->
               mapping.idp_group_id == "okta_group_1" &&
                 mapping.semaphore_group_id == semaphore_group_id_3
             end)

      assert Enum.any?(updated_idp_mapping.group_mapping, fn mapping ->
               mapping.idp_group_id == "okta_group_2" &&
                 mapping.semaphore_group_id == semaphore_group_id_2
             end)

      assert Enum.any?(updated_idp_mapping.role_mapping, fn mapping ->
               mapping.idp_role_id == "okta_role_2" &&
                 mapping.semaphore_role_id == semaphore_role_id_2
             end)
    end

    test "fails with invalid group mappings", %{integration: integration} do
      group_mapping = [
        %InternalApi.Okta.GroupMapping{
          okta_group_id: "okta_group_1",
          semaphore_group_id: nil
        }
      ]

      request = %InternalApi.Okta.SetUpMappingRequest{
        org_id: integration.org_id,
        group_mapping: group_mapping,
        default_role_id: Ecto.UUID.generate()
      }

      assert {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      assert {:error, _} = InternalApi.Okta.Okta.Stub.set_up_mapping(channel, request)
    end

    test "fails with invalid role mappings", %{integration: integration} do
      group_mapping = [
        %InternalApi.Okta.GroupMapping{
          okta_group_id: "okta_group_1",
          semaphore_group_id: Ecto.UUID.generate()
        }
      ]

      role_mapping = [
        %InternalApi.Okta.RoleMapping{
          okta_role_id: "okta_role_1",
          semaphore_role_id: nil
        }
      ]

      request = %InternalApi.Okta.SetUpMappingRequest{
        org_id: integration.org_id,
        group_mapping: group_mapping,
        role_mapping: role_mapping,
        default_role_id: Ecto.UUID.generate()
      }

      assert {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      assert {:error, _} = InternalApi.Okta.Okta.Stub.set_up_mapping(channel, request)
    end

    test "fails with duplicate group mappings", %{integration: integration} do
      semaphore_group_id = Ecto.UUID.generate()

      group_mapping = [
        %InternalApi.Okta.GroupMapping{
          okta_group_id: "same_okta_group",
          semaphore_group_id: semaphore_group_id
        },
        %InternalApi.Okta.GroupMapping{
          okta_group_id: "same_okta_group",
          semaphore_group_id: semaphore_group_id
        }
      ]

      request = %InternalApi.Okta.SetUpMappingRequest{
        org_id: integration.org_id,
        group_mapping: group_mapping,
        default_role_id: Ecto.UUID.generate()
      }

      assert {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      assert {:error, _} = InternalApi.Okta.Okta.Stub.set_up_mapping(channel, request)
    end

    test "fails with duplicate role mappings", %{integration: integration} do
      semaphore_group_id = Ecto.UUID.generate()
      semaphore_role_id = Ecto.UUID.generate()

      group_mapping = [
        %InternalApi.Okta.GroupMapping{
          okta_group_id: "okta_group_1",
          semaphore_group_id: semaphore_group_id
        }
      ]

      role_mapping = [
        %InternalApi.Okta.RoleMapping{
          okta_role_id: "same_okta_role",
          semaphore_role_id: semaphore_role_id
        },
        %InternalApi.Okta.RoleMapping{
          okta_role_id: "same_okta_role",
          semaphore_role_id: semaphore_role_id
        }
      ]

      request = %InternalApi.Okta.SetUpMappingRequest{
        org_id: integration.org_id,
        group_mapping: group_mapping,
        role_mapping: role_mapping,
        default_role_id: Ecto.UUID.generate()
      }

      assert {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      assert {:error, _} = InternalApi.Okta.Okta.Stub.set_up_mapping(channel, request)
    end

    test "fails when default role id not present", %{integration: integration} do
      semaphore_group_id_1 = Ecto.UUID.generate()

      # First set up with a default_role_id
      initial_group_mapping = [
        %InternalApi.Okta.GroupMapping{
          okta_group_id: "okta_group_1",
          semaphore_group_id: semaphore_group_id_1
        }
      ]

      initial_request = %InternalApi.Okta.SetUpMappingRequest{
        org_id: integration.org_id,
        group_mapping: initial_group_mapping
      }

      assert {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      assert {:error, error} = InternalApi.Okta.Okta.Stub.set_up_mapping(channel, initial_request)

      assert error.message =~ "Invalid"
    end
  end

  describe "describe_mapping" do
    setup do
      {:ok, integration} = create_integration()
      %{integration: integration}
    end

    test "invalid org_id format" do
      request = %InternalApi.Okta.DescribeMappingRequest{
        org_id: "not-a-valid-uuid"
      }

      assert {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      assert {:error, err} = InternalApi.Okta.Okta.Stub.describe_mapping(channel, request)

      assert err == %GRPC.RPCError{
               message: "Invalid uuid passed as an argument where uuid v4 was expected.",
               status: 3
             }
    end

    test "returns empty mappings when no mappings exist", %{integration: integration} do
      request = %InternalApi.Okta.DescribeMappingRequest{
        org_id: integration.org_id
      }

      assert {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      assert {:ok, res} = InternalApi.Okta.Okta.Stub.describe_mapping(channel, request)

      assert %InternalApi.Okta.DescribeMappingResponse{} = res
      assert Enum.empty?(res.group_mapping)
      assert Enum.empty?(res.role_mapping)
    end

    test "returns mappings when they exist", %{integration: integration} do
      semaphore_group_id_1 = Ecto.UUID.generate()
      semaphore_group_id_2 = Ecto.UUID.generate()
      semaphore_role_id_1 = Ecto.UUID.generate()
      default_role_id = Ecto.UUID.generate()

      group_mappings = [
        %{
          idp_group_id: "okta_group_1",
          semaphore_group_id: semaphore_group_id_1
        },
        %{
          idp_group_id: "okta_group_2",
          semaphore_group_id: semaphore_group_id_2
        }
      ]

      role_mappings = [
        %{
          idp_role_id: "okta_role_1",
          semaphore_role_id: semaphore_role_id_1
        }
      ]

      {:ok, _} =
        Rbac.Okta.IdpGroupMapping.create_or_update(
          integration.org_id,
          group_mappings,
          role_mappings,
          default_role_id
        )

      list_request = %InternalApi.Okta.DescribeMappingRequest{
        org_id: integration.org_id
      }

      assert {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      assert {:ok, res} = InternalApi.Okta.Okta.Stub.describe_mapping(channel, list_request)

      assert %InternalApi.Okta.DescribeMappingResponse{} = res
      assert length(res.group_mapping) == 2
      assert length(res.role_mapping) == 1
      assert res.default_role_id == default_role_id

      assert Enum.any?(res.group_mapping, fn m ->
               m.okta_group_id == "okta_group_1" && m.semaphore_group_id == semaphore_group_id_1
             end)

      assert Enum.any?(res.group_mapping, fn m ->
               m.okta_group_id == "okta_group_2" && m.semaphore_group_id == semaphore_group_id_2
             end)

      assert Enum.any?(res.role_mapping, fn m ->
               m.okta_role_id == "okta_role_1" && m.semaphore_role_id == semaphore_role_id_1
             end)
    end

    test "returns empty lists for non-existent organization" do
      request = %InternalApi.Okta.DescribeMappingRequest{
        org_id: Ecto.UUID.generate()
      }

      assert {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      assert {:ok, res} = InternalApi.Okta.Okta.Stub.describe_mapping(channel, request)

      assert %InternalApi.Okta.DescribeMappingResponse{} = res
      assert Enum.empty?(res.group_mapping)
      assert Enum.empty?(res.role_mapping)
    end
  end

  ###
  ### Helper functions
  ###
  def create_integration do
    {:ok, cert} = Support.Okta.Saml.PayloadBuilder.test_cert()

    with_mocks([
      {Rbac.Api.Organization, [],
       [
         find_by_id: fn _ -> {:ok, %{allowed_id_providers: []}} end,
         update: fn _ -> {:ok, %{}} end
       ]}
    ]) do
      Rbac.Okta.Integration.create_or_update(
        Ecto.UUID.generate(),
        Ecto.UUID.generate(),
        "https://sso-url.com",
        "https://saml-issuer.com",
        cert,
        false
      )
    end
  end

  defp user_has_one_role_assigned?(user_id) do
    import Ecto.Query, only: [where: 3]

    ret =
      Rbac.Repo.SubjectRoleBinding
      |> where([srb], srb.subject_id == ^user_id)
      |> Rbac.Repo.one()

    ret != nil
  end
end
