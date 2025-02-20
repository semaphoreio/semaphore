defmodule Gofer.Deployment.GuardianTestHelpers do
  import ExUnit.Assertions, only: [assert: 1]
  alias Gofer.Deployment.Model.Deployment
  alias Gofer.Switch.Model.Switch
  alias Gofer.Deployment.Guardian
  alias Support.Stubs.RBAC, as: RBACStub

  def setup_rbac(_ctx) do
    RBACStub.setup()
    :ok
  end

  def setup_subject_and_roles(_ctx) do
    subject_params = [
      organization_id: UUID.uuid4(),
      project_id: UUID.uuid4(),
      triggerer: UUID.uuid4()
    ]

    {:ok,
     [
       organization_id: subject_params[:organization_id],
       project_id: subject_params[:project_id],
       triggerer: subject_params[:triggerer],
       random_triggerer: UUID.uuid4(),
       role_ids: for(_ <- 1..5, do: insert_role(subject_params, UUID.uuid4())),
       deployment: %Deployment{
         id: UUID.uuid4(),
         name: "production",
         organization_id: subject_params[:organization_id],
         project_id: subject_params[:project_id],
         state: :FINISHED,
         result: :SUCCESS
       }
     ]}
  end

  def insert_role(subject_params, role_id) do
    subject_params
    |> Keyword.values()
    |> List.to_tuple()
    |> Tuple.append(role_id)
    |> RBACStub.set_role()

    role_id
  end

  def with_syncing_state(deployment) do
    %Deployment{deployment | state: :SYNCING, result: :FAILURE}
  end

  def with_failure(deployment) do
    %Deployment{deployment | state: :FINISHED, result: :FAILURE}
  end

  def with_cordon_on(deployment) do
    %Deployment{deployment | cordoned: true}
  end

  def with_subject_rules(deployment, subject_rules) do
    as_rule = &%Deployment.SubjectRule{type: elem(&1, 0), subject_id: elem(&1, 1)}
    %Deployment{deployment | subject_rules: Enum.map(subject_rules, as_rule)}
  end

  def with_object_rules(deployment, object_rules) do
    as_rule = fn {type, {match_mode, pattern}} ->
      %Deployment.ObjectRule{type: type, match_mode: match_mode, pattern: pattern}
    end

    %Deployment{deployment | object_rules: Enum.map(object_rules, as_rule)}
  end

  def check_subject_access(deployment, opts \\ []) do
    {:SUBJECT,
     fn triggerer ->
       switch = %Switch{git_ref_type: "branch", label: "master"}

       deployment
       |> with_object_rules(BRANCH: {:ALL, ""})
       |> Guardian.verify(switch, triggerer, opts)
     end}
  end

  def check_object_access(deployment, opts \\ []) do
    {:OBJECT,
     fn git_ref_type, label ->
       type_as_string = git_ref_type |> to_string() |> String.downcase()

       switch = %Switch{git_ref_type: type_as_string, label: label}
       triggerer = UUID.uuid4()

       deployment
       |> with_subject_rules(USER: triggerer)
       |> Guardian.verify(switch, triggerer, opts)
     end}
  end

  def granted?(check = {:SUBJECT, func}, triggerer) do
    assert {:ok, _deployment} = func.(triggerer)

    check
  end

  def granted?(check = {:OBJECT, func}, git_ref_type, label) do
    assert {:ok, _deployment} = func.(git_ref_type, label)

    check
  end

  def not_granted?(check = {:SUBJECT, func}, triggerer) do
    assert {:error, {:BANNED_SUBJECT, meta}} = func.(triggerer)
    assert [triggerer: ^triggerer] = Keyword.take(meta, [:triggerer])

    check
  end

  def not_granted?(check = {:OBJECT, func}, git_ref_type, label) do
    git_ref_type_as_string = git_ref_type |> to_string() |> String.downcase()

    assert {:error, {:BANNED_OBJECT, meta}} = func.(git_ref_type, label)

    assert [git_ref_type: ^git_ref_type_as_string, label: ^label] =
             Keyword.take(meta, [:git_ref_type, :label])

    check
  end

  def nobody_has_access?(deployment, reason) do
    switch = %Switch{git_ref_type: "branch", label: "master"}
    triggerer = UUID.uuid4()

    assert {:error, {^reason, meta}} =
             deployment
             |> with_subject_rules(USER: triggerer)
             |> with_object_rules(BRANCH: {:EXACT, "master"})
             |> Guardian.verify(switch, triggerer)

    assert Keyword.get(meta, :deployment_id) == deployment.id
    assert Keyword.get(meta, :deployment_name) == deployment.name
    assert Keyword.get(meta, :git_ref_type) == switch.git_ref_type
    assert Keyword.get(meta, :label) == switch.label
    assert Keyword.get(meta, :triggerer) == triggerer

    deployment
  end
