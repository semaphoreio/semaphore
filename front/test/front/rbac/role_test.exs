defmodule Front.RBAC.RoleTest do
  use ExUnit.Case, async: true
  @moduletag :rbac_roles
  @moduletag capture_log: true

  alias Front.RBAC.Role
  alias Role.Permission

  setup_all do
    org_id = UUID.uuid4()

    roles = [
      %{id: UUID.uuid4(), name: "role1"},
      %{id: UUID.uuid4(), name: "role2"}
    ]

    maps_to_id = roles |> Enum.at(0) |> (& &1.id).()

    permissions = [
      %{id: UUID.uuid4(), name: "permission1"},
      %{id: UUID.uuid4(), name: "permission2"},
      %{id: UUID.uuid4(), name: "permission3"},
      %{id: UUID.uuid4(), name: "permission4"}
    ]

    extra_args = %{org_id: org_id, roles: roles, permissions: permissions}
    {:ok, %{extra_args: extra_args, maps_to_id: maps_to_id} |> Map.merge(extra_args)}
  end

  describe "new/2" do
    setup [:prepare_params]

    test "without parameters - creates an empty role", _ctx do
      assert %Role{} = role = Role.new()
      assert role.id == ""
      assert role.name == ""
      assert role.description == ""
      assert role.scope == nil
      assert role.maps_to == nil
      assert role.permissions == []
    end

    test "with parameters - creates a role with the given parameters", ctx do
      assert %Role{} = role = Role.new(ctx[:params])
      assert role.id == ctx.params.id
      assert role.name == ctx.params.name
      assert role.description == ctx.params.description
      assert role.scope == ctx.params.scope
      assert role.maps_to == ctx.params.maps_to
      assert MapSet.new(role.permissions) == MapSet.new(ctx.params.permissions, &Permission.new/1)
    end
  end

  describe "changeset/2" do
    setup [:prepare_params]

    test "with valid parameters - returns a valid changeset", ctx do
      assert %Ecto.Changeset{valid?: true} = changeset = Role.changeset(%Role{}, ctx.params)
      assert %Role{} = role = Ecto.Changeset.apply_changes(changeset)

      assert role.name == ctx.params.name
      assert role.description == ctx.params.description
      assert role.scope == ctx.params.scope
      assert role.maps_to == ctx.params.maps_to
      assert MapSet.new(role.permissions) == MapSet.new(ctx.params.permissions, &Permission.new/1)
    end

    test "with empty name - returns an invalid changeset", ctx do
      assert %Ecto.Changeset{valid?: false, errors: errors} =
               Role.changeset(%Role{}, %{ctx.params | name: ""})

      assert [name: {"can't be blank", [validation: :required]}] = errors
    end

    test "with name above 255 characters - returns an invalid changeset", ctx do
      assert %Ecto.Changeset{valid?: false, errors: errors} =
               Role.changeset(%Role{}, %{ctx.params | name: String.duplicate("a", 256)})

      assert [
               name:
                 {"should be at most %{count} character(s)",
                  [count: 255, validation: :length, kind: :max, type: :string]}
             ] = errors
    end

    test "with duplicate name - returns an invalid changeset", ctx do
      assert %Ecto.Changeset{valid?: false, errors: errors} =
               Role.changeset(%Role{id: UUID.uuid4(), name: "role1"}, ctx.params,
                 used_names: ["custom_role"]
               )

      assert [name: {"has already been taken", [{:validation, :exclusion} | _]}] = errors
    end

    test "with empty description - returns a valid changeset", ctx do
      assert %Ecto.Changeset{valid?: true} =
               Role.changeset(%Role{}, %{ctx.params | description: ""})
    end

    test "with invalid scope - returns an invalid changeset", ctx do
      assert %Ecto.Changeset{valid?: false, errors: errors} =
               Role.changeset(%Role{}, %{ctx.params | scope: :insider})

      assert [scope: {"is invalid", [type: {:parameterized, _, _}, validation: :cast]}] = errors
    end

    test "with empty scope - returns an invalid changeset", ctx do
      assert %Ecto.Changeset{valid?: false, errors: errors} =
               Role.changeset(%Role{}, %{ctx.params | scope: nil})

      assert [scope: {"can't be blank", [validation: :required]}] = errors
    end

    test "with invalid maps_to - returns an invalid changeset", ctx do
      assert %Ecto.Changeset{valid?: false, errors: errors} =
               Role.changeset(%Role{}, %{ctx.params | maps_to: "invalid"})

      assert [maps_to: {"is invalid", [type: Ecto.UUID, validation: :cast]}] = errors
    end

    test "with empty maps_to - returns a valid changeset", ctx do
      assert %Ecto.Changeset{valid?: true} = Role.changeset(%Role{}, %{ctx.params | maps_to: nil})
    end

    test "with invalid permissions - returns an invalid changeset", ctx do
      assert %Ecto.Changeset{valid?: false, errors: errors} =
               Role.changeset(%Role{}, %{ctx.params | permissions: [1, 2, 3]})

      assert [permissions: {"is invalid", [validation: :embed, type: {:array, :map}]}] = errors
    end

    test "with empty permissions - returns a valid changeset", ctx do
      assert %Ecto.Changeset{valid?: true} =
               Role.changeset(%Role{}, %{ctx.params | permissions: []})
    end

    test "with valid permissions - returns a valid changeset", ctx do
      assert changeset = %Ecto.Changeset{valid?: true} = Role.changeset(%Role{}, ctx.params)
      assert role = Ecto.Changeset.apply_changes(changeset)
      refute Enum.any?(role.permissions, & &1.granted)
    end

    test "with default permissions - returns a changeset with granted default permissions", ctx do
      permissions = [
        %{id: UUID.uuid4(), name: "organization.view"},
        %{id: UUID.uuid4(), name: "project.view"} | ctx.params.permissions
      ]

      assert changeset = Role.changeset(%Role{}, %{ctx.params | permissions: permissions})
      assert changeset.valid?

      assert role = Ecto.Changeset.apply_changes(changeset)

      assert Enum.all?(role.permissions, fn permission ->
               case permission.name do
                 "organization.view" -> permission.granted
                 "project.view" -> permission.granted
                 _ -> not permission.granted
               end
             end)
    end
  end

  describe "from_api/1" do
    setup [:prepare_api_role]

    test "maps organization role to the model", ctx do
      assert %Role{scope: :organization} =
               Role.from_api(%{ctx.api_role | scope: :SCOPE_ORG}, ctx.permissions)
    end

    test "maps project role to the model", ctx do
      assert %Role{scope: :project} =
               Role.from_api(%{ctx.api_role | scope: :SCOPE_PROJECT}, ctx.permissions)
    end

    test "maps unspecified scope role to the model", ctx do
      assert %Role{scope: nil} =
               Role.from_api(%{ctx.api_role | scope: :SCOPE_UNSPECIFIED}, ctx.permissions)
    end

    test "maps fields to the model", ctx do
      assert %Role{} = role = Role.from_api(ctx.api_role, ctx.permissions)
      assert role.id == ctx.api_role.id
      assert role.name == ctx.api_role.name
      assert role.description == ctx.api_role.description
    end

    test "maps existing maps_to to the model", ctx do
      maps_to_id = ctx.api_role.maps_to.id
      assert %Role{maps_to: ^maps_to_id} = Role.from_api(ctx.api_role, ctx.permissions)
    end

    test "maps empty maps_to to the model", ctx do
      assert %Role{maps_to: nil} = Role.from_api(%{ctx.api_role | maps_to: nil}, ctx.permissions)
    end

    test "maps all permissions to the model", ctx do
      assert %Role{permissions: permissions} = Role.from_api(ctx.api_role, ctx.permissions)

      assert MapSet.new(ctx.permissions, &{&1.id, &1.name}) ==
               MapSet.new(permissions, &{&1.id, &1.name})

      refute Enum.empty?(permissions)
    end

    test "maps granted permissions accordingly", ctx do
      assert %Role{permissions: permissions} = Role.from_api(ctx.api_role, ctx.permissions)

      assert MapSet.new(ctx.api_role.rbac_permissions, &{&1.id, &1.name}) ==
               permissions |> Enum.filter(& &1.granted) |> MapSet.new(&{&1.id, &1.name})

      refute Enum.empty?(permissions)
    end

    test "maps non-granted permissions accordingly", ctx do
      assert %Role{permissions: permissions} = Role.from_api(ctx.api_role, ctx.permissions)

      all_permissions = MapSet.new(ctx.permissions, &{&1.id, &1.name})
      granted_permissions = MapSet.new(ctx.api_role.rbac_permissions, &{&1.id, &1.name})
      non_granted_permissions = MapSet.difference(all_permissions, granted_permissions)

      assert non_granted_permissions ==
               permissions |> Enum.reject(& &1.granted) |> MapSet.new(&{&1.id, &1.name})

      refute Enum.empty?(permissions)
    end

    test "grants default permissions", ctx do
      permissions = [
        %{id: UUID.uuid4(), name: "organization.view"},
        %{id: UUID.uuid4(), name: "project.view"} | ctx.permissions
      ]

      assert %Role{permissions: permissions} = Role.from_api(ctx.api_role, permissions)

      assert %{granted: true} = Enum.find(permissions, &(&1.name == "organization.view"))
      assert %{granted: true} = Enum.find(permissions, &(&1.name == "project.view"))
    end
  end

  describe "to_api/2" do
    setup [:prepare_model]

    test "maps fields to the API role", ctx do
      assert api_role = Role.to_api(%{ctx.model | scope: :organization}, ctx.extra_args)
      assert api_role.id == ctx.model.id
      assert api_role.name == ctx.model.name
      assert api_role.description == ctx.model.description
      assert api_role.org_id == ctx.extra_args.org_id
    end

    test "maps organization scope to the API scope", ctx do
      scope_value = InternalApi.RBAC.Scope.value(:SCOPE_ORG)

      assert %{scope: ^scope_value} =
               Role.to_api(%{ctx.model | scope: :organization}, ctx.extra_args)
    end

    test "maps project scope to the API scope", ctx do
      scope_value = InternalApi.RBAC.Scope.value(:SCOPE_PROJECT)
      assert %{scope: ^scope_value} = Role.to_api(%{ctx.model | scope: :project}, ctx.extra_args)
    end

    test "maps model with empty maps_to to the nil API role", ctx do
      assert %{maps_to: nil} = Role.to_api(%{ctx.model | maps_to: nil}, ctx.extra_args)
    end

    test "maps model with role_mapping set to false to the nil API role", ctx do
      assert %{maps_to: nil} = Role.to_api(%{ctx.model | role_mapping: false}, ctx.extra_args)
    end

    test "maps model with maps_to pointing to non-existing role to the nil API role", ctx do
      assert %{maps_to: nil} = Role.to_api(%{ctx.model | maps_to: UUID.uuid4()}, ctx.extra_args)
    end

    test "maps existing maps_to to the API role", %{maps_to_id: maps_to_id} = ctx do
      assert %{maps_to: %{id: ^maps_to_id}} = Role.to_api(ctx.model, ctx.extra_args)
    end

    test "maps permissions to the API role", ctx do
      assert api_role = Role.to_api(ctx.model, ctx.extra_args)

      assert ctx.model.permissions
             |> Enum.filter(& &1.granted)
             |> MapSet.new(&Map.take(&1, ~w(id name)a)) ==
               api_role.rbac_permissions |> MapSet.new(&Map.take(&1, ~w(id name)a))

      refute Enum.empty?(api_role.rbac_permissions)
    end

    test "ignores missing permissions", ctx do
      permissions = [
        Permission.new(
          id: UUID.uuid4(),
          name: "non-existing permission",
          granted: true
        )
        | ctx.model.permissions
      ]

      assert api_role = Role.to_api(%{ctx.model | permissions: permissions}, ctx.extra_args)

      refute "non-existing permission" in MapSet.new(api_role.rbac_permissions, & &1.name)
    end
  end

  defp prepare_params(ctx) do
    {:ok,
     %{
       params: %{
         id: UUID.uuid4(),
         name: "custom_role",
         description: "custom role description",
         scope: :organization,
         maps_to: ctx.maps_to_id,
         permissions: ctx.permissions |> Enum.take(2)
       }
     }}
  end

  defp prepare_api_role(ctx) do
    {:ok,
     %{
       api_role:
         Util.Proto.to_map!(
           InternalApi.RBAC.Role.new(
             id: UUID.uuid4(),
             name: "custom_role",
             description: "custom role description",
             scope: InternalApi.RBAC.Scope.value(:SCOPE_UNSPECIFIED),
             maps_to: InternalApi.RBAC.Role.new(id: ctx.maps_to_id),
             rbac_permissions:
               ctx.permissions |> Enum.take(2) |> Enum.map(&InternalApi.RBAC.Role.new/1)
           )
         )
     }}
  end

  defp prepare_model(ctx) do
    granted_permissions =
      ctx.permissions
      |> Enum.take(2)
      |> Stream.map(&Map.put(&1, :granted, true))
      |> Enum.map(&Permission.new/1)

    non_granted_permissions = ctx.permissions |> Enum.drop(2) |> Enum.map(&Permission.new/1)

    {:ok,
     %{
       model: %Role{
         id: UUID.uuid4(),
         name: "custom_role",
         description: "custom role description",
         scope: :organization,
         role_mapping: true,
         maps_to: ctx.maps_to_id,
         permissions: granted_permissions ++ non_granted_permissions
       }
     }}
  end
end
