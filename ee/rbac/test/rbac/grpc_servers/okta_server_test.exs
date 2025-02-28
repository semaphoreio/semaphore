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
        saml_certificate: cert
      }

      with_mock Rbac.Store.UserPermissions, [:passthrough],
        read_user_permissions: fn _ -> "organization.okta.manage" end do
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
      end
    end

    test "idempotent requests return the same response" do
      {:ok, cert} = Support.Okta.Saml.PayloadBuilder.test_cert()

      request = %InternalApi.Okta.SetUpRequest{
        org_id: Ecto.UUID.generate(),
        creator_id: Ecto.UUID.generate(),
        idempotency_token: Ecto.UUID.generate(),
        saml_issuer: "https://otkta.something/very/secure",
        saml_certificate: cert
      }

      with_mock Rbac.Store.UserPermissions, [:passthrough],
        read_user_permissions: fn _ -> "organization.okta.manage" end do
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
        saml_certificate: cert
      }

      update_request = %InternalApi.Okta.SetUpRequest{
        org_id: org_id,
        creator_id: Ecto.UUID.generate(),
        idempotency_token: Ecto.UUID.generate(),
        saml_issuer: "https://otkta.something/else",
        saml_certificate: cert
      }

      with_mock Rbac.Store.UserPermissions, [:passthrough],
        read_user_permissions: fn _ -> "organization.okta.manage" end do
        assert {:ok, channel} = GRPC.Stub.connect("localhost:50051")
        assert {:ok, res} = InternalApi.Okta.Okta.Stub.set_up(channel, request)
        :timer.sleep(2_000)
        assert {:ok, update_res} = InternalApi.Okta.Okta.Stub.set_up(channel, update_request)

        assert update_res.integration.created_at == res.integration.created_at
        assert update_res.integration.updated_at != res.integration.updated_at
        assert update_res.integration.idempotency_token != res.integration.idempotency_token
      end
    end

    test "If certificate is not valid, return invalid_argument error" do
      request = %InternalApi.Okta.SetUpRequest{
        org_id: Ecto.UUID.generate(),
        creator_id: Ecto.UUID.generate(),
        idempotency_token: Ecto.UUID.generate(),
        saml_issuer: "https://otkta.something/very/secure",
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

      assert {:ok, channel} = GRPC.Stub.connect("localhost:50051")

      with_mock Rbac.Store.UserPermissions, [:passthrough],
        read_user_permissions: fn _ -> "organization.okta.manage" end do
        assert {:ok, _res} = InternalApi.Okta.Okta.Stub.destroy(channel, request)
      end

      assert user_has_one_role_assigned?(non_okta_user.id)
      refute user_has_one_role_assigned?(okta_user.id)
      assert {:error, :not_found} == Rbac.Repo.OktaUser.find(integration, okta_user.id)
      assert nil != Rbac.Store.RbacUser.fetch(okta_user.id)
      assert {:error, :not_found} == Rbac.Okta.Integration.find(integration.id)
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

  ###
  ### Helper functions
  ###
  def create_integration do
    {:ok, cert} = Support.Okta.Saml.PayloadBuilder.test_cert()

    with_mock Rbac.Store.UserPermissions, [:passthrough],
      read_user_permissions: fn _ -> "organization.okta.manage" end do
      request = %InternalApi.Okta.SetUpRequest{
        org_id: Ecto.UUID.generate(),
        creator_id: Ecto.UUID.generate(),
        idempotency_token: Ecto.UUID.generate(),
        saml_issuer: "https://otkta.something/very/secure",
        saml_certificate: cert,
        sso_url: "https://otkta.something/very/secure"
      }

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, res} = InternalApi.Okta.Okta.Stub.set_up(channel, request)

      {:ok, res.integration}
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
