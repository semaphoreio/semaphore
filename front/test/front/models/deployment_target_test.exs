# credo:disable-for-this-file Credo.Check.Design.DuplicatedCode
defmodule Front.Models.DeploymentTargetTest do
  use ExUnit.Case, async: true
  @moduletag capture_log: true
  @moduletag :deployments

  alias Front.Models.DeploymentsError
  alias Front.Models.DeploymentTarget, as: Target
  alias InternalApi.Gofer.DeploymentTargets, as: API

  setup_all [
    :prepare_params,
    :prepare_api_target,
    :prepare_api_secret_data,
    :prepare_model,
    :prepare_extra_params
  ]

  describe "new/1" do
    test "without any values returns the empty target" do
      assert target = %Target{} = Target.new()

      for field <- ~w(id name description url)a,
          do: assert("" == target |> Map.get(field))

      for field <- ~w(bookmark_parameter1 bookmark_parameter2 bookmark_parameter3)a,
          do: assert("" == target |> Map.get(field))

      for field <- ~w(branch_mode tag_mode)a,
          do: assert("all" == target |> Map.get(field))

      for field <- ~w(roles members env_vars files branches tags)a,
          do: assert([] == target |> Map.get(field))
    end
  end

  describe "EnvVar.changeset/2" do
    test "with all data returns is valid" do
      params = %{"id" => "name", "name" => "name", "value" => "value", "md5" => "md5"}
      assert changeset = %Ecto.Changeset{valid?: true} = changeset_for(Target.EnvVar, params)

      assert %Target.EnvVar{id: "name", name: "name", value: "value", md5: "md5"} =
               Ecto.Changeset.apply_changes(changeset)
    end

    test "without name is invalid" do
      params = %{"id" => "name", "name" => "", "value" => "value", "md5" => "md5"}
      assert changeset = %Ecto.Changeset{valid?: false} = changeset_for(Target.EnvVar, params)
      assert [name: {"can't be blank", _}] = changeset.errors
    end

    test "with id, name and md5 is valid" do
      params = %{"id" => "name", "name" => "name", "value" => "value", "md5" => "md5"}
      assert %Ecto.Changeset{valid?: true} = changeset_for(Target.EnvVar, params)
    end

    test "with id, name and value is valid" do
      params = %{"id" => "name", "name" => "name", "value" => "value", "md5" => ""}
      assert %Ecto.Changeset{valid?: true} = changeset_for(Target.EnvVar, params)
    end

    test "with id, name and without value or md5 is invalid" do
      params = %{"id" => "name", "name" => "name", "value" => "", "md5" => ""}
      assert changeset = %Ecto.Changeset{valid?: false} = changeset_for(Target.EnvVar, params)
      assert [value: {"can't be blank", _}] = changeset.errors
    end

    test "without id and value is invalid" do
      params = %{"id" => "", "name" => "name", "value" => "", "md5" => "md5"}
      assert changeset = %Ecto.Changeset{valid?: false} = changeset_for(Target.EnvVar, params)
      assert [id: {"can't be blank", _}] = changeset.errors
    end

    test "without id and md5 is valid" do
      params = %{"id" => "", "name" => "name", "value" => "value", "md5" => ""}
      assert %Ecto.Changeset{valid?: true} = changeset_for(Target.EnvVar, params)
    end

    test "without id, value and md5 is invalid" do
      params = %{"id" => "", "name" => "name", "value" => "", "md5" => ""}
      assert changeset = %Ecto.Changeset{valid?: false} = changeset_for(Target.EnvVar, params)
      assert [value: {"can't be blank", _}] = changeset.errors
    end
  end

  describe "File.changeset/2" do
    test "with all data returns is valid" do
      params = %{"id" => "path", "path" => "path", "content" => "content", "md5" => "md5"}
      assert changeset = %Ecto.Changeset{valid?: true} = changeset_for(Target.File, params)

      assert %Target.File{id: "path", path: "path", content: "content", md5: "md5"} =
               Ecto.Changeset.apply_changes(changeset)
    end

    test "without path is invalid" do
      params = %{"id" => "path", "path" => "", "content" => "content", "md5" => "md5"}
      assert changeset = %Ecto.Changeset{valid?: false} = changeset_for(Target.File, params)
      assert [path: {"can't be blank", _}] = changeset.errors
    end

    test "with id, path and md5 is valid" do
      params = %{"id" => "path", "path" => "path", "content" => "content", "md5" => "md5"}
      assert %Ecto.Changeset{valid?: true} = changeset_for(Target.File, params)
    end

    test "with id, path and content is valid" do
      params = %{"id" => "path", "path" => "path", "content" => "content", "md5" => ""}
      assert %Ecto.Changeset{valid?: true} = changeset_for(Target.File, params)
    end

    test "with id, path and without content or md5 is invalid" do
      params = %{"id" => "path", "path" => "path", "content" => "", "md5" => ""}
      assert changeset = %Ecto.Changeset{valid?: false} = changeset_for(Target.File, params)
      assert [content: {"can't be blank", _}] = changeset.errors
    end

    test "without id and content is invalid" do
      params = %{"id" => "", "path" => "path", "content" => "", "md5" => "md5"}
      assert changeset = %Ecto.Changeset{valid?: false} = changeset_for(Target.File, params)
      assert [id: {"can't be blank", _}] = changeset.errors
    end

    test "without id and md5 is valid" do
      params = %{"id" => "", "path" => "path", "content" => "content", "md5" => ""}
      assert %Ecto.Changeset{valid?: true} = changeset_for(Target.File, params)
    end

    test "without id, content and md5 is invalid" do
      params = %{"id" => "", "path" => "path", "content" => "", "md5" => ""}
      assert changeset = %Ecto.Changeset{valid?: false} = changeset_for(Target.File, params)
      assert [content: {"can't be blank", _}] = changeset.errors
    end
  end

  describe "ObjectItem.changeset/2" do
    test "without match_mode is invalid" do
      params = %{"match_mode" => "", "pattern" => "foo"}
      assert changeset = %Ecto.Changeset{valid?: false} = changeset_for(Target.ObjectItem, params)
      assert [match_mode: {"can't be blank", _}] = changeset.errors
    end

    test "with unknown match_mode is invalid" do
      params = %{"match_mode" => "0", "pattern" => "foo"}
      assert changeset = %Ecto.Changeset{valid?: false} = changeset_for(Target.ObjectItem, params)
      assert [match_mode: {"is invalid", _}] = changeset.errors
    end

    test "with exact match_mode and no pattern is invalid" do
      params = %{"match_mode" => "1", "pattern" => ""}
      assert changeset = %Ecto.Changeset{valid?: false} = changeset_for(Target.ObjectItem, params)
      assert [pattern: {"can't be blank", _}] = changeset.errors
    end

    test "with exact match_mode and some pattern is valid" do
      params = %{"match_mode" => 1, "pattern" => "master"}
      assert changeset = %Ecto.Changeset{valid?: true} = changeset_for(Target.ObjectItem, params)

      assert %Target.ObjectItem{match_mode: 1, pattern: "master"} =
               Ecto.Changeset.apply_changes(changeset)
    end

    test "with regex match_mode and no pattern is invalid" do
      params = %{"match_mode" => "2", "pattern" => ""}
      assert changeset = %Ecto.Changeset{valid?: false} = changeset_for(Target.ObjectItem, params)
      assert [pattern: {"can't be blank", _}] = changeset.errors
    end

    test "with regex match_mode and invalid regex pattern is invalid" do
      params = %{"match_mode" => "2", "pattern" => "release/["}
      assert changeset = %Ecto.Changeset{valid?: false} = changeset_for(Target.ObjectItem, params)
      assert [pattern: {"must be regex", _}] = changeset.errors
    end

    test "with regex match_mode and some pattern is valid" do
      params = %{"match_mode" => "2", "pattern" => "release\/.*"}
      assert changeset = %Ecto.Changeset{valid?: true} = changeset_for(Target.ObjectItem, params)

      assert %Target.ObjectItem{match_mode: 2, pattern: "release\/.*"} =
               Ecto.Changeset.apply_changes(changeset)
    end
  end

  describe "DeploymentTarget.changeset/2" do
    test "when all params are provided then changeset is valid", ctx do
      assert changeset = %Ecto.Changeset{valid?: true} = changeset_for(Target, ctx.params)
      assert target = %Target{} = Ecto.Changeset.apply_changes(changeset)

      for field <- ~w(name description url roles members branch_mode tag_mode)a do
        assert Map.get(target, field) == Ecto.Changeset.get_change(changeset, field)
      end

      assert collection_from_params(ctx.params, :env_vars) == MapSet.new(target.env_vars)
      assert collection_from_params(ctx.params, :files) == MapSet.new(target.files)
      assert collection_from_params(ctx.params, :branches) == MapSet.new(target.branches)
      assert collection_from_params(ctx.params, :tags) == MapSet.new(target.tags)
    end

    test "when required params are not provided then changeset is invalid", ctx do
      for field <- ~w(name branch_mode tag_mode)a do
        params = Map.put(ctx.params, to_string(field), "")
        assert changeset = %Ecto.Changeset{valid?: false} = changeset_for(Target, params)
        assert [{^field, {"can't be blank", _}}] = changeset.errors
      end
    end

    test "when optional params are not provided then changeset is valid", ctx do
      for field <- ~w(description url)a do
        params = Map.put(ctx.params, to_string(field), "")
        assert changeset = %Ecto.Changeset{valid?: true} = changeset_for(Target, params)

        assert target = %Target{} = Ecto.Changeset.apply_changes(changeset)
        assert target |> Map.get(field) |> String.equivalent?("")
      end

      for field <- ~w(bookmark_parameter1 bookmark_parameter2 bookmark_parameter3)a do
        params = Map.put(ctx.params, to_string(field), "")
        assert changeset = %Ecto.Changeset{valid?: true} = changeset_for(Target, params)

        assert target = %Target{} = Ecto.Changeset.apply_changes(changeset)
        assert target |> Map.get(field) |> String.equivalent?("")
      end

      for field <- ~w(roles members)a do
        params = Map.put(ctx.params, to_string(field), [])
        assert changeset = %Ecto.Changeset{valid?: true} = changeset_for(Target, params)

        assert target = %Target{} = Ecto.Changeset.apply_changes(changeset)
        assert target |> Map.get(field) |> Enum.empty?()
      end
    end

    test "when name is too long then changeset is invalid", ctx do
      too_long_name = ["DeploymentTarget"] |> Stream.cycle() |> Enum.take(16) |> Enum.join()
      params = Map.put(ctx.params, "name", too_long_name)
      assert changeset = %Ecto.Changeset{valid?: false} = changeset_for(Target, params)

      assert [
               name:
                 {"should be at most %{count} character(s)",
                  [count: 255, validation: :length, kind: :max, type: :string]}
             ] = changeset.errors
    end

    test "when name is invalid then changeset is invalid", ctx do
      params = Map.put(ctx.params, "name", "Deployment Target")
      assert changeset = %Ecto.Changeset{valid?: false} = changeset_for(Target, params)

      assert [name: {"must contain only alphanumericals, dashes, underscores or dots", _}] =
               changeset.errors
    end

    test "when no env vars then changeset is valid", ctx do
      params = Map.put(ctx.params, "env_vars", %{})
      assert changeset = %Ecto.Changeset{valid?: true} = changeset_for(Target, params)

      assert target = %Target{} = Ecto.Changeset.apply_changes(changeset)
      assert Enum.empty?(target.env_vars)
    end

    test "when env vars are empty then changeset is invalid", ctx do
      env_vars = %{"0" => %{"id" => "", "name" => "", "value" => ""}}
      params = Map.put(ctx.params, "env_vars", env_vars)
      assert changeset = %Ecto.Changeset{valid?: false} = changeset_for(Target, params)

      assert %Ecto.Changeset{
               errors: [
                 value: {"can't be blank", _},
                 name: {"can't be blank", _}
               ]
             } = List.first(changeset.changes.env_vars)
    end

    test "when env vars are invalid then changeset is invalid", ctx do
      env_vars = %{"0" => %{"id" => "", "name" => "n", "value" => ""}}
      params = Map.put(ctx.params, "env_vars", env_vars)
      assert changeset = %Ecto.Changeset{valid?: false} = changeset_for(Target, params)

      assert %Ecto.Changeset{errors: [value: {"can't be blank", _}]} =
               List.first(changeset.changes.env_vars)
    end

    test "when no files then changeset is valid", ctx do
      params = Map.put(ctx.params, "files", %{})
      assert changeset = %Ecto.Changeset{valid?: true} = changeset_for(Target, params)

      assert target = %Target{} = Ecto.Changeset.apply_changes(changeset)
      assert Enum.empty?(target.files)
    end

    test "when files are empty then changeset is valid", ctx do
      files = %{"0" => %{"id" => "", "path" => "", "content" => ""}}
      params = Map.put(ctx.params, "files", files)
      assert changeset = %Ecto.Changeset{valid?: false} = changeset_for(Target, params)

      assert %Ecto.Changeset{
               errors: [
                 content: {"can't be blank", _},
                 path: {"can't be blank", _}
               ]
             } = List.first(changeset.changes.files)
    end

    test "when files are invalid then changeset is invalid", ctx do
      files = %{"0" => %{"id" => "", "path" => "", "content" => "ddd"}}
      params = Map.put(ctx.params, "files", files)
      assert changeset = %Ecto.Changeset{valid?: false} = changeset_for(Target, params)

      assert %Ecto.Changeset{errors: [path: {"can't be blank", _}]} =
               List.first(changeset.changes.files)
    end

    test "when branch mode is invalid then changeset is invalid", ctx do
      params = Map.put(ctx.params, "branch_mode", "gibberish")
      assert changeset = %Ecto.Changeset{valid?: false} = changeset_for(Target, params)
      assert [branch_mode: {"is invalid", _}] = changeset.errors
    end

    test "when tag mode is invalid then changeset is invalid", ctx do
      params = Map.put(ctx.params, "tag_mode", "gibberish")
      assert changeset = %Ecto.Changeset{valid?: false} = changeset_for(Target, params)
      assert [tag_mode: {"is invalid", _}] = changeset.errors
    end

    test "when branch mode is all then changeset is valid", ctx do
      params = Map.put(ctx.params, "branch_mode", "all")
      assert changeset = %Ecto.Changeset{valid?: true} = changeset_for(Target, params)

      assert target = %Target{} = Ecto.Changeset.apply_changes(changeset)
      assert Enum.empty?(target.branches)
    end

    test "when branch mode is none then changeset is valid", ctx do
      params = Map.put(ctx.params, "branch_mode", "none")
      assert changeset = %Ecto.Changeset{valid?: true} = changeset_for(Target, params)

      assert target = %Target{} = Ecto.Changeset.apply_changes(changeset)
      assert Enum.empty?(target.branches)
    end

    test "when branch mode whitelisted and non-empty branches then changeset is valid", ctx do
      branches = %{"0" => %{"match_mode" => "1", "pattern" => "master"}}
      params = Map.put(ctx.params, "branches", branches)
      assert changeset = %Ecto.Changeset{valid?: true} = changeset_for(Target, params)

      assert [%Target.ObjectItem{match_mode: 1, pattern: "master"}] =
               changeset |> Ecto.Changeset.apply_changes() |> Map.get(:branches)
    end

    test "when branch mode is whitelisted and no branches then changeset is invalid", ctx do
      params = Map.put(ctx.params, "branches", %{})
      assert changeset = %Ecto.Changeset{valid?: false} = changeset_for(Target, params)
      assert [branches: {"can't be blank", _}] = changeset.errors
    end

    test "when tag mode is all then changeset is valid", ctx do
      params = Map.put(ctx.params, "tag_mode", "all")
      assert changeset = %Ecto.Changeset{valid?: true} = changeset_for(Target, params)

      assert target = %Target{} = Ecto.Changeset.apply_changes(changeset)
      assert Enum.empty?(target.tags)
    end

    test "when tag mode is none then changeset is valid", ctx do
      params = Map.put(ctx.params, "tag_mode", "none")
      assert changeset = %Ecto.Changeset{valid?: true} = changeset_for(Target, params)

      assert target = %Target{} = Ecto.Changeset.apply_changes(changeset)
      assert Enum.empty?(target.tags)
    end

    test "when tag mode is whitelisted and no tags then changeset is invalid", ctx do
      params = Map.put(ctx.params, "tags", %{})
      assert changeset = %Ecto.Changeset{valid?: false} = changeset_for(Target, params)
      assert [tags: {"can't be blank", _}] = changeset.errors
    end

    test "when tag mode whitelisted and non-empty tags then changeset is valid", ctx do
      tags = %{"0" => %{"match_mode" => "1", "pattern" => "latest"}}
      params = Map.put(ctx.params, "tags", tags)
      assert %Ecto.Changeset{valid?: true} = changeset_for(Target, params)
    end
  end

  describe "from_api/2" do
    test "maps simple fields", ctx do
      assert target = %Target{} = Target.from_api(ctx.api_target, ctx.api_secret_data)

      assert target.name == ctx.api_target.name
      assert target.description == ctx.api_target.description
      assert target.url == ctx.api_target.url
      assert target.roles == [ctx.api_role_id]
      assert target.members == [ctx.api_user_id]
    end

    test "maps empty credentials", ctx do
      alias InternalApi.Secrethub.Secret
      api_secret_data = Util.Proto.to_map!(Secret.Data.new())
      assert target = %Target{} = Target.from_api(ctx.api_target, api_secret_data)

      assert [] = target.env_vars
      assert [] = target.files
    end

    test "maps non-empty credentials", ctx do
      assert target = %Target{} = Target.from_api(ctx.api_target, ctx.api_secret_data)

      to_env_var_model = &%Target.EnvVar{id: &1.name, name: &1.name, md5: md5_checksum(&1.value)}
      env_vars = Enum.map(ctx.api_secret_data.env_vars, to_env_var_model)

      to_file_model = &%Target.File{id: &1.path, path: &1.path, md5: md5_checksum(&1.content)}
      files = Enum.map(ctx.api_secret_data.files, to_file_model)

      assert ^env_vars = target.env_vars
      assert ^files = target.files
    end

    test "correctly maps any user access", ctx do
      api_target = %{
        ctx.api_target
        | subject_rules: [
            %{type: :ANY, subject_id: ""},
            %{type: :ROLE, subject_id: UUID.uuid4()},
            %{type: :USER, subject_id: UUID.uuid4()},
            %{type: :AUTO, subject_id: UUID.uuid4()}
          ]
      }

      assert target = Target.from_api(api_target, ctx.api_secret_data)
      assert "any" = target.user_access
      assert [] = target.roles
      assert [] = target.members
      refute target.auto_promotions
    end

    test "correctly maps roles", ctx do
      api_target = %{
        ctx.api_target
        | subject_rules: [
            %{type: :ROLE, subject_id: UUID.uuid4()},
            %{type: :ROLE, subject_id: UUID.uuid4()}
          ]
      }

      assert target = Target.from_api(api_target, ctx.api_secret_data)
      roles = MapSet.new(api_target.subject_rules, & &1.subject_id)
      assert ^roles = MapSet.new(target.roles)
      assert [] = target.members
      refute target.auto_promotions
    end

    test "correctly maps users", ctx do
      api_target = %{
        ctx.api_target
        | subject_rules: [
            %{type: :USER, subject_id: UUID.uuid4()},
            %{type: :USER, subject_id: UUID.uuid4()}
          ]
      }

      assert target = Target.from_api(api_target, ctx.api_secret_data)
      users = MapSet.new(api_target.subject_rules, & &1.subject_id)
      assert ^users = MapSet.new(target.members)
      assert [] = target.roles
      refute target.auto_promotions
    end

    test "correctly maps auto-promotions", ctx do
      api_target = %{
        ctx.api_target
        | subject_rules: [%{type: :AUTO, subject_id: ""}]
      }

      assert target = Target.from_api(api_target, ctx.api_secret_data)
      assert target.auto_promotions
    end

    test "maps empty subject rules", ctx do
      api_target = %{ctx.api_target | subject_rules: []}

      assert target = Target.from_api(api_target, ctx.api_secret_data)
      refute target.auto_promotions
      assert [] = target.roles
      assert [] = target.members
    end

    test "maps whitelisted branches", ctx do
      api_target = %{
        ctx.api_target
        | object_rules: [
            %{type: :BRANCH, match_mode: :EXACT, pattern: "master"},
            %{type: :BRANCH, match_mode: :REGEX, pattern: "feature/*"}
          ]
      }

      assert target = Target.from_api(api_target, ctx.api_secret_data)
      assert "whitelisted" = target.branch_mode
      assert "none" = target.tag_mode
      assert "none" = target.pr_mode

      assert [
               %Target.ObjectItem{match_mode: 1, pattern: "master"},
               %Target.ObjectItem{match_mode: 2, pattern: "feature/*"}
             ] = target.branches

      assert [] = target.tags
    end

    test "maps whitelisted tags", ctx do
      api_target = %{
        ctx.api_target
        | object_rules: [
            %{type: :TAG, match_mode: :EXACT, pattern: "latest"},
            %{type: :TAG, match_mode: :REGEX, pattern: "v1.0.*"}
          ]
      }

      assert target = Target.from_api(api_target, ctx.api_secret_data)
      assert "whitelisted" = target.tag_mode
      assert "none" = target.branch_mode
      assert "none" = target.pr_mode

      assert [
               %Target.ObjectItem{match_mode: 1, pattern: "latest"},
               %Target.ObjectItem{match_mode: 2, pattern: "v1.0.*"}
             ] = target.tags

      assert [] = target.branches
    end

    test "maps all branches", ctx do
      api_target = %{
        ctx.api_target
        | object_rules: [
            %{type: :BRANCH, match_mode: :ALL, pattern: ""},
            %{type: :BRANCH, match_mode: :EXACT, pattern: "master"},
            %{type: :BRANCH, match_mode: :REGEX, pattern: "feature/*"},
            %{type: :TAG, match_mode: :EXACT, pattern: "latest"}
          ]
      }

      assert target = Target.from_api(api_target, ctx.api_secret_data)
      assert "all" = target.branch_mode
      assert "whitelisted" = target.tag_mode
      assert "none" = target.pr_mode

      assert [%Target.ObjectItem{match_mode: 1, pattern: "latest"}] = target.tags
      assert [] = target.branches
    end

    test "maps all tags", ctx do
      api_target = %{
        ctx.api_target
        | object_rules: [
            %{type: :TAG, match_mode: :ALL, pattern: ""},
            %{type: :TAG, match_mode: :EXACT, pattern: "latest"},
            %{type: :TAG, match_mode: :REGEX, pattern: "v1.0.*"},
            %{type: :BRANCH, match_mode: :EXACT, pattern: "latest"}
          ]
      }

      assert target = Target.from_api(api_target, ctx.api_secret_data)
      assert "whitelisted" = target.branch_mode
      assert "all" = target.tag_mode
      assert "none" = target.pr_mode

      assert [%Target.ObjectItem{match_mode: 1, pattern: "latest"}] = target.branches
      assert [] = target.tags
    end

    test "maps all pull requests", ctx do
      api_target = %{
        ctx.api_target
        | object_rules: [
            %{type: :PR, match_mode: :ALL, pattern: ""},
            %{type: :PR, match_mode: :EXACT, pattern: "latest"},
            %{type: :TAG, match_mode: :REGEX, pattern: "v1.0.*"},
            %{type: :BRANCH, match_mode: :EXACT, pattern: "latest"}
          ]
      }

      assert target = Target.from_api(api_target, ctx.api_secret_data)
      assert "whitelisted" = target.branch_mode
      assert "whitelisted" = target.tag_mode
      assert "all" = target.pr_mode

      assert [%Target.ObjectItem{match_mode: 1, pattern: "latest"}] = target.branches
      assert [%Target.ObjectItem{match_mode: 2, pattern: "v1.0.*"}] = target.tags
    end

    test "maps whitelisted pull requests to none", ctx do
      api_target = %{
        ctx.api_target
        | object_rules: [
            %{type: :PR, match_mode: :EXACT, pattern: "latest"},
            %{type: :TAG, match_mode: :REGEX, pattern: "v1.0.*"},
            %{type: :BRANCH, match_mode: :EXACT, pattern: "latest"}
          ]
      }

      assert target = Target.from_api(api_target, ctx.api_secret_data)
      assert "whitelisted" = target.branch_mode
      assert "whitelisted" = target.tag_mode
      assert "none" = target.pr_mode

      assert [%Target.ObjectItem{match_mode: 1, pattern: "latest"}] = target.branches
      assert [%Target.ObjectItem{match_mode: 2, pattern: "v1.0.*"}] = target.tags
    end

    test "maps all branches and tags", ctx do
      api_target = %{
        ctx.api_target
        | object_rules: [
            %{type: :BRANCH, match_mode: :ALL, pattern: "latest"},
            %{type: :TAG, match_mode: :ALL, pattern: "latest"},
            %{type: :PR, match_mode: :ALL, pattern: "latest"}
          ]
      }

      assert target = Target.from_api(api_target, ctx.api_secret_data)
      assert "all" = target.branch_mode
      assert "all" = target.tag_mode
      assert "all" = target.pr_mode

      assert [] = target.branches
      assert [] = target.tags
    end
  end

  describe "to_api/2" do
    test "maps simple fields", ctx do
      assert result = Target.to_api(ctx.model, ctx.extra_params)

      for field <- ~w(id name description url)a do
        assert Map.get(result, field) == Map.get(ctx.model, field)
      end

      for field <- ~w(organization_id project_id)a do
        assert Map.get(result, field) == Map.get(ctx.extra_params, field)
      end
    end

    test "when any user has access then maps it to only one rule", ctx do
      model = %{ctx.model | user_access: "any", auto_promotions: true}
      assert result = Target.to_api(model, ctx.extra_params)
      assert [%{type: :ANY, subject_id: ""}] = result.subject_rules
    end

    test "when roles and members are granted access then maps them to subject rules", ctx do
      assert result = Target.to_api(ctx.model, ctx.extra_params)

      model_subjects =
        MapSet.union(
          MapSet.new(ctx.model.roles, &{:ROLE, &1}),
          MapSet.new(ctx.model.members, &{:USER, &1})
        )

      assert ^model_subjects = MapSet.new(result.subject_rules, &{&1.type, &1.subject_id})
    end

    test "when only roles are granted access then maps them to subject rules", ctx do
      model = %{ctx.model | members: []}
      assert result = Target.to_api(model, ctx.extra_params)

      model_subjects = MapSet.new(ctx.model.roles)
      assert ^model_subjects = MapSet.new(result.subject_rules, & &1.subject_id)
    end

    test "when only members are granted access then maps them to subject rules", ctx do
      model = %{ctx.model | roles: []}
      assert result = Target.to_api(model, ctx.extra_params)

      model_subjects = MapSet.new(ctx.model.members)
      assert ^model_subjects = MapSet.new(result.subject_rules, & &1.subject_id)
    end

    test "when auto promotions are granted access then maps it to subject rules", ctx do
      model = %{ctx.model | roles: [], auto_promotions: true}
      assert result = Target.to_api(model, ctx.extra_params)

      model_subjects = MapSet.new(ctx.model.members) |> MapSet.put("")
      assert ^model_subjects = MapSet.new(result.subject_rules, & &1.subject_id)
      assert Enum.member?(result.subject_rules, %{type: :AUTO, subject_id: ""})
    end

    test "when no one is granted access then subject rules are empty", ctx do
      model = %{ctx.model | roles: [], members: []}
      assert result = Target.to_api(model, ctx.extra_params)
      assert [] = result.subject_rules
    end

    test "when branches and tags are granted access then map them to subject rules", ctx do
      assert result = Target.to_api(ctx.model, ctx.extra_params)

      model_subjects =
        MapSet.union(
          MapSet.new(ctx.model.branches, &{:BRANCH, {&1.match_mode, &1.pattern}}),
          MapSet.new(ctx.model.tags, &{:TAG, {&1.match_mode, &1.pattern}})
        )

      assert ^model_subjects =
               MapSet.new(result.object_rules, &{&1.type, {&1.match_mode, &1.pattern}})
    end

    test "when branch mode is all then maps it to one rule", ctx do
      model = %{ctx.model | branch_mode: "all"}
      assert result = Target.to_api(model, ctx.extra_params)

      model_subjects =
        MapSet.union(
          MapSet.new(ctx.model.tags, &{:TAG, {&1.match_mode, &1.pattern}}),
          MapSet.new([{:BRANCH, {:ALL, ""}}])
        )

      assert ^model_subjects =
               MapSet.new(result.object_rules, &{&1.type, {&1.match_mode, &1.pattern}})
    end

    test "when branch mode is none then maps it to no rule", ctx do
      model = %{ctx.model | branch_mode: "none"}
      assert result = Target.to_api(model, ctx.extra_params)

      model_subjects = MapSet.new(ctx.model.tags, &{:TAG, {&1.match_mode, &1.pattern}})

      assert ^model_subjects =
               MapSet.new(result.object_rules, &{&1.type, {&1.match_mode, &1.pattern}})
    end

    test "when tag mode is all then maps it to one rule", ctx do
      model = %{ctx.model | tag_mode: "all"}
      assert result = Target.to_api(model, ctx.extra_params)

      model_subjects =
        MapSet.union(
          MapSet.new(ctx.model.branches, &{:BRANCH, {&1.match_mode, &1.pattern}}),
          MapSet.new([{:TAG, {:ALL, ""}}])
        )

      assert ^model_subjects =
               MapSet.new(result.object_rules, &{&1.type, {&1.match_mode, &1.pattern}})
    end

    test "when tag mode is none then maps it to no rule", ctx do
      model = %{ctx.model | tag_mode: "none"}
      assert result = Target.to_api(model, ctx.extra_params)

      model_subjects = MapSet.new(ctx.model.branches, &{:BRANCH, {&1.match_mode, &1.pattern}})

      assert ^model_subjects =
               MapSet.new(result.object_rules, &{&1.type, {&1.match_mode, &1.pattern}})
    end

    test "when PR mode is all then maps it to one rule", ctx do
      model = %{ctx.model | pr_mode: "all"}
      assert result = Target.to_api(model, ctx.extra_params)

      model_subjects =
        MapSet.new([{:PR, {:ALL, ""}}])
        |> MapSet.union(MapSet.new(ctx.model.branches, &{:BRANCH, {&1.match_mode, &1.pattern}}))
        |> MapSet.union(MapSet.new(ctx.model.tags, &{:TAG, {&1.match_mode, &1.pattern}}))

      assert ^model_subjects =
               MapSet.new(result.object_rules, &{&1.type, {&1.match_mode, &1.pattern}})
    end

    test "when PR mode is none then maps it to no rule", ctx do
      model = %{ctx.model | pr_mode: "none"}
      assert result = Target.to_api(model, ctx.extra_params)

      model_subjects =
        MapSet.union(
          MapSet.new(ctx.model.branches, &{:BRANCH, {&1.match_mode, &1.pattern}}),
          MapSet.new(ctx.model.tags, &{:TAG, {&1.match_mode, &1.pattern}})
        )

      assert ^model_subjects =
               MapSet.new(result.object_rules, &{&1.type, {&1.match_mode, &1.pattern}})
    end

    test "when branch, tag and PR mode are all then maps it two rules", ctx do
      model = %{ctx.model | branch_mode: "all", tag_mode: "all", pr_mode: "all"}
      assert result = Target.to_api(model, ctx.extra_params)

      model_subjects = MapSet.new([{:BRANCH, {:ALL, ""}}, {:TAG, {:ALL, ""}}, {:PR, {:ALL, ""}}])

      assert ^model_subjects =
               MapSet.new(result.object_rules, &{&1.type, {&1.match_mode, &1.pattern}})
    end

    test "when branch, tag and PR mode are none then maps it to empty rules", ctx do
      model = %{ctx.model | branch_mode: "none", tag_mode: "none", pr_mode: "none"}
      assert result = Target.to_api(model, ctx.extra_params)

      assert [] = Enum.map(result.object_rules, &{&1.type, {&1.match_mode, &1.pattern}})
    end
  end

  describe "extract_secret_data/2" do
    test "for env vars when ids are empty then maps new values", ctx do
      env_vars = [
        %{id: "", name: "NAME1", value: "VALUE1"},
        %{id: "", name: "NAME2", value: "VALUE2"}
      ]

      expected = Enum.into(env_vars, [], &%{name: &1.name, value: &1.value})
      changeset = Target.changeset(Target.new(), %{env_vars: env_vars, files: []})

      assert {:ok, %{env_vars: ^expected, files: []}} =
               Target.extract_secret_data(changeset, ctx.api_secret_data)
    end

    test "for env vars when ids are non empty and value is empty then maps old values", ctx do
      env_vars = [
        %{id: "EV1", name: "NAME1", value: ""},
        %{id: "EV2", name: "NAME2", value: ""}
      ]

      old_values = Enum.into(ctx.api_secret_data.env_vars, %{}, &{&1.name, &1.value})
      expected = Enum.into(env_vars, [], &%{name: &1.name, value: Map.get(old_values, &1.id)})
      changeset = Target.changeset(Target.new(), %{env_vars: env_vars, files: []})

      assert {:ok, %{env_vars: ^expected, files: []}} =
               Target.extract_secret_data(changeset, ctx.api_secret_data)
    end

    test "for env vars when ids are non empty and value is empty" <>
           " and old values are missing then returns error",
         ctx do
      env_vars = [
        %{id: "E1", name: "NAME1", value: ""},
        %{id: "E2", name: "NAME2", value: ""}
      ]

      changeset = Target.changeset(Target.new(), %{env_vars: env_vars, files: []})

      assert {:error, %DeploymentsError{message: "Secret was modified in the meantime"}} =
               Target.extract_secret_data(changeset, ctx.api_secret_data)
    end

    test "for env vars when ids are non empty and value is non empty then maps new values", ctx do
      env_vars = [
        %{id: "EV1", name: "NAME1", value: "VALUE1"},
        %{id: "EV2", name: "NAME2", value: "VALUE2"}
      ]

      expected = Enum.into(env_vars, [], &%{name: &1.name, value: &1.value})
      changeset = Target.changeset(Target.new(), %{env_vars: env_vars, files: []})

      assert {:ok, %{env_vars: ^expected, files: []}} =
               Target.extract_secret_data(changeset, ctx.api_secret_data)
    end

    test "for env vars with mixed cases values are handled properly", ctx do
      env_vars = [
        %{id: "", name: "NAME1", value: "VALUE1"},
        %{id: "EV1", name: "NAME2", value: ""},
        %{id: "EV2", name: "NAME3", value: "VALUE3"}
      ]

      expected = [
        %{name: "NAME1", value: "VALUE1"},
        %{name: "NAME2", value: "V1"},
        %{name: "NAME3", value: "VALUE3"}
      ]

      changeset = Target.changeset(Target.new(), %{env_vars: env_vars, files: []})

      assert {:ok, %{env_vars: ^expected, files: []}} =
               Target.extract_secret_data(changeset, ctx.api_secret_data)
    end

    test "for files when ids are empty then maps new contents", ctx do
      files = [
        %{id: "", path: "PATH1", content: "CONTENT1"},
        %{id: "", path: "PATH2", content: "CONTENT2"}
      ]

      expected = Enum.into(files, [], &%{path: &1.path, content: &1.content})
      changeset = Target.changeset(Target.new(), %{env_vars: [], files: files})

      assert {:ok, %{env_vars: [], files: ^expected}} =
               Target.extract_secret_data(changeset, ctx.api_secret_data)
    end

    test "for files when ids are non empty and content is empty then maps old contents", ctx do
      files = [
        %{id: "F1", path: "PATH1", content: ""},
        %{id: "F2", path: "PATH2", content: ""}
      ]

      old_contents = Enum.into(ctx.api_secret_data.files, %{}, &{&1.path, &1.content})
      expected = Enum.into(files, [], &%{path: &1.path, content: Map.get(old_contents, &1.id)})
      changeset = Target.changeset(Target.new(), %{env_vars: [], files: files})

      assert {:ok, %{env_vars: [], files: ^expected}} =
               Target.extract_secret_data(changeset, ctx.api_secret_data)
    end

    test "for files when ids are non empty and content is empty" <>
           " and old content is missing then maps to empty contents",
         ctx do
      files = [
        %{id: "P1", path: "PATH1", content: ""},
        %{id: "P2", path: "PATH2", content: ""}
      ]

      changeset = Target.changeset(Target.new(), %{env_vars: [], files: files})

      assert {:error, %DeploymentsError{message: "Secret was modified in the meantime"}} =
               Target.extract_secret_data(changeset, ctx.api_secret_data)
    end

    test "for files when ids and contents are non empty then maps new contents", ctx do
      files = [
        %{id: "F1", path: "PATH1", content: "CONTENT1"},
        %{id: "F2", path: "PATH2", content: "CONTENT2"}
      ]

      expected = Enum.into(files, [], &%{path: &1.path, content: &1.content})
      changeset = Target.changeset(Target.new(), %{env_vars: [], files: files})

      assert {:ok, %{env_vars: [], files: ^expected}} =
               Target.extract_secret_data(changeset, ctx.api_secret_data)
    end

    test "for files with mixed cases contents are handled properly", ctx do
      files = [
        %{id: "", path: "PATH1", content: "CONTENT1"},
        %{id: "F1", path: "PATH2", content: ""},
        %{id: "F2", path: "PATH3", content: "CONTENT3"}
      ]

      expected = [
        %{path: "PATH1", content: "CONTENT1"},
        %{path: "PATH2", content: "C1"},
        %{path: "PATH3", content: "CONTENT3"}
      ]

      changeset = Target.changeset(Target.new(), %{env_vars: [], files: files})

      assert {:ok, %{env_vars: [], files: ^expected}} =
               Target.extract_secret_data(changeset, ctx.api_secret_data)
    end

    test "for empty env vars and files data is empty", ctx do
      model = %Target{
        env_vars: [%Target.EnvVar{id: "E1", name: "E1", value: "V1"}],
        files: [%Target.File{id: "F1", path: "F1", content: "C1"}]
      }

      assert {:ok, %{env_vars: [], files: []}} =
               Target.extract_secret_data(
                 Target.changeset(model, %{env_vars: [], files: []}),
                 ctx.api_secret_data
               )
    end

    test "when there are no changes to secret then atom is returned", ctx do
      model = %Target{
        env_vars: [%Target.EnvVar{id: "E1", name: "E1", value: "", md5: "EMD1"}],
        files: [%Target.File{id: "F1", path: "F1", content: "", md5: "FMD1"}]
      }

      params = %{
        "env_vars" => %{"0" => %{"id" => "E1", "name" => "E1", "value" => "", "md5" => "EMD1"}},
        "files" => %{"0" => %{"id" => "F1", "path" => "F1", "content" => "", "md5" => "FMD1"}}
      }

      assert {:ok, :no_changes} =
               Target.extract_secret_data(Target.changeset(model, params), ctx.api_secret_data)
    end

    test "for mixed env vars and files values and contents are handled properly", ctx do
      changeset =
        Target.changeset(%{
          env_vars: [
            %{id: "", name: "NAME1", value: "VALUE1"},
            %{id: "EV1", name: "NAME2", value: ""},
            %{id: "EV2", name: "NAME3", value: "VALUE3"}
          ],
          files: [
            %{id: "", path: "PATH1", content: "CONTENT1"},
            %{id: "F1", path: "PATH2", content: ""},
            %{id: "F2", path: "PATH3", content: "CONTENT3"}
          ]
        })

      expected = %{
        env_vars: [
          %{name: "NAME1", value: "VALUE1"},
          %{name: "NAME2", value: "V1"},
          %{name: "NAME3", value: "VALUE3"}
        ],
        files: [
          %{path: "PATH1", content: "CONTENT1"},
          %{path: "PATH2", content: "C1"},
          %{path: "PATH3", content: "CONTENT3"}
        ]
      }

      assert {:ok, ^expected} = Target.extract_secret_data(changeset, ctx.api_secret_data)
    end
  end

  # helpers

  defp md5_checksum(value),
    do: value |> :erlang.md5() |> Base.encode16(case: :lower)

  defp changeset_for(structure = %{__struct__: module}, params) when is_struct(structure) do
    module.changeset(structure, params)
  end

  defp changeset_for(module, params) when is_atom(module) do
    module.changeset(struct(module), params)
  end

  defp collection_from_params(params, :env_vars),
    do: collection_from_params(params, "env_vars", Target.EnvVar, ~w(id name value))

  defp collection_from_params(params, :files),
    do: collection_from_params(params, "files", Target.File, ~w(id path content))

  defp collection_from_params(params, :branches),
    do: collection_from_params(params, "branches", Target.ObjectItem, ~w(match_mode pattern))

  defp collection_from_params(params, :tags),
    do: collection_from_params(params, "tags", Target.ObjectItem, ~w(match_mode pattern))

  defp collection_from_params(params, name, struct_mod, fields) do
    MapSet.new(params[name], &struct!(struct_mod, map_param_fields(&1, fields)))
  end

  defp map_param_fields({_index, item}, fields) do
    result = item |> Map.take(fields) |> keys_to_atom()

    if Map.has_key?(result, :match_mode) do
      {match_mode, _} = Integer.parse(result.match_mode)
      %{result | match_mode: match_mode}
    else
      result
    end
  end

  defp keys_to_atom(map) do
    Enum.into(map, %{}, &{String.to_existing_atom(elem(&1, 0)), elem(&1, 1)})
  end

  # fixtures

  defp prepare_extra_params(_ctx) do
    {:ok,
     extra_params: %{
       organization_id: UUID.uuid4(),
       project_id: UUID.uuid4(),
       requester_id: UUID.uuid4()
     }}
  end

  defp prepare_params(_ctx) do
    {:ok, params: Support.Factories.Deployments.prepare_params()}
  end

  defp prepare_model(_ctx) do
    {:ok,
     model: %Target{
       name: "Production",
       description: "Production environment",
       url: "https://production.rtx.com",
       unique_token: UUID.uuid4(),
       user_access: "some",
       roles: [UUID.uuid4(), UUID.uuid4()],
       members: [UUID.uuid4(), UUID.uuid4()],
       auto_promotions: false,
       branch_mode: "whitelisted",
       tag_mode: "whitelisted",
       pr_mode: "none",
       branches: [
         %Target.ObjectItem{match_mode: 1, pattern: "master"},
         %Target.ObjectItem{match_mode: 2, pattern: "feature/*"}
       ],
       tags: [
         %Target.ObjectItem{match_mode: 1, pattern: "latest"},
         %Target.ObjectItem{match_mode: 2, pattern: "v1.0.*"}
       ]
     }}
  end

  defp prepare_api_target(_ctx) do
    role_id = UUID.uuid4()
    user_id = UUID.uuid4()

    {:ok,
     api_role_id: role_id,
     api_user_id: user_id,
     api_target:
       Util.Proto.to_map!(
         API.DeploymentTarget.new(
           id: UUID.uuid4(),
           name: "Staging",
           description: "Staging environment",
           url: "https://staging.rtx.com",
           subject_rules: [
             API.SubjectRule.new(type: 0, subject_id: user_id),
             API.SubjectRule.new(type: 1, subject_id: role_id)
           ],
           object_rules: []
         )
       )}
  end

  defp prepare_api_secret_data(_ctx) do
    alias InternalApi.Secrethub.Secret

    {:ok,
     api_secret_data:
       Util.Proto.to_map!(
         Secret.Data.new(
           env_vars: [
             Secret.EnvVar.new(name: "EV1", value: "V1"),
             Secret.EnvVar.new(name: "EV2", value: "V2")
           ],
           files: [
             Secret.File.new(path: "F1", content: "C1"),
             Secret.File.new(path: "F2", content: "C2")
           ]
         )
       )}
  end
end
