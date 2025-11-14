defmodule Support.Browser.WorkflowEditor do
  use Wallaby.DSL

  alias Support.Stubs

  def init do
    Stubs.init()
    Stubs.build_shared_factories()

    :ok
  end

  def get_workflow do
    Stubs.DB.first(:workflows)
  end

  def create_self_hosted_agent(name) do
    Stubs.SelfHostedAgent.create(
      Stubs.Organization.default_org_id(),
      name
    )
  end

  def open(session, wf_id) do
    session |> visit("/workflows/#{wf_id}/edit")
  end

  @doc """
  Returns the YAML of the first pipeline as a Map. Example:

    ppl = session |> get_first_pipeline()

  """
  def get_first_pipeline(session) do
    {:ok, ppl} =
      Support.Browser.fetch_js_value(
        session,
        "return WorkflowEditor.workflow.findInitialPipeline().toJson()"
      )

    ppl
  end

  def first_block_yaml(page) do
    page
    |> get_first_pipeline()
    |> get_in(["blocks", Access.at(0)])
  end

  @doc """
  Selects a block in the diagram. Example:

    session |> select_block("Lint")

  """
  def select_block(session, block_name) do
    query = Query.css("#workflow-editor-diagram [data-type=block]", text: block_name)

    click(session, query)
  end

  def change_agent_env_type_for_pipeline(page, type) do
    page
    |> find(Query.select("Environment Type"), fn select ->
      select |> click(Query.option(type))
    end)
  end

  def change_agent_env_type_for_block(page, type) do
    page
    |> in_config("Agent", fn cfg ->
      cfg
      |> find(Query.select("Environment Type"), fn select ->
        select |> click(Query.option(type))
      end)
    end)
  end

  def select_first_block(page) do
    block_name = first_block_name(page)

    page |> select_block(block_name)
  end

  def first_block_name(page) do
    page
    |> get_first_pipeline()
    |> get_in(["blocks", Access.at(0), "name"])
  end

  @doc """
  Selects a pipeline in the diagram. Example:

    session |> select_pipeline("Lint")

  """
  def select_pipeline(session, name) do
    query = Query.css("#workflow-editor-diagram [data-type=pipeline]", text: name)

    session
    |> find(query, fn e ->
      e |> Wallaby.Element.click()
    end)
  end

  def select_first_pipeline(page) do
    name = first_pipeline_name(page)

    page |> select_pipeline(name)
  end

  def first_pipeline_name(page) do
    page
    |> get_first_pipeline()
    |> get_in(["name"])
  end

  @doc """
  Expands a config panel. Example:

    session |> expand_config("Secrets")

  """
  def expand_config(session, title) do
    query = Query.css("#workflow-editor-config-panel details summary", text: title)

    click(session, query)
  end

  def fill(session, query, value) do
    session
    |> find(query, fn e ->
      e |> Wallaby.Element.clear()
    end)
    |> find(query, fn e ->
      e |> Wallaby.Element.set_value(value)
    end)
  end

  @doc """
  Executes the callback inside of a config panel. Example:

  Select secret in Secrets config.

    session |> in_config("Secrets", fn cfg ->
      click(cfg, Query.css("input[type=checkbox]", text: "a"))
    end)

  """
  def in_config(session, title, callback) do
    query = Query.css("#workflow-editor-config-panel details", text: title)

    find(session, query, callback)
  end

  @doc """
  Updates the YAML code in the code editor.

  Example:
    change_code_in_editor(session, ".semaphore/semaphore.yml", "a: 12")

  """
  def change_code_in_editor(session, editor_title, new_yaml) do
    script =
      [
        "let e = WorkflowEditor.getCodeEditor(#{Poison.encode!(editor_title)})",
        "e.changeContent(#{Poison.encode!(new_yaml)})",
        "return true"
      ]
      |> Enum.join(";")

    session
    |> goto_code_editor(editor_title)
    |> execute_script(script)
  end

  def goto_code_editor(session, title) do
    session |> click(Query.css("#workflow-editor-tabs a", text: title))
  end

  def goto_visual_editor(session) do
    session |> click(Query.css("#workflow-editor-tabs a", text: "Visual Builder"))
  end

  def scroll_config_to_bottom(session) do
    script =
      [
        "let config = document.querySelector('#workflow-editor-config-panel-content')",
        "config.scrollTop = config.scrollHeight",
        "return true"
      ]
      |> Enum.join(";")

    session |> execute_script(script)
  end
end
