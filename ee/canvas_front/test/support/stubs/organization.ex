defmodule Support.Stubs.Organization do
  alias InternalApi.Organization.Organization
  alias InternalApi.Organization.Suspension
  alias Support.Stubs.DB
  require Logger

  def default_org_id, do: "92be62c2-9cf4-4dad-b168-d6efa6aa5e21"

  def init do
    Logger.info("organization api init")
    DB.add_table(:organizations, [:id, :name, :api_model])
    DB.add_table(:organization_contacts, [:id, :org_id, :type, :name])
    DB.add_table(:suspensions, [:id, :organization_id, :api_model])
    DB.add_table(:organization_repo_integrators, [:id, :types])
    Logger.info("organization api init done")
  end

  def create_default(params \\ []) do
    constant = [
      org_id: default_org_id()
    ]

    params |> Keyword.merge(constant) |> create()
  end

  def default do
    DB.find(:organizations, default_org_id())
  end

  def create(params \\ []) do
    name = params[:name] || "RT1"

    name_hash =
      :crypto.hash(:sha256, "#{name}@semaphoreci.com")
      |> Base.encode16(case: :lower)

    default = [
      org_id: Ecto.UUID.generate(),
      name: name,
      org_username: "rt1",
      avatar_url: "https://www.gravatar.com/avatar/#{name_hash}?d=identicon&size=32",
      created_at: %Google.Protobuf.Timestamp{seconds: 1_522_495_543},
      open_source: false,
      restricted: true,
      ip_allow_list: [],
      deny_member_workflows: false,
      deny_non_member_workflows: false,
      settings: []
    ]

    api_model = default |> Keyword.merge(params) |> then(&struct(Organization, &1))

    DB.insert(:organizations, %{
      id: api_model.org_id,
      name: api_model.name,
      api_model: api_model
    })

    # Add default repository integrators (all three types)
    DB.insert(:organization_repo_integrators, %{
      id: api_model.org_id,
      types:
        [:GITHUB_OAUTH_TOKEN, :GITHUB_APP, :BITBUCKET, :GITLAB]
        |> Enum.map(&InternalApi.RepositoryIntegrator.IntegrationType.value/1)
    })

    %{id: api_model.org_id, name: api_model.name, api_model: api_model}
  end

  def suspend(org, params \\ []) do
    default = [
      origin: "Automatic/Billing",
      description: "Trial expired",
      reason: :INSUFFICIENT_FUNDS,
      created_at: %Google.Protobuf.Timestamp{seconds: 1_522_495_543}
    ]

    api_model = default |> Keyword.merge(params) |> then(&struct(Suspension, &1))

    DB.insert(:suspensions, %{
      id: Ecto.UUID.generate(),
      organization_id: org.id,
      api_model: api_model
    })
  end

  def put_settings(org, settings) do
    alias InternalApi.Organization.OrganizationSetting, as: Setting
    settings = Enum.into(settings, [], &%Setting{key: elem(&1, 0), value: elem(&1, 1)})
    new_org = Map.merge(org.api_model, %{settings: settings})

    DB.update(:organizations, %{
      id: org.id,
      name: org.name,
      api_model: new_org
    })
  end

  defmodule Grpc do
    alias InternalApi.Organization.{
      AddMemberResponse,
      AddMembersResponse,
      CreateResponse,
      DeleteMemberResponse,
      DescribeResponse,
      IsValidResponse,
      ListResponse,
      ListSuspensionsResponse,
      MembersResponse,
      RepositoryIntegratorsResponse,
      UpdateResponse
    }

    alias Support.Stubs.DB

    use GRPC.Server, service: InternalApi.Organization.OrganizationService.Service

    def destroy(_, _) do
      %Google.Protobuf.Empty{}
    end

    def describe(req, _) do
      org = DB.find(:organizations, req.org_id)

      if req.include_quotas do
        %DescribeResponse{
          status: ok(),
          organization: %InternalApi.Organization.Organization{
            org_username: org.api_model.org_username,
            name: org.api_model.name,
            org_id: org.api_model.org_id,
            created_at: %Google.Protobuf.Timestamp{seconds: 1_522_495_543},
            deny_member_workflows: org.api_model.deny_member_workflows,
            deny_non_member_workflows: org.api_model.deny_non_member_workflows
          }
        }
      else
        %DescribeResponse{
          status: ok(),
          organization: org.api_model
        }
      end
    rescue
      _ ->
        %DescribeResponse{status: bad_param()}
    end

    def describe_many(req, _) do
      orgs = DB.find_many(:organizations, req.org_ids)

      %InternalApi.Organization.DescribeManyResponse{
        organizations: Enum.map(orgs, & &1.api_model)
      }
    rescue
      _ ->
        raise %GRPC.RPCError{status: GRPC.Status.invalid_argument(), message: "Bad request"}
    end

    def update(req, _) do
      org = DB.find(:organizations, req.organization.org_id)

      new_org =
        Map.merge(org.api_model, %{
          name: req.organization.name,
          org_username: req.organization.org_username,
          ip_allow_list: req.organization.ip_allow_list,
          deny_member_workflows: req.organization.deny_member_workflows,
          deny_non_member_workflows: req.organization.deny_non_member_workflows
        })

      updated =
        DB.update(:organizations, %{
          id: req.organization.org_id,
          name: req.organization.name,
          api_model: new_org
        })

      %UpdateResponse{organization: updated.api_model}
    rescue
      _ ->
        raise %GRPC.RPCError{message: "Error", status: GRPC.Status.invalid_argument()}
    end

    def list(_req, _) do
      orgs =
        DB.all(:organizations)
        |> Enum.map(fn o -> o.api_model end)

      %ListResponse{status: ok(), organizations: orgs}
    end

    def is_valid(req, _) do
      username = req.org_username

      org_usernames =
        DB.all(:organizations)
        |> Enum.map(fn o -> o.api_model end)
        |> Enum.map(& &1.org_username)

      (username in org_usernames)
      |> case do
        true ->
          %IsValidResponse{
            is_valid: false,
            errors: "Organization name is already taken"
          }

        _ ->
          %IsValidResponse{is_valid: true}
      end
    end

    def create(req, _) do
      entry =
        Support.Stubs.Organization.create(
          name: req.organization_name,
          org_username: req.organization_username,
          owner_id: req.creator_id
        )

      Support.Stubs.RBAC.add_member(entry.api_model.org_id, entry.api_model.owner_id, nil)

      %CreateResponse{
        status: %InternalApi.ResponseStatus{code: :OK},
        organization: entry.api_model
      }
    end

    def list_suspensions(req, _) do
      suspensions = DB.find_all_by(:suspensions, :organization_id, req.org_id)

      %ListSuspensionsResponse{
        status: %Google.Rpc.Status{code: :OK},
        suspensions: Enum.map(suspensions, fn s -> s.api_model end)
      }
    end

    def members(req, _) do
      users =
        DB.all(:users)
        |> Enum.filter(fn user ->
          if req.name_contains != "" do
            String.starts_with?(
              String.downcase(user.api_model.name),
              String.downcase(req.name_contains)
            )
          else
            true
          end
        end)

      %MembersResponse{
        status: ok(),
        members:
          Enum.map(users, fn user ->
            %InternalApi.Organization.Member{
              screen_name: user.api_model.name,
              avatar_url: user.api_model.avatar_url,
              user_id: user.api_model.user_id,
              github_username: user.api_model.github_login,
              membership_id: Ecto.UUID.generate()
            }
          end),
        not_logged_in_members: []
      }
    end

    def delete_member(_req, _) do
      %DeleteMemberResponse{status: %Google.Rpc.Status{code: :OK}}
    end

    def add_members(_req, _) do
      %AddMembersResponse{
        members: [%InternalApi.Organization.Member{screen_name: "example_screen_name"}]
      }
    end

    def add_member(_req, _) do
      %AddMemberResponse{
        member: %InternalApi.Organization.Member{screen_name: "example_screen_name"},
        status: %Google.Rpc.Status{code: :OK}
      }
    end

    def fetch_organization_contacts(req, _) do
      alias InternalApi.Organization.FetchOrganizationContactsResponse
      alias InternalApi.Organization.OrganizationContact

      contacts = DB.find_all_by(:organization_contacts, :org_id, req.org_id)

      %FetchOrganizationContactsResponse{
        org_contacts:
          Enum.map(
            contacts,
            &%OrganizationContact{
              org_id: &1.org_id,
              type: &1.type |> String.to_atom(),
              name: &1.name
            }
          )
      }
    end

    def modify_organization_contact(req, _) do
      alias InternalApi.Organization.OrganizationContact

      DB.insert(:organization_contacts, %{
        id: Support.Stubs.UUID.gen(),
        org_id: req.org_contact.org_id,
        type: req.org_contact.type |> String.to_atom(),
        name: req.org_contact.name
      })

      %InternalApi.Organization.ModifyOrganizationContactResponse{}
    end

    def fetch_organization_settings(req, _) do
      alias InternalApi.Organization.FetchOrganizationSettingsResponse
      org = DB.find(:organizations, req.org_id)
      settings = (org && org.api_model.settings) || []
      %FetchOrganizationSettingsResponse{settings: settings}
    end

    def modify_organization_settings(req, _) do
      alias InternalApi.Organization.ModifyOrganizationSettingsResponse
      alias InternalApi.Organization.OrganizationSetting, as: Setting

      org = DB.find(:organizations, req.org_id)
      old_settings = Map.new((org && org.api_model.settings) || [], &{&1.key, &1.value})
      new_settings = Map.new(req.settings, &{&1.key, &1.value})

      settings =
        old_settings
        |> Map.merge(new_settings)
        |> Enum.reject(fn {_, v} -> v == "" end)
        |> Enum.into([], &%Setting{key: elem(&1, 0), value: elem(&1, 1)})

      new_org = Map.merge(org.api_model, %{settings: settings})

      DB.update(:organizations, %{id: org.id, name: org.name, api_model: new_org})
      %ModifyOrganizationSettingsResponse{settings: new_org.settings}
    end

    def repository_integrators(req, _) do
      case DB.find(:organization_repo_integrators, req.org_id) do
        nil ->
          available = []
          %RepositoryIntegratorsResponse{primary: nil, enabled: available}

        record ->
          %RepositoryIntegratorsResponse{
            primary: List.first(record.types),
            enabled: record.types
          }
      end
    end

    defp ok do
      %InternalApi.ResponseStatus{code: :OK}
    end

    defp bad_param do
      %InternalApi.ResponseStatus{code: :BAD_PARAM}
    end
  end
end
