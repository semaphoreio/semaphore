defmodule Front.Browser.PeopleTest do
  use FrontWeb.WallabyCase

  import Mock

  @add_link Query.css("button", text: "Add people")
  @load_more_btn Query.css("#load_more_btn")
  @remove_btn Query.button("remove-btn", count: :any, at: 0)
  @change_role_btn Query.css(".change_role_btn", count: :any, at: 0)

  setup do
    edition = Application.get_env(:front, :edition)
    Application.put_env(:front, :edition, "")

    on_exit(fn -> Application.put_env(:front, :edition, edition) end)
    :ok
  end

  describe "organization people" do
    setup [:setup_organization]

    browser_test "remove user", ctx do
      test_remove_user(ctx)
    end

    browser_test "change role", ctx do
      test_change_role(ctx, "Member", "Admin")
    end

    browser_test "load more", ctx do
      # this browser_testworks only if there is one member
      org = Support.Stubs.Organization.default()
      user = Support.Stubs.User.default()

      Support.Stubs.DB.all(:users)
      |> Enum.reject(fn u -> u.id == user.id end)
      |> Enum.each(fn u -> Support.Stubs.RBAC.delete_member(org.id, u.id) end)

      assign_role("Jacob Bannon", "Member", ctx.org_id)
      test_load_more(ctx)
    end

    browser_test "when user has multiple roles, show multiple labels", ctx do
      assign_role("Jacob Bannon", "Admin", ctx.org_id)
      assign_role("Jacob Bannon", "Member", ctx.org_id)
      {:ok, session} = Wallaby.start_session()

      session
      |> visit(ctx.path)
      # Service accounts are loaded asynchronously, so we need to wait a bit
      |> sleep(500)
      |> assert_number_of_role_labels(12)
    end

    test "if there is only 1 page, do not show buttons", ctx do
      ctx.page |> find(@load_more_btn)
      # We expect previous line to throw an exception, as that element should not be present
      assert false
    rescue
      _ -> assert true
    end
  end

  describe "project people" do
    setup [:setup_project]

    browser_test "adding people", ctx do
      with_mocks([
        {
          Front.Models.User,
          [:passthrough],
          [find: fn _ -> %{id: "1", name: "test"} end]
        }
      ]) do
        number = get_number_of_members(ctx.page)

        page =
          ctx.page
          |> click(@add_link)
          |> choose_user("Dimitri Minakakis")
          |> sleep(200)

        new_number = get_number_of_members(page)

        assert number + 1 == new_number

        true
      end
    end

    browser_test "remove user", ctx do
      test_remove_user(ctx)
    end

    browser_test "change role", ctx do
      test_change_role(ctx, "Admin", "Contributor")
    end

    browser_test "load more", ctx do
      # Adding another user to the projcet as well
      assign_role("Dimitri Minakakis", "Admin", ctx.stubs.org.id, ctx.stubs.project.id)
      test_load_more(ctx)
    end

    browser_test "when flag isn't enable, dont show remove button", ctx do
      Support.Stubs.Feature.disable_feature(ctx.stubs.org.id, :rbac__project_roles)
      Cachex.clear!(:feature_provider_cache)

      {:ok, session} = Wallaby.start_session()

      session =
        session
        |> visit(ctx.path)

      refute session |> has?(@remove_btn)
      refute session |> has?(@change_role_btn)
    end
  end

  ###
  ### Setups for different scenarios
  ###

  defp setup_project(%{session: session}) do
    stubs = Support.Browser.ProjectSettings.create_project()
    org = Support.Stubs.Organization.default()
    user = Support.Stubs.User.default()

    Support.Stubs.Feature.enable_feature(stubs.org.id, :rbac__project_roles)
    Support.Stubs.PermissionPatrol.allow_everything(org.id, user.id)

    assign_role("Jacob Bannon", "Admin", stubs.org.id, stubs.project.id)
    path = "/projects/#{stubs.project.name}/people"
    page = session |> visit(path)

    {:ok, %{page: page, path: path, stubs: stubs}}
  end

  defp setup_organization(%{session: session}) do
    Support.Stubs.init()
    Support.Stubs.build_shared_factories()
    org = Support.Stubs.Organization.default()
    user = Support.Stubs.User.default()

    Support.Stubs.PermissionPatrol.allow_everything(org.id, user.id)

    path = "/people"
    page = session |> visit(path)

    {:ok, %{page: page, path: path, org_id: org.id}}
  end

  ###
  ### All teste extracted in private functions
  ###

  defp test_remove_user(ctx) do
    number = get_number_of_members(ctx.page)
    new_page = ctx.page |> remove_user()
    new_number = get_number_of_members(new_page)
    assert number == new_number + 1

    true
  end

  defp test_change_role(ctx, current_role, new_role) do
    with_mocks([
      {
        Front.Models.User,
        [:passthrough],
        [find: fn _ -> %{id: "1", name: "test"} end]
      }
    ]) do
      ctx.page
      |> assert_selected_role(current_role)
      |> change_role(new_role)

      {:ok, session} = Wallaby.start_session()

      session
      |> visit(ctx.path)
      |> assert_selected_role(new_role)

      Wallaby.end_session(session)
    end

    true
  end

  defp test_load_more(ctx) do
    with_mocks([
      {
        Front.RBAC.Members,
        [:passthrough],
        [
          list_org_members: fn org_id ->
            Front.RBAC.Members.list_org_members(org_id, username: "", page_no: 0, page_size: 1)
          end,
          list_project_members: fn org_id, proj_id ->
            Front.RBAC.Members.list_project_members(org_id, proj_id,
              username: "",
              page_no: 0,
              page_size: 1
            )
          end
        ]
      }
    ]) do
      Application.put_env(:front, :test_page_size, 1)
      {:ok, session} = Wallaby.start_session()

      session
      |> visit(ctx.path)
      |> click(@load_more_btn)
      |> sleep(400)
      |> assert_button_disabled(@load_more_btn)

      Application.delete_env(:front, :test_page_size)
      true
    end
  end

  ###
  ### Helper functions
  ###

  defp assert_number_of_role_labels(page, expected_no) do
    role_label_css_selector = "span.f6.normal.ml1.ph1.br2"
    role_label_elems = all(page, Query.css(role_label_css_selector))

    assert length(role_label_elems) == expected_no
    true
  end

  defp assert_button_disabled(page, button_query) do
    button = page |> find(button_query)
    is_disabled = button |> Element.attr("disabled")
    assert is_disabled == "true"

    page
  end

  defp assert_selected_role(page, role_name) do
    role_label_css_selector = "span.f6.normal.ml1.ph1.br2"
    selected_role_query = Query.css(role_label_css_selector, count: :any, at: 0)
    selected_role = text(page, selected_role_query)

    assert selected_role == role_name

    page
  end

  defp change_role(page, role_name) do
    page
    |> click(@change_role_btn)
    |> click(Query.css("p.b.f5.mb0", text: role_name))
  end

  defp choose_user(page, name) do
    page
    |> fill_in(Query.text_field("Search users and groups to add to project"), with: name)
    |> sleep(500)
    |> send_keys([:enter])
    |> click(Query.css("button[id='add_members_btn']"))
  end

  defp get_number_of_members(page) do
    length(all(page, Query.css("#member")))
  end

  defp remove_user(page) do
    with_mocks([
      {
        Front.Models.User,
        [:passthrough],
        [find: fn _ -> %{id: "1", name: "test"} end]
      }
    ]) do
      accept_confirm(page, fn s -> click(s, @remove_btn) end)

      page
      |> sleep(500)
    end
  end

  defp assign_role(username, role_name, org_id, project_id \\ nil) do
    user_id = get_user(username)
    role = Support.Stubs.DB.find_by(:rbac_roles, :name, role_name)

    Support.Stubs.DB.insert(:subject_role_bindings, %{
      id: Support.Stubs.UUID.gen(),
      org_id: org_id,
      subject_id: user_id,
      role_id: role.id,
      project_id: project_id
    })
  end

  defp get_user(username) do
    rbac_user = Support.Stubs.DB.find_by(:subjects, :name, username)
    rbac_user.id
  end

  defp sleep(session, milliseconds) do
    :timer.sleep(milliseconds)
    session
  end
end
