defmodule Support.Stubs.Groups do
  alias Support.Stubs.{
    DB,
    Feature,
    UUID,
    RBAC
  }

  require Logger

  @default_org_id "92be62c2-9cf4-4dad-b168-d6efa6aa5e21"
  @default_user_id "78114608-be8a-465a-b9cd-81970fb802c5"

  def init do
    DB.add_table(:groups, [
      :id,
      :name,
      :description,
      :org_id,
      :member_ids
    ])

    seed_data()
    __MODULE__.Grpc.init()
  end

  def seed_data do
    # Insert default groups
    default_groups = [
      %{
        name: "Mighty group",
        description: "A group for mighty members",
        member_ids: [@default_user_id]
      },
      %{
        name: "Amazing group",
        description: "A group for magical members",
        member_ids: [@default_user_id]
      },
      %{
        name: "Secret group",
        description: "A group for secretive members",
        member_ids: [@default_user_id]
      }
    ]

    Enum.each(default_groups, fn group ->
      id = UUID.gen()

      DB.insert(:groups, %{
        id: id,
        name: group.name,
        description: group.description,
        org_id: @default_org_id,
        member_ids: group.member_ids
      })

      RBAC.add_group(@default_org_id, group.name, id)
    end)

    # Enable groups feature for default org
    Feature.enable_feature(@default_org_id, "rbac__groups")
  end

  defmodule Grpc do
    def init do
      GrpcMock.stub(GroupsMock, :list_groups, &__MODULE__.list_groups/2)
      GrpcMock.stub(GroupsMock, :create_group, &__MODULE__.create_group/2)
      GrpcMock.stub(GroupsMock, :destroy_group, &__MODULE__.destroy_group/2)
      GrpcMock.stub(GroupsMock, :modify_group, &__MODULE__.modify_group/2)
    end

    def list_groups(req, _) do
      groups =
        if req.group_id != "" do
          # Get a specific group by ID
          case DB.find_by(:groups, :id, req.group_id) do
            nil -> []
            group -> [group]
          end
        else
          # Get all groups for the organization
          DB.find_all_by(:groups, :org_id, req.org_id)
        end

      # Extract pagination parameters with proper defaults
      page_size =
        case req.page do
          nil -> 10
          # Return all results when page_size is 0
          page when page.page_size <= 0 -> length(groups)
          page -> page.page_size
        end

      page_no =
        case req.page do
          nil -> 1
          # Default to page 1 when page_no is 0
          page when page.page_no <= 0 -> 1
          page -> page.page_no
        end

      total_count = length(groups)
      total_pages = if page_size == 0, do: 1, else: max(1, ceil(total_count / page_size))

      # Apply pagination only if page_size > 0
      paged_groups =
        if page_size > 0 do
          groups
          |> Enum.drop((page_no - 1) * page_size)
          |> Enum.take(page_size)
        else
          # Return all groups if page_size is 0
          groups
        end

      group_models = Enum.map(paged_groups, &to_group_model/1)

      %InternalApi.Groups.ListGroupsResponse{
        groups: group_models,
        total_pages: total_pages
      }
    end

    def create_group(req, _) do
      new_group = %{
        id: UUID.gen(),
        name: req.group.name,
        description: req.group.description,
        org_id: req.org_id,
        member_ids: req.group.member_ids
      }

      created_group = DB.insert(:groups, new_group)

      # Assign RBAC role bindings for each member in the group
      RBAC.add_group(created_group.org_id, new_group.name, new_group.id)

      %InternalApi.Groups.CreateGroupResponse{
        group: to_group_model(created_group)
      }
    end

    def destroy_group(req, _) do
      group = DB.find_by(:groups, :id, req.group_id)

      if group do
        DB.delete(:groups, group.id)
        # Here we might want to also clean up RBAC bindings, but that's not implemented yet
        %InternalApi.Groups.DestroyGroupResponse{}
      else
        raise(GRPC.RPCError, status: GRPC.Status.not_found(), message: "Group not found")
      end
    end

    def modify_group(req, _) do
      group = DB.find_by(:groups, :id, req.group.id)

      if group do
        # Ensure member_ids is always a list
        current_members = group.member_ids || []

        # Make sure members_to_add and members_to_remove are lists
        members_to_add = ensure_list(req.members_to_add)
        members_to_remove = ensure_list(req.members_to_remove)

        # Calculate new member list safely
        new_member_ids = update_member_ids(current_members, members_to_add, members_to_remove)

        # Apply changes to the group
        updated_group = %{
          id: group.id,
          name: req.group.name || group.name,
          description: req.group.description || group.description,
          org_id: group.org_id,
          member_ids: new_member_ids
        }

        DB.update(:groups, updated_group)
        updated = DB.find_by(:groups, :id, group.id)

        Logger.info("updated group: #{inspect(updated)}")

        %InternalApi.Groups.ModifyGroupResponse{
          group: to_group_model(updated)
        }
      else
        raise(GRPC.RPCError, status: GRPC.Status.not_found(), message: "Group not found")
      end
    end

    ###
    ### Helpers
    ###

    # Helper to ensure a value is a list
    defp ensure_list(nil), do: []
    defp ensure_list(value) when is_list(value), do: value
    defp ensure_list(value), do: [value]

    defp update_member_ids(current_members, members_to_add, members_to_remove) do
      # Ensure all parameters are lists
      current = ensure_list(current_members)
      to_add = ensure_list(members_to_add)
      to_remove = ensure_list(members_to_remove)

      current
      |> Enum.reject(fn member -> Enum.member?(to_remove, member) end)
      |> Enum.concat(to_add)
      |> Enum.uniq()
    end

    defp to_group_model(group) do
      %InternalApi.Groups.Group{
        id: group.id,
        name: group.name,
        description: group.description,
        member_ids: group.member_ids || []
      }
    end
  end
end
