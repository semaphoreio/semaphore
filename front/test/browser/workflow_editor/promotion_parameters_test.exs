defmodule Front.Browser.WorkflowEditor.PromotionParametersTest do
  use FrontWeb.WallabyCase

  alias Support.Browser.WorkflowEditor, as: Editor

  @add_env_var_buttom Query.css("a", text: "+ Add Environment Variable")
  @input_name Query.data("action", "changePromotionParameterEnvName")
  @input_description Query.data("action", "changePromotionParameterEnvDescription")
  @input_default Query.data("action", "changePromotionParameterEnvDefault")
  @input_options Query.data("action", "changePromotionParameterEnvOptions")
  @input_required Query.data("action", "changePromotionParameterEnvRequired")

  setup %{session: session} do
    Editor.init()

    Support.Stubs.PermissionPatrol.allow_everything()

    workflow = Editor.get_workflow()

    page = Editor.open(session, workflow.id)
    page = page |> click(Query.data("action", "addPromotion"))

    {:ok, %{page: page}}
  end

  browser_test "adding a required promotion parameter", %{page: page} do
    page
    |> click(@add_env_var_buttom)
    |> Editor.fill(@input_name, "SERVER")
    |> Editor.fill(@input_description, "Server where to deploy to")
    |> Editor.fill(@input_default, "1.2.3.4")
    |> Editor.fill(@input_options, "2.3.4.5\n5.6.7.8")
    |> Editor.scroll_config_to_bottom()
    |> click(Query.css("body"))

    yaml = last_promotion_yaml(page)
    assert length(yaml["parameters"]["env_vars"]) == 1

    param = hd(assert yaml["parameters"]["env_vars"])

    assert param["name"] == "SERVER"
    assert param["description"] == "Server where to deploy to"
    assert param["default_value"] == "1.2.3.4"
    assert param["options"] == ["2.3.4.5", "5.6.7.8"]
    assert param["required"] == true
  end

  browser_test "adding an optional promotion parameter", %{page: page} do
    page
    |> click(@add_env_var_buttom)
    |> Editor.fill(@input_name, "SERVER")
    |> Editor.fill(@input_description, "Server where to deploy to")
    |> Editor.fill(@input_default, "1.2.3.4")
    |> Editor.fill(@input_options, "2.3.4.5\n5.6.7.8")
    |> Editor.scroll_config_to_bottom()
    |> click(@input_required)

    yaml = last_promotion_yaml(page)
    assert length(yaml["parameters"]["env_vars"]) == 1

    param = hd(assert yaml["parameters"]["env_vars"])

    assert param["name"] == "SERVER"
    assert param["description"] == "Server where to deploy to"
    assert param["default_value"] == "1.2.3.4"
    assert param["options"] == ["2.3.4.5", "5.6.7.8"]
    assert param["required"] == false
  end

  #
  # Utils
  #

  def select_first_pipeline(page) do
    name = first_pipeline_name(page)

    page |> Editor.select_pipeline(name)
  end

  def first_pipeline_name(page) do
    page |> Editor.get_first_pipeline() |> get_in(["name"])
  end

  def last_promotion_yaml(page) do
    page |> Editor.get_first_pipeline() |> get_in(["promotions"]) |> List.last()
  end
end