end

defmodule Gofer.Deployment.GuardianTest do
  use ExUnit.Case, async: false
  import Gofer.Deployment.GuardianTestHelpers
  alias Gofer.Deployment.Guardian

  setup_all [:setup_rbac, :setup_subject_and_roles]
  @branch_pattern "release/v([0-9]+)\\.([0-9]+)\\.([0-9]+)"
  @tag_pattern "v([0-9]+)\\.([0-9]+)\\.([0-9]+)"
  @invalid_pattern "[0-9++"

  describe "verify/3 (interface)" do
    test "works with switch", ctx do
      alias Gofer.Switch.Model.Switch

      assert {:ok, _metadata} =
               ctx[:deployment]
               |> with_subject_rules(ANY: "")
               |> with_object_rules(BRANCH: {:ALL, ""})
               |> Guardian.verify(%Switch{git_ref_type: "branch", label: "master"}, ctx.triggerer)

      assert {:error, {:BANNED_OBJECT, _metadata}} =
               ctx[:deployment]
               |> with_subject_rules(ANY: "")
               |> with_object_rules(BRANCH: {:ALL, ""})
               |> Guardian.verify(%Switch{git_ref_type: "tag", label: "latest"}, ctx.triggerer)
    end

    test "works with object pair", ctx do
      assert {:ok, _metadata} =
               ctx[:deployment]
               |> with_subject_rules(ANY: "")
               |> with_object_rules(BRANCH: {:ALL, ""})
               |> Guardian.verify({:BRANCH, "master"}, ctx.triggerer)

      assert {:error, {:BANNED_OBJECT, _metadata}} =
               ctx[:deployment]
               |> with_subject_rules(ANY: "")
               |> with_object_rules(BRANCH: {:ALL, ""})
               |> Guardian.verify({:TAG, "latest"}, ctx.triggerer)
    end
  end

  describe "verify/3 (corner cases)" do
    test "when deployment is syncing", ctx do
      ctx[:deployment]
      |> with_syncing_state()
      |> nobody_has_access?(:SYNCING_TARGET)
    end

    test "when deployment syncing has failed", ctx do
      ctx[:deployment]
      |> with_failure()
      |> nobody_has_access?(:CORRUPTED_TARGET)
    end

    test "when deployment is cordoned", ctx do
      ctx[:deployment]
      |> with_cordon_on()
      |> nobody_has_access?(:CORDONED_TARGET)
    end
  end

  describe "verify/3 (subject rules)" do
    test "when nobody is granted access", ctx do
      ctx[:deployment]
      |> check_subject_access()
      |> not_granted?(ctx.triggerer)
      |> not_granted?(ctx.random_triggerer)
    end

    test "when anyone is granted access", ctx do
      ctx[:deployment]
      |> with_subject_rules(ANY: "")
      |> check_subject_access()
      |> not_granted?("")
      |> not_granted?(nil)
      |> granted?("Pipeline Done request")
      |> granted?("literally any user ID")
      |> granted?(UUID.uuid4())
    end

    test "when user is empty", ctx do
      ctx[:deployment]
      |> with_subject_rules(USER: "")
      |> check_subject_access()
      |> not_granted?("")
      |> not_granted?(nil)
    end

    test "when auto-promotions are granted access", ctx do
      ctx[:deployment]
      |> with_subject_rules(AUTO: "")
      |> check_subject_access()
      |> not_granted?(ctx.triggerer)
      |> granted?("Pipeline Done request")
    end

    test "when auto-promotions are denied access", ctx do
      ctx[:deployment]
      |> with_subject_rules(USER: ctx.triggerer)
      |> check_subject_access()
      |> granted?(ctx.triggerer)
      |> not_granted?("Pipeline Done request")
    end

    test "when user is granted access", ctx do
      ctx[:deployment]
      |> with_subject_rules(USER: ctx.triggerer)
      |> check_subject_access()
      |> granted?(ctx.triggerer)
      |> not_granted?(ctx.random_triggerer)
    end

    test "when user's role is granted access", ctx do
      ctx[:deployment]
      |> with_subject_rules(
        ROLE: UUID.uuid4(),
        ROLE: List.first(ctx.role_ids)
      )
      |> check_subject_access()
      |> granted?(ctx.triggerer)
      |> not_granted?(ctx.random_triggerer)
    end

    test "when a few user's roles are granted access", ctx do
      ctx[:deployment]
      |> with_subject_rules(Enum.map(ctx.role_ids, &{:ROLE, &1}))
      |> check_subject_access()
      |> granted?(ctx.triggerer)
      |> not_granted?(ctx.random_triggerer)
    end

    test "when other users are granted access", ctx do
      ctx[:deployment]
      |> with_subject_rules(
        USER: UUID.uuid4(),
        USER: UUID.uuid4()
      )
      |> check_subject_access()
      |> not_granted?(ctx.triggerer)
      |> not_granted?(ctx.random_triggerer)
    end

    test "when other roles are granted access", ctx do
      ctx[:deployment]
      |> with_subject_rules(
        ROLE: UUID.uuid4(),
        ROLE: UUID.uuid4()
      )
      |> check_subject_access()
      |> not_granted?(ctx.triggerer)
      |> not_granted?(ctx.random_triggerer)
    end

    test "when user is one of those who are granted access",
         ctx do
      ctx[:deployment]
      |> with_subject_rules(USER: UUID.uuid4(), USER: ctx.triggerer)
      |> check_subject_access()
      |> granted?(ctx.triggerer)
      |> not_granted?(ctx.random_triggerer)
    end

    test "when user has one of roles that are granted access", ctx do
      ctx[:deployment]
      |> with_subject_rules(
        ROLE: UUID.uuid4(),
        ROLE: List.first(ctx.role_ids)
      )
      |> check_subject_access()
      |> granted?(ctx.triggerer)
      |> not_granted?(ctx.random_triggerer)
    end

    test "when roles' cache is queried", ctx do
      start_supervised!(Gofer.RBAC.RolesCache)

      ctx[:deployment]
      |> with_subject_rules(
        ROLE: UUID.uuid4(),
        ROLE: List.first(ctx.role_ids)
      )
      |> check_subject_access(cached?: true)
      |> granted?(ctx.triggerer)
      |> not_granted?(ctx.random_triggerer)
    end

    test "when both user and his role are granted access", ctx do
      ctx[:deployment]
      |> with_subject_rules(
        ROLE: List.first(ctx.role_ids),
        USER: ctx.triggerer
      )
      |> check_subject_access()
      |> granted?(ctx.triggerer)
      |> not_granted?(ctx.random_triggerer)
    end

    test "when user and none of their roles are granted access", ctx do
      ctx[:deployment]
      |> with_subject_rules(
        USER: UUID.uuid4(),
        USER: UUID.uuid4(),
        ROLE: UUID.uuid4(),
        ROLE: UUID.uuid4()
      )
      |> check_subject_access()
      |> not_granted?(ctx.triggerer)
      |> not_granted?(ctx.random_triggerer)
    end
  end

  describe "verify/3 (object rules)" do
    test "when no object is granted access", ctx do
      ctx[:deployment]
      |> check_object_access()
      |> not_granted?(:BRANCH, "master")
      |> not_granted?(:BRANCH, "release/v1.2.3")
      |> not_granted?(:TAG, "latest")
      |> not_granted?(:TAG, "v1.2.3")
      |> not_granted?(:PR, "1234")
    end

    test "when only tags are granted access", ctx do
      ctx[:deployment]
      |> with_object_rules(TAG: {:ALL, ""})
      |> check_object_access()
      |> granted?(:TAG, "latest")
      |> granted?(:TAG, "v1.2.3")
      |> not_granted?(:BRANCH, "master")
      |> not_granted?(:BRANCH, "release/v1.2.3")
      |> not_granted?(:PR, "1234")
    end

    test "when only exact tags are granted access", ctx do
      ctx[:deployment]
      |> with_object_rules(TAG: {:EXACT, "latest"})
      |> check_object_access()
      |> granted?(:TAG, "latest")
      |> not_granted?(:TAG, "v1.2.3")
      |> not_granted?(:BRANCH, "master")
      |> not_granted?(:BRANCH, "release/v1.2.3")
      |> not_granted?(:PR, "1234")
    end

    test "when only regex tags are granted access", ctx do
      ctx[:deployment]
      |> with_object_rules(TAG: {:REGEX, @tag_pattern})
      |> check_object_access()
      |> granted?(:TAG, "v1.2.3")
      |> not_granted?(:TAG, "latest")
      |> not_granted?(:BRANCH, "master")
      |> not_granted?(:BRANCH, "release/v1.2.3")
      |> not_granted?(:PR, "1234")
    end

    test "when both exact and regex tags are granted access", ctx do
      ctx[:deployment]
      |> with_object_rules(
        TAG: {:REGEX, @tag_pattern},
        TAG: {:EXACT, "latest"}
      )
      |> check_object_access()
      |> granted?(:TAG, "v1.2.3")
      |> granted?(:TAG, "latest")
      |> not_granted?(:TAG, "v.1.2.2")
      |> not_granted?(:BRANCH, "master")
      |> not_granted?(:BRANCH, "release/v1.2.3")
      |> not_granted?(:PR, "1234")
    end

    test "when all, exact and regex tags are granted access", ctx do
      ctx[:deployment]
      |> with_object_rules(
        TAG: {:ALL, ""},
        TAG: {:REGEX, @tag_pattern},
        TAG: {:EXACT, "latest"}
      )
      |> check_object_access()
      |> granted?(:TAG, "v1.2.3")
      |> granted?(:TAG, "latest")
      |> granted?(:TAG, "v.1.2.2")
      |> not_granted?(:BRANCH, "master")
      |> not_granted?(:BRANCH, "release/v1.2.3")
      |> not_granted?(:PR, "1234")
    end

    test "when only branches are granted access", ctx do
      ctx[:deployment]
      |> with_object_rules(BRANCH: {:ALL, ""})
      |> check_object_access()
      |> granted?(:BRANCH, "master")
      |> granted?(:BRANCH, "release/v1.2.3")
      |> not_granted?(:TAG, "latest")
      |> not_granted?(:TAG, "v1.2.3")
      |> not_granted?(:PR, "1234")
    end

    test "when only exact branches are granted access", ctx do
      ctx[:deployment]
      |> with_object_rules(BRANCH: {:EXACT, "master"})
      |> check_object_access()
      |> granted?(:BRANCH, "master")
      |> not_granted?(:BRANCH, "release/v1.2.3")
      |> not_granted?(:TAG, "latest")
      |> not_granted?(:TAG, "v1.2.3")
      |> not_granted?(:PR, "1234")
    end

    test "when only regex branches are granted access", ctx do
      ctx[:deployment]
      |> with_object_rules(BRANCH: {:REGEX, @branch_pattern})
      |> check_object_access()
      |> not_granted?(:BRANCH, "master")
      |> granted?(:BRANCH, "release/v1.2.3")
      |> not_granted?(:TAG, "latest")
      |> not_granted?(:TAG, "v1.2.3")
      |> not_granted?(:PR, "1234")
    end

    test "when both exact and regex branches are granted access", ctx do
      ctx[:deployment]
      |> with_object_rules(
        BRANCH: {:REGEX, @branch_pattern},
        BRANCH: {:EXACT, "master"}
      )
      |> check_object_access()
      |> granted?(:BRANCH, "master")
      |> granted?(:BRANCH, "release/v1.2.3")
      |> not_granted?(:TAG, "latest")
      |> not_granted?(:TAG, "v1.2.3")
      |> not_granted?(:PR, "1234")
    end

    test "when all, exact and regex branches are granted access", ctx do
      ctx[:deployment]
      |> with_object_rules(
        BRANCH: {:ALL, ""},
        BRANCH: {:REGEX, @tag_pattern},
        BRANCH: {:EXACT, "master"}
      )
      |> check_object_access()
      |> granted?(:BRANCH, "master")
      |> granted?(:BRANCH, "develop")
      |> granted?(:BRANCH, "release/v1.2.3")
      |> not_granted?(:TAG, "latest")
      |> not_granted?(:TAG, "v1.2.3")
      |> not_granted?(:PR, "1234")
    end

    test "when exact branches and regex tags are granted access", ctx do
      ctx[:deployment]
      |> with_object_rules(
        TAG: {:REGEX, @tag_pattern},
        BRANCH: {:EXACT, "master"}
      )
      |> check_object_access()
      |> granted?(:BRANCH, "master")
      |> not_granted?(:BRANCH, "release/v1.2.3")
      |> not_granted?(:TAG, "latest")
      |> granted?(:TAG, "v1.2.3")
      |> not_granted?(:PR, "1234")
    end

    test "when exact tags and regex branches are granted access", ctx do
      ctx[:deployment]
      |> with_object_rules(
        BRANCH: {:REGEX, @branch_pattern},
        TAG: {:EXACT, "latest"}
      )
      |> check_object_access()
      |> not_granted?(:BRANCH, "master")
      |> granted?(:BRANCH, "release/v1.2.3")
      |> granted?(:TAG, "latest")
      |> not_granted?(:TAG, "v1.2.3")
      |> not_granted?(:PR, "1234")
    end

    test "when invalid regex branches are granted access", ctx do
      ctx[:deployment]
      |> with_object_rules(BRANCH: {:REGEX, @invalid_pattern})
      |> check_object_access()
      |> not_granted?(:BRANCH, "master")
      |> not_granted?(:BRANCH, "release/v1.2.3")
      |> not_granted?(:TAG, "latest")
      |> not_granted?(:TAG, "v1.2.3")
      |> not_granted?(:PR, "1234")
    end

    test "when invalid regex tags are granted access", ctx do
      ctx[:deployment]
      |> with_object_rules(TAG: {:REGEX, @invalid_pattern})
      |> check_object_access()
      |> not_granted?(:BRANCH, "master")
      |> not_granted?(:BRANCH, "release/v1.2.3")
      |> not_granted?(:TAG, "latest")
      |> not_granted?(:TAG, "v1.2.3")
      |> not_granted?(:PR, "1234")
    end

    test "when invalid regex branches are granted access but some other rules apply", ctx do
      ctx[:deployment]
      |> with_object_rules(
        BRANCH: {:REGEX, @invalid_pattern},
        TAG: {:ALL, ""},
        BRANCH: {:EXACT, "master"}
      )
      |> check_object_access()
      |> granted?(:BRANCH, "master")
      |> not_granted?(:BRANCH, "release/v1.2.3")
      |> granted?(:TAG, "latest")
      |> granted?(:TAG, "v1.2.3")
      |> not_granted?(:PR, "1234")
    end

    test "when invalid regex tags are granted access but some other rules apply", ctx do
      ctx[:deployment]
      |> with_object_rules(
        TAG: {:REGEX, @invalid_pattern},
        BRANCH: {:ALL, ""},
        TAG: {:EXACT, "latest"}
      )
      |> check_object_access()
      |> granted?(:BRANCH, "master")
      |> granted?(:BRANCH, "release/v1.2.3")
      |> granted?(:TAG, "latest")
      |> not_granted?(:TAG, "v1.2.3")
      |> not_granted?(:PR, "1234")
    end

    test "when pull requests are granted access", ctx do
      ctx[:deployment]
      |> with_object_rules(PR: {:ALL, ""})
      |> check_object_access()
      |> not_granted?(:BRANCH, "master")
      |> not_granted?(:BRANCH, "release/v1.2.3")
      |> not_granted?(:TAG, "latest")
      |> not_granted?(:TAG, "v1.2.3")
      |> granted?(:PR, "1234")
      |> granted?(:PR, "123")
    end

    test "when pull requests are granted access but some other rules apply", ctx do
      ctx[:deployment]
      |> with_object_rules(
        BRANCH: {:REGEX, @branch_pattern},
        TAG: {:EXACT, "latest"},
        PR: {:ALL, ""}
      )
      |> check_object_access()
      |> not_granted?(:BRANCH, "master")
      |> granted?(:BRANCH, "release/v1.2.3")
      |> granted?(:TAG, "latest")
      |> not_granted?(:TAG, "v1.2.3")
      |> granted?(:PR, "1234")
      |> granted?(:PR, "123")
    end
  end
end

defmodule Gofer.Deployment.GuardianUnavailableTest do
  use ExUnit.Case, async: false
  import Gofer.Deployment.GuardianTestHelpers

  setup_all [:setup_subject_and_roles]

  describe "verify/3 (when RBAC is unavailable)" do
    test "when only user rules are given", ctx do
      ctx[:deployment]
      |> with_subject_rules(USER: ctx.triggerer, USER: UUID.uuid4())
      |> check_subject_access()
      |> granted?(ctx.triggerer)
      |> not_granted?(ctx.random_triggerer)
    end

    test "when user has explicit access but role rules are given", ctx do
      ctx[:deployment]
      |> with_subject_rules(USER: ctx.triggerer, ROLE: UUID.uuid4())
      |> check_subject_access()
      |> granted?(ctx.triggerer)
      |> not_granted?(ctx.random_triggerer)
    end

    test "when user has no explicit access but role rules are given", ctx do
      ctx[:deployment]
      |> with_subject_rules(ROLE: List.first(ctx.role_ids), USER: UUID.uuid4())
      |> check_subject_access()
      |> not_granted?(ctx.triggerer)
      |> not_granted?(ctx.random_triggerer)
    end
  end
end
