defmodule Guard.GrpcServers.OrganizationServer do
  use GRPC.Server, service: InternalApi.Organization.OrganizationService.Service

  require Logger
  alias InternalApi.Organization

  import Guard.Utils,
    only: [
      grpc_error!: 2,
      valid_uuid?: 1,
      non_empty_value_or_default: 3,
      timestamp_to_datetime: 2
    ]

  @spec describe(Organization.DescribeRequest.t(), GRPC.Server.Stream.t()) ::
          Organization.DescribeResponse.t()
  def describe(%{org_id: org_id, org_username: org_username} = request, _stream) do
    Logger.debug("describe request: #{inspect(request)}")

    observe("describe", fn ->
      case fetch_organization(org_id, org_username, soft_deleted: request.soft_deleted) do
        {:ok, organization} ->
          %Organization.DescribeResponse{
            status: %InternalApi.ResponseStatus{
              code: InternalApi.ResponseStatus.Code.value(:OK),
              message: ""
            },
            organization: org_to_proto(organization)
          }

        {:error, {:not_found, msg}} ->
          grpc_error!(:not_found, msg)
      end
    end)
  end

  @spec fetch_organization_settings(
          Organization.FetchOrganizationSettingsRequest.t(),
          GRPC.Server.Stream.t()
        ) ::
          Organization.FetchOrganizationSettingsResponse.t()
  def fetch_organization_settings(%{org_id: org_id} = request, _stream) do
    Logger.debug("fetch_organization_settings request: #{inspect(request)}")

    observe("fetch_organization_settings", fn ->
      case fetch_organization(org_id, "") do
        {:ok, organization} ->
          %Organization.FetchOrganizationSettingsResponse{
            settings:
              (organization.settings || %{})
              |> Enum.map(fn setting -> setting_to_proto(setting) end)
          }

        {:error, {:not_found, msg}} ->
          grpc_error!(:not_found, msg)
      end
    end)
  end

  @spec list(Organization.ListRequest.t(), GRPC.Server.Stream.t()) ::
          Organization.ListResponse.t()
  def list(request, _stream) do
    Logger.debug("list request: #{inspect(request)}")

    observe("list", fn ->
      {:ok, size} = non_empty_value_or_default(request, :page_size, 20)
      {:ok, token} = non_empty_value_or_default(request, :page_token, nil)
      {:ok, created_at_gt} = timestamp_to_datetime(request.created_at_gt, :skip)

      {:ok, %{organizations: organizations, next_page_token: next_page_token}} =
        Guard.Store.Organization.list(
          %{
            created_at_gt: created_at_gt,
            soft_deleted: request.soft_deleted
          },
          %{
            page_token: token,
            page_size: size,
            order: InternalApi.Organization.ListRequest.Order.key(request.order)
          }
        )

      %Organization.ListResponse{
        status: %InternalApi.ResponseStatus{
          code: InternalApi.ResponseStatus.Code.value(:OK),
          message: ""
        },
        organizations: Enum.map(organizations, &org_to_proto/1),
        next_page_token: next_page_token
      }
    end)
  end

  @spec repository_integrators(
          Organization.RepositoryIntegratorsRequest.t(),
          GRPC.Server.Stream.t()
        ) ::
          Organization.RepositoryIntegratorsResponse.t()
  def repository_integrators(%{org_id: org_id} = request, _stream) do
    Logger.debug("repository_integrators request: #{inspect(request)}")

    observe("repository_integrators", fn ->
      case fetch_organization(org_id, "") do
        {:ok, _} ->
          primary = InternalApi.RepositoryIntegrator.IntegrationType.value(:GITHUB_APP)

          available =
            [
              InternalApi.RepositoryIntegrator.IntegrationType.value(:GITHUB_APP)
            ]
            |> add_if_enabled(
              InternalApi.RepositoryIntegrator.IntegrationType.value(:GITHUB_OAUTH_TOKEN),
              FeatureProvider.feature_enabled?(:github_oauth_token, param: org_id)
            )
            |> add_if_enabled(
              InternalApi.RepositoryIntegrator.IntegrationType.value(:BITBUCKET),
              FeatureProvider.feature_enabled?(:bitbucket, param: org_id)
            )
            |> add_if_enabled(
              InternalApi.RepositoryIntegrator.IntegrationType.value(:GITLAB),
              FeatureProvider.feature_enabled?(:gitlab, param: org_id)
            )
            |> add_if_enabled(
              InternalApi.RepositoryIntegrator.IntegrationType.value(:GIT),
              FeatureProvider.feature_enabled?(:git, param: org_id)
            )

          %Organization.RepositoryIntegratorsResponse{
            primary: primary,
            enabled: available,
            available: available
          }

        {:error, {:not_found, msg}} ->
          grpc_error!(:not_found, msg)
      end
    end)
  end

  @spec describe_many(Organization.DescribeManyRequest.t(), GRPC.Server.Stream.t()) ::
          Organization.DescribeManyResponse.t()
  def describe_many(%{org_ids: org_ids, soft_deleted: soft_deleted} = request, _stream) do
    Logger.debug("describe_many request: #{inspect(request)}")

    observe("describe_many", fn ->
      organizations =
        org_ids
        |> Enum.filter(&valid_uuid?/1)
        |> Guard.Store.Organization.list_by_ids(soft_deleted: soft_deleted)
        |> Enum.map(&org_to_proto/1)

      %Organization.DescribeManyResponse{
        organizations: organizations
      }
    end)
  end

  @spec fetch_organization_contacts(
          Organization.FetchOrganizationContactsRequest.t(),
          GRPC.Server.Stream.t()
        ) ::
          Organization.FetchOrganizationContactsResponse.t()
  def fetch_organization_contacts(%{org_id: org_id} = request, _stream) do
    Logger.debug("fetch_organization_contacts request: #{inspect(request)}")

    observe("fetch_organization_contacts", fn ->
      case fetch_organization(org_id, "") do
        {:ok, organization} ->
          organization = Guard.FrontRepo.preload(organization, :contacts)

          %Organization.FetchOrganizationContactsResponse{
            org_contacts: organization.contacts |> Enum.map(&contact_to_proto/1)
          }

        {:error, {:not_found, msg}} ->
          grpc_error!(:not_found, msg)
      end
    end)
  end

  @spec modify_organization_contact(
          Organization.ModifyOrganizationContactRequest.t(),
          GRPC.Server.Stream.t()
        ) ::
          Organization.ModifyOrganizationContactResponse.t()
  def modify_organization_contact(%{org_contact: contact} = request, _stream) do
    Logger.debug("modify_organization_contact request: #{inspect(request)}")

    observe("modify_organization_contact", fn ->
      case fetch_organization(contact.org_id, "") do
        {:ok, organization} ->
          contact_params = %{
            contact_type: Organization.OrganizationContact.ContactType.key(contact.type),
            name: contact.name,
            email: contact.email,
            phone: contact.phone
          }

          case Guard.Store.Organization.modify_contact(organization, contact_params) do
            {:ok, _} ->
              %Organization.ModifyOrganizationContactResponse{}

            {:error, {:invalid_params, changeset}} ->
              errors =
                Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
                |> Enum.map_join(", ", fn {key, msgs} -> "#{key}: #{Enum.join(msgs, ", ")}" end)

              grpc_error!(:invalid_argument, "Invalid contact parameters: #{errors}")
          end

        {:error, {:not_found, msg}} ->
          grpc_error!(:not_found, msg)
      end
    end)
  end

  @spec modify_organization_settings(
          Organization.ModifyOrganizationSettingsRequest.t(),
          GRPC.Server.Stream.t()
        ) ::
          Organization.ModifyOrganizationSettingsResponse.t()
  def modify_organization_settings(%{org_id: org_id, settings: settings} = request, _stream) do
    Logger.debug("modify_organization_settings request: #{inspect(request)}")

    observe("modify_organization_settings", fn ->
      case fetch_organization(org_id, "") do
        {:ok, organization} ->
          settings_map = Enum.into(settings, %{}, fn setting -> {setting.key, setting.value} end)

          case Guard.Store.Organization.modify_settings(organization, settings_map) do
            {:ok, updated_org} ->
              %Organization.ModifyOrganizationSettingsResponse{
                settings: Enum.map(updated_org.settings || %{}, &setting_to_proto/1)
              }

            {:error, {:invalid_params, changeset}} ->
              errors =
                Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
                |> Enum.map_join(", ", fn {key, msgs} -> "#{key}: #{Enum.join(msgs, ", ")}" end)

              grpc_error!(:invalid_argument, "Invalid settings parameters: #{errors}")
          end

        {:error, {:not_found, msg}} ->
          grpc_error!(:not_found, msg)
      end
    end)
  end

  @spec list_suspensions(Organization.ListSuspensionsRequest.t(), GRPC.Server.Stream.t()) ::
          Organization.ListSuspensionsResponse.t()
  def list_suspensions(%{org_id: org_id} = request, _stream) do
    Logger.debug("list_suspensions request: #{inspect(request)}")

    observe("list_suspensions", fn ->
      case fetch_organization(org_id, "") do
        {:ok, organization} ->
          suspensions =
            organization
            |> Guard.FrontRepo.preload(:active_suspensions)
            |> Map.get(:active_suspensions)
            |> Enum.map(&suspension_to_proto/1)

          %Organization.ListSuspensionsResponse{
            status: %Google.Rpc.Status{code: 0, message: ""},
            suspensions: suspensions
          }

        {:error, {:not_found, msg}} ->
          grpc_error!(:not_found, msg)
      end
    end)
  end

  @spec suspend(Organization.SuspendRequest.t(), GRPC.Server.Stream.t()) ::
          Organization.SuspendResponse.t()
  def suspend(%{org_id: org_id} = request, _stream) do
    Logger.debug("suspend request: #{inspect(request)}")

    observe("suspend", fn ->
      case fetch_organization(org_id, "") do
        {:ok, organization} ->
          params = %{
            reason: Organization.Suspension.Reason.key(request.reason),
            origin: request.origin,
            description: request.description
          }

          case Guard.Store.Organization.add_suspension(organization, params) do
            {:ok, suspension} ->
              Guard.Events.OrganizationBlocked.publish(
                organization.id,
                suspension.reason
              )

              Guard.Events.OrganizationSuspensionCreated.publish(
                organization.id,
                suspension.reason
              )

              %Organization.SuspendResponse{
                status: %Google.Rpc.Status{code: 0, message: ""}
              }

            {:error, changeset} ->
              grpc_error!(
                :invalid_argument,
                "Invalid suspension parameters: #{inspect(changeset.errors)}"
              )
          end

        {:error, {:not_found, msg}} ->
          grpc_error!(:not_found, msg)
      end
    end)
  end

  @spec unsuspend(Organization.UnsuspendRequest.t(), GRPC.Server.Stream.t()) ::
          Organization.UnsuspendResponse.t()
  def unsuspend(%{org_id: org_id} = request, _) do
    Logger.debug("unsuspend request: #{inspect(request)}")

    observe("unsuspend", fn ->
      case fetch_organization(org_id, "") do
        {:ok, organization} ->
          reason = Organization.Suspension.Reason.key(request.reason)

          case Guard.Store.Organization.remove_suspension(organization, reason) do
            {:ok, suspension} ->
              {:ok, organization} = Guard.Store.Organization.get_by_id(organization.id)

              Guard.Events.OrganizationSuspensionRemoved.publish(
                organization.id,
                suspension.reason
              )

              unless organization.suspended do
                Guard.Events.OrganizationUnblocked.publish(organization.id)
              end

              %Organization.UnsuspendResponse{
                status: %Google.Rpc.Status{code: 0, message: ""}
              }

            {:error, :suspension_not_found} ->
              %Organization.UnsuspendResponse{
                status: %Google.Rpc.Status{code: 0, message: ""}
              }

            {:error, changeset} ->
              grpc_error!(
                :invalid_argument,
                "Invalid suspension parameters: #{inspect(changeset.errors)}"
              )
          end

        {:error, {:not_found, msg}} ->
          grpc_error!(:not_found, msg)
      end
    end)
  end

  @spec is_valid(Organization.Organization.t(), GRPC.Server.Stream.t()) ::
          Organization.IsValidResponse.t()
  # credo:disable-for-next-line
  def is_valid(request, _) do
    Logger.debug("is_valid request: #{inspect(request)}")

    observe("is_valid", fn ->
      case Guard.Store.Organization.validate(%{
             name: request.name,
             username: request.org_username,
             creator_id: request.owner_id
           }) do
        :ok ->
          Organization.IsValidResponse.new(
            is_valid: true,
            errors: ""
          )

        {:error, errors} ->
          Organization.IsValidResponse.new(
            is_valid: false,
            errors: errors
          )
      end
    end)
  end

  @spec create(Organization.CreateRequest.t(), GRPC.Server.Stream.t()) ::
          Organization.CreateResponse.t()
  def create(request, _) do
    Logger.debug("create request: #{inspect(request)}")

    observe("create", fn ->
      case Guard.Store.Organization.create(%{
             name: request.organization_name,
             username: request.organization_username,
             creator_id: request.creator_id
           }) do
        {:ok, organization} ->
          Guard.Events.OrganizationCreated.publish(organization.id)

          %Organization.CreateResponse{
            status: %InternalApi.ResponseStatus{
              code: InternalApi.ResponseStatus.Code.value(:OK),
              message: ""
            },
            organization: org_to_proto(organization)
          }

        {:error, changeset} ->
          Logger.error(
            "Error while creating org req #{inspect(request)} errors: #{inspect(changeset.errors)}"
          )

          errors =
            Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
            |> Jason.encode!()

          grpc_error!(:invalid_argument, errors)
      end
    end)
  end

  @spec destroy(Organization.DestroyRequest.t(), GRPC.Server.Stream.t()) ::
          Google.Protobuf.Empty.t()
  def destroy(%{org_id: org_id} = request, _) do
    Logger.debug("destroy request: #{inspect(request)}")

    observe("destroy", fn ->
      case fetch_organization(org_id, "") do
        {:ok, organization} ->
          case Guard.Store.Organization.soft_destroy(organization) do
            {:ok, _} ->
              %Google.Protobuf.Empty{}

            {:error, changeset} ->
              Logger.error("Error while deleting org #{org_id}: #{inspect(changeset.errors)}")
              grpc_error!(:internal, "Error while deleting org: #{org_id}")
          end

        {:error, {:not_found, msg}} ->
          grpc_error!(:not_found, msg)
      end
    end)
  end

  @spec restore(Organization.RestoreRequest.t(), GRPC.Server.Stream.t()) ::
          Google.Protobuf.Empty.t()
  def restore(%{org_id: org_id} = request, _) do
    Logger.debug("restore request: #{inspect(request)}")

    observe("restore", fn ->
      case fetch_organization(org_id, "", soft_deleted: true) do
        {:ok, organization} ->
          case Guard.Store.Organization.restore(organization) do
            {:ok, _} ->
              %Google.Protobuf.Empty{}

            {:error, changeset} ->
              Logger.error("Error while restoring org #{org_id}: #{inspect(changeset.errors)}")
              grpc_error!(:internal, "Error while restoring org: #{org_id}")
          end

        {:error, {:not_found, msg}} ->
          grpc_error!(:not_found, msg)
      end
    end)
  end

  @spec update(Organization.UpdateRequest.t(), GRPC.Server.Stream.t()) ::
          Organization.UpdateResponse.t()
  def update(%{organization: proto_org} = request, _) do
    Logger.debug("update request: #{inspect(request)}")

    observe("update", fn ->
      case fetch_organization(proto_org.org_id, "") do
        {:ok, organization} ->
          attrs = %{
            name: proto_org.name,
            username: proto_org.org_username,
            deny_non_member_workflows: proto_org.deny_non_member_workflows,
            deny_member_workflows: proto_org.deny_member_workflows,
            ip_allow_list: Enum.join(proto_org.ip_allow_list, ",")
          }

          attrs =
            case proto_org.allowed_id_providers do
              [_head | _tail] ->
                Map.put(
                  attrs,
                  :allowed_id_providers,
                  Enum.join(proto_org.allowed_id_providers, ",")
                )

              _ ->
                attrs
            end

          case Guard.Store.Organization.update(organization, attrs) do
            {:ok, updated_org} ->
              %Organization.UpdateResponse{
                organization: org_to_proto(updated_org)
              }

            {:error, changeset} ->
              Logger.error(
                "Error while updating org req #{inspect(request)} errors: #{inspect(changeset.errors)}"
              )

              errors =
                Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
                |> Jason.encode!()

              grpc_error!(:invalid_argument, errors)
          end

        {:error, {:not_found, msg}} ->
          grpc_error!(:not_found, msg)
      end
    end)
  end

  @spec verify(Organization.VerifyRequest.t(), GRPC.Server.Stream.t()) ::
          Organization.Organization.t()
  def verify(%{org_id: org_id} = request, _) do
    Logger.debug("verify request: #{inspect(request)}")

    observe("verify", fn ->
      case fetch_organization(org_id, "") do
        {:ok, organization} ->
          case Guard.Store.Organization.verify(organization) do
            {:ok, organization} ->
              org_to_proto(organization)

            {:error, changeset} ->
              errors =
                Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
                |> Jason.encode!()

              grpc_error!(:invalid_argument, errors)
          end

        {:error, {:not_found, msg}} ->
          grpc_error!(:not_found, msg)
      end
    end)
  end

  @doc """
  Temporary method to cleanup legacy members table after user is removed from organization
  Will be removed after proper invitation system is implemented
  """
  @spec delete_member(Organization.DeleteMemberRequest.t(), GRPC.Server.Stream.t()) ::
          Organization.DeleteMemberResponse.t()
  def delete_member(%{org_id: org_id, membership_id: member_id, user_id: user_id} = request, _) do
    Logger.debug("delete_member request: #{inspect(request)}")

    observe("delete_member", fn ->
      case fetch_organization(org_id, "") do
        {:ok, _} ->
          Guard.Store.Members.cleanup(org_id, user_id, member_id)

          %Organization.DeleteMemberResponse{
            status: %Google.Rpc.Status{code: 0, message: ""}
          }

        {:error, {:not_found, msg}} ->
          grpc_error!(:not_found, msg)
      end
    end)
  end

  @spec fetch_organization(String.t(), String.t(), Keyword.t()) ::
          {:ok, FrontRepo.Organization.t()} | {:error, {:not_found, String.t()}}
  defp fetch_organization(id, username, opts \\ []) do
    cond do
      valid_uuid?(id) ->
        Guard.Store.Organization.get_by_id(id, opts)

      is_binary(username) and username != "" ->
        Guard.Store.Organization.get_by_username(username, opts)

      true ->
        {:error, {:not_found, "Invalid organization id or username"}}
    end
  end

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp org_to_proto(organization) do
    %Organization.Organization{
      name: organization.name,
      org_username: organization.username,
      created_at: grpc_timestamp(organization.created_at),
      avatar_url: avatar_url(organization.username),
      org_id: organization.id,
      owner_id: organization.creator_id,
      suspended: organization.suspended || false,
      open_source: organization.open_source || false,
      verified: organization.verified || false,
      restricted: organization.restricted || false,
      ip_allow_list: String.split(organization.ip_allow_list || "", ",", trim: true),
      allowed_id_providers:
        String.split(organization.allowed_id_providers || "", ",", trim: true),
      deny_member_workflows: organization.deny_member_workflows || false,
      deny_non_member_workflows: organization.deny_non_member_workflows || false,
      settings:
        (organization.settings || %{})
        |> Enum.map(fn {k, v} -> %Organization.OrganizationSetting{key: k, value: v} end)
    }
  end

  defp contact_to_proto(contact) do
    %Organization.OrganizationContact{
      org_id: contact.organization_id,
      type: Organization.OrganizationContact.ContactType.value(contact.contact_type),
      name: contact.name || "",
      email: contact.email || "",
      phone: contact.phone || ""
    }
  end

  defp setting_to_proto({key, value}) do
    %Organization.OrganizationSetting{key: key, value: value}
  end

  defp suspension_to_proto(suspension) do
    %Organization.Suspension{
      origin: suspension.origin,
      description: suspension.description,
      reason: Organization.Suspension.Reason.value(suspension.reason),
      created_at: grpc_timestamp(suspension.created_at)
    }
  end

  defp add_if_enabled(integrations, _type, false), do: integrations
  defp add_if_enabled(integrations, type, true), do: [type | integrations]

  defp avatar_url(username), do: "/projects/assets/images/org-#{String.first(username)}.svg"

  defp grpc_timestamp(nil), do: nil

  defp grpc_timestamp(%DateTime{} = value) do
    unix_timestamp =
      value
      |> DateTime.to_unix(:second)

    %Google.Protobuf.Timestamp{seconds: unix_timestamp, nanos: 0}
  end

  defp observe(name, f) do
    Watchman.benchmark("#{name}", fn ->
      try do
        Logger.debug("Service #{name} - Started")
        result = f.()
        Logger.debug("Service #{name} - Finished")
        Watchman.increment({name, ["OK"]})
        result
      rescue
        e ->
          Logger.error("Service #{name} - Exited with an error: #{inspect(e)}")
          Watchman.increment({name, ["ERROR"]})

          reraise e, __STACKTRACE__
      end
    end)
  end
end
