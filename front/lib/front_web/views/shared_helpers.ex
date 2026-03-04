defmodule FrontWeb.SharedHelpers do
  alias Front.Auth
  alias Front.Layout.Model, as: LayoutModel
  alias FrontWeb.Router.Helpers, as: RouteHelper
  require Logger

  @type renderable() :: nil | {:safe, String.t()}

  def sem_tooltip(anchor, options \\ [], do: block) do
    Phoenix.HTML.Tag.content_tag "sem-tooltip", options do
      [
        Phoenix.HTML.Tag.content_tag("slot", anchor, slot: "anchor"),
        Phoenix.HTML.Tag.content_tag("slot", block, slot: "content")
      ]
    end
  end

  def sem_popover(anchor, options \\ [], do: block) do
    Phoenix.HTML.Tag.content_tag "sem-popover", options do
      [
        Phoenix.HTML.Tag.content_tag("slot", anchor, slot: "anchor"),
        Phoenix.HTML.Tag.content_tag("slot", block, slot: "content")
      ]
    end
  end

  def public_page?(conn), do: Map.get(conn.assigns, :authorization) != :member

  def show_backend_badge? do
    Application.get_env(:front, :environment) == :dev
  end

  @spec livechat_enabled?(Conn.t()) :: {boolean, String.t()}
  def livechat_enabled?(conn) do
    zendesk_live_chat_enabled? =
      FeatureProvider.feature_enabled?(:zendesk_live_chat, param: conn.assigns[:organization_id])

    zendesk_snippet_id = Application.get_env(:front, :zendesk_snippet_id, "")

    # Pylon chat takes precedence over Zendesk live chat.
    enabled? =
      zendesk_live_chat_enabled? && zendesk_snippet_id != "" && not pylon_chat_enabled?(conn)

    {enabled?, zendesk_snippet_id}
  end

  @spec pylon_chat_widget_settings(Conn.t()) :: map() | nil
  def pylon_chat_widget_settings(conn) do
    org_id = conn.assigns[:organization_id]

    user =
      conn.assigns
      |> Map.get(:layout_model, %{})
      |> Map.get(:user)

    with true <- pylon_chat_enabled?(conn),
         %{email: email} <- user,
         true <- is_binary(email) and email != "",
         {:ok, app_id} <- pylon_chat_app_id(),
         {:ok, email_hash} <- pylon_chat_email_hash(email) do
      %{
        "app_id" => app_id,
        "email" => email,
        "name" => Map.get(user, :name, ""),
        "email_hash" => email_hash,
        "account_external_id" => org_id
      }
      |> maybe_put_avatar_url(Map.get(user, :avatar_url))
    else
      _ -> nil
    end
  end

  @spec pylon_chat_enabled?(Conn.t()) :: boolean()
  def pylon_chat_enabled?(conn) do
    org_id = conn.assigns[:organization_id]

    conn.assigns[:authorization] == :member and is_binary(org_id) and org_id != "" and
      FeatureProvider.feature_enabled?(:pylon_chat, param: org_id)
  end

  @spec pylon_chat_settings_json(map()) :: String.t()
  def pylon_chat_settings_json(settings), do: Poison.encode!(settings)

  @spec pylon_chat_script_url(String.t()) :: String.t()
  def pylon_chat_script_url(app_id), do: "https://widget.usepylon.com/widget/#{app_id}"

  defp maybe_put_avatar_url(settings, avatar_url)
       when is_binary(avatar_url) and avatar_url != "" do
    Map.put(settings, "avatar_url", avatar_url)
  end

  defp maybe_put_avatar_url(settings, _), do: settings

  defp pylon_chat_app_id do
    case Application.get_env(:front, :pylon_chat_app_id) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, :missing_pylon_chat_app_id}
    end
  end

  defp pylon_chat_email_hash(email) do
    with {:ok, secret} <- pylon_chat_identity_secret(),
         {:ok, secret_bytes} <- decode_hex(secret) do
      {:ok,
       :crypto.mac(:hmac, :sha256, secret_bytes, email)
       |> Base.encode16(case: :lower)}
    end
  end

  defp pylon_chat_identity_secret do
    case Application.get_env(:front, :pylon_chat_identity_secret) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, :missing_pylon_chat_identity_secret}
    end
  end

  defp decode_hex(value) do
    case Base.decode16(value, case: :mixed) do
      {:ok, decoded} -> {:ok, decoded}
      :error -> {:error, :invalid_pylon_chat_identity_secret}
    end
  end

  @spec gtag_enabled?(Conn.t()) :: {boolean, String.t()}
  def gtag_enabled?(_conn) do
    gtag = Application.get_env(:front, :google_gtag, "")

    {gtag != "", gtag}
  end

  def commit_message(hook) do
    hook.commit_message |> String.split("\n") |> List.first()
  end

  def commit_sha(hook) do
    hook.head_commit_sha |> String.slice(0..6)
  end

  def pr_commit_sha(hook) do
    hook.pr_sha |> String.slice(0..6)
  end

  def commit_author_string(hook) do
    if hook.commit_author != "" do
      " by #{hook.commit_author}"
    end
  end

  def commit_url(hook) do
    case URI.parse(hook.repo_host_url) do
      %{host: "bitbucket.org"} ->
        "#{hook.repo_host_url}/commits/#{hook.head_commit_sha}"

      %{host: "gitlab.com" = host, path: path} ->
        "https://#{host}#{remove_git_suffix(path)}/-/commit/#{hook.head_commit_sha}"

      _ ->
        "#{hook.repo_host_url}/commit/#{hook.head_commit_sha}"
    end
  end

  def pr_commit_url(hook) do
    case URI.parse(hook.repo_host_url) do
      %{host: "bitbucket.org"} ->
        "#{hook.repo_host_url}/commits/#{hook.pr_sha}"

      %{host: "gitlab.com" = host, path: path} ->
        "https://#{host}#{remove_git_suffix(path)}/-/commit/#{hook.pr_sha}"

      _ ->
        "#{hook.repo_host_url}/commit/#{hook.pr_sha}"
    end
  end

  def pr_url(hook) do
    case URI.parse(hook.repo_host_url) do
      %{host: "bitbucket.org"} ->
        "#{hook.repo_host_url}/pull-requests/#{hook.pr_number}"

      %{host: "gitlab.com" = host, path: path} ->
        "https://#{host}#{remove_git_suffix(path)}/-/merge_requests/#{hook.pr_number}"

      _ ->
        "#{hook.repo_host_url}/pull/#{hook.pr_number}"
    end
  end

  def format_date(time) do
    {:ok, formatted} =
      time
      |> DateTime.from_unix!()
      |> Timex.format("%FT%T%:z", :strftime)

    formatted
  end

  def branch_type_name(nil), do: branch_type_name("branch")
  def branch_type_name("branch"), do: "Branch"
  def branch_type_name("pr"), do: "Pull Request"
  def branch_type_name("pull-request"), do: "Pull Request"
  def branch_type_name("tag"), do: "Tag"
  def branch_type_name(hook), do: branch_type_name(hook.type)

  def wf_editor_push_branch(hook), do: wf_editor_push_branch(hook.type, hook.forked_pr, hook)
  def wf_editor_push_branch("branch", _, hook), do: hook.branch_name
  def wf_editor_push_branch("tag", _, hook), do: "semaphore_tag_#{hook.tag_name}"
  def wf_editor_push_branch("pr", true, hook), do: "semaphore_pr_#{hook.pr_number}"
  def wf_editor_push_branch("pr", false, hook), do: hook.pr_branch_name

  def wf_editor_init_branch(hook), do: wf_editor_init_branch(hook.type, hook.forked_pr, hook)
  def wf_editor_init_branch("branch", _, hook), do: hook.branch_name
  def wf_editor_init_branch("tag", _, hook), do: hook.branch_name
  def wf_editor_init_branch("pr", true, hook), do: hook.branch_name
  def wf_editor_init_branch("pr", false, hook), do: hook.pr_branch_name

  def human_accessible_repo_name(project) do
    "#{project.repo_owner}/#{project.repo_name}"
  end

  def human_accessible_repository_url(project) do
    case project.integration_type do
      :GITLAB ->
        "https://gitlab.com/#{project.repo_owner}/#{project.repo_name}"

      :BITBUCKET ->
        "https://bitbucket.org/#{project.repo_owner}/#{project.repo_name}"

      _ ->
        "https://github.com/#{project.repo_owner}/#{project.repo_name}"
    end
  end

  def human_accessible_repository_url(project, branch),
    do: human_accessible_repository_url(project, branch.type, branch)

  def human_accessible_repository_url(project, "tag", tag) do
    case project.integration_type do
      :GITLAB ->
        "#{human_accessible_repository_url(project)}/-/tags/#{tag.display_name}"

      :BITBUCKET ->
        "#{human_accessible_repository_url(project)}/src/#{tag.display_name}"

      _ ->
        "#{human_accessible_repository_url(project)}/tree/#{tag.name}"
    end
  end

  def human_accessible_repository_url(project, "branch", branch) do
    case project.integration_type do
      :GITLAB ->
        "#{human_accessible_repository_url(project)}/-/tree/#{branch.display_name}"

      :BITBUCKET ->
        "#{human_accessible_repository_url(project)}/src/#{branch.display_name}"

      _ ->
        "#{human_accessible_repository_url(project)}/tree/#{branch.name}"
    end
  end

  def human_accessible_repository_url(project, type, branch)
      when type in ["pr", "pull-request"] do
    case project.integration_type do
      :BITBUCKET ->
        "#{human_accessible_repository_url(project)}/pull-requests/#{branch.pr_number}"

      _ ->
        "#{human_accessible_repository_url(project)}/pull/#{branch.pr_number}"
    end
  end

  def assets_path, do: "/projects/assets"

  def image_source(name) do
    "#{assets_path()}/images/#{name}"
  end

  def icon(name) do
    icon(name, [])
  end

  def icon(%{integration_type: :GITLAB}, options),
    do: icon("icn-gitlab", options)

  def icon(%{integration_type: :BITBUCKET}, options),
    do: icon("icn-bitbucket", options)

  def icon(%{integration_type: _}, options),
    do: icon("icn-github", options)

  def icon("branch", options),
    do: icon("icn-branch", options)

  def icon("tag", options),
    do: icon("icn-tag", options)

  def icon("pr", options),
    do: icon("icn-pullrequest", options)

  def icon("pull-request", options),
    do: icon("icn-pullrequest", options)

  def icon(name, options) do
    [class: nil, width: nil, height: nil]
    |> Keyword.merge(options)
    |> raw_image_tag(name)
  end

  defp remove_git_suffix(path), do: String.replace_suffix(path, ".git", "")

  defp raw_image_tag(options, name) do
    image_tag =
      options
      |> Enum.into(%{})
      |> Map.take([:class, :width, :height, :data])
      |> Enum.filter(fn {_k, v} -> not is_nil(v) end)
      |> Enum.reduce(
        "<img src='#{assets_path()}/images/#{name}.svg'",
        fn
          {:data, v}, acc ->
            acc <>
              Enum.map_join(v, " ", fn {kk, vv} -> "data-#{Atom.to_string(kk)}='#{vv}'" end)

          {k, v}, acc ->
            acc <> " #{Atom.to_string(k)}='#{v}'"
        end
      )

    {:safe, image_tag <> ">"}
  end

  def can_manage_people?(user_id, organization_id) do
    Auth.manage_people?(user_id, organization_id)
  end

  def can_manage_billing?(user_id, organization_id) do
    can_manage_people?(user_id, organization_id)
  end

  def workflow_bg_class(workflow) do
    case workflow.state do
      :DONE ->
        case workflow.result do
          :PASSED -> "bg-lightest-green"
          :FAILED -> "bg-lightest-red"
          :CANCELED -> "bg-lightest-red"
          :STOPPED -> "bg-lightest-gray"
        end

      :RUNNING ->
        "bg-lightest-blue"

      :STOPPING ->
        "bg-lightest-orange"

      _ ->
        "bg-lightest-orange"
    end
  end

  def status_badge(pipeline) do
    case {pipeline.state, pipeline.result} do
      {:DONE, :PASSED} ->
        "<a href='/workflows/#{pipeline.workflow_id}?pipeline_id=#{pipeline.id}' class='link badge badge-passed'>Passed</a>"

      {:DONE, :FAILED} ->
        "<a href='/workflows/#{pipeline.workflow_id}?pipeline_id=#{pipeline.id}' class='link badge badge-failed'>Failed</a>"

      {:DONE, :CANCELED} ->
        "<a href='/workflows/#{pipeline.workflow_id}?pipeline_id=#{pipeline.id}' class='link badge badge-stopped'>Canceled</a>"

      {:DONE, :STOPPED} ->
        "<a href='/workflows/#{pipeline.workflow_id}?pipeline_id=#{pipeline.id}' class='link badge badge-stopped'>Stopped</a>"

      {:RUNNING, _} ->
        "<a href='/workflows/#{pipeline.workflow_id}?pipeline_id=#{pipeline.id}' class='link badge badge-running mt2 mt0-m'>Running</a>"

      {:STOPPING, _} ->
        "<a href='/workflows/#{pipeline.workflow_id}?pipeline_id=#{pipeline.id}' class='link badge badge-failed mt2 mt0-m'>Stopping</a>"

      _ ->
        "<a href='/workflows/#{pipeline.workflow_id}?pipeline_id=#{pipeline.id}' class='link badge badge-queue mt2 mt0-m'>Queued</a>"
    end
  end

  def status_text(pipeline) do
    case {pipeline.state, pipeline.result} do
      {:DONE, :PASSED} -> "Passed"
      {:DONE, :FAILED} -> "Failed"
      {:DONE, :CANCELED} -> "Canceled"
      {:DONE, :STOPPED} -> "Stopped"
      {:RUNNING, _} -> "Running"
      {:STOPPING, _} -> "Stopping"
      _ -> "Queued"
    end
  end

  # Input forms

  def branches_dropdown(branches) do
    branches
    |> Enum.with_index()
    |> Enum.map(fn {branch, index} -> compose_branch_option(branch, index) end)
  end

  defp compose_branch_option(branch, index) do
    if index == 0 do
      [key: branch, value: branch, selected: true]
    else
      [key: branch, value: branch]
    end
  end

  ## Input form errors handling

  def manage_error_message(:account_settings, validations, field) do
    if validations && validations.errors && validations.errors[field] do
      message = validations.errors[field]
      Phoenix.HTML.raw(~c"<div class=\"f5 mv1 red\">#{message}</div>")
    end
  end

  def manage_error_message(:project_delete, validations, field) do
    if validations && validations.errors && validations.errors[field] do
      message = validations.errors[field]
      Phoenix.HTML.raw(~c"<div class=\"f6 fw5 mt1 red\">#{message}</div>")
    end
  end

  def manage_error_message(:schedulers, validations, field) do
    if validations && validations.errors && validations.errors[field] do
      msg = validations.errors[field]
      Phoenix.HTML.raw(~c"<p class=\"f6 fw5 mt1 mb0 red\">#{msg}</p>")
    end
  end

  def manage_error_message(:secrets, validations, field) do
    if validations && validations.errors && validations.errors[field] do
      msg = validations.errors[field]
      Phoenix.HTML.raw(~c"<p class=\"f6 fw5 mt1 mb0 red\">#{msg}</p>")
    end
  end

  def manage_error_message(_form, validations, field) do
    if validations && validations.errors && validations.errors[field] do
      {msg, _opts} = validations.errors[field]
      Phoenix.HTML.raw(~c"<p class=\"f6 fw5 mt1 red\">#{msg}</p>")
    end
  end

  def manage_field_class(:project_delete, validations, field) do
    if validations && validations.errors && validations.errors[field] do
      "#{input_form_field_class(:project_delete, field)} form-control-error"
    else
      input_form_field_class(:project_delete, field)
    end
  end

  def manage_field_class(:schedulers, validations, field = :at) do
    if validations && validations.errors && validations.errors[field] do
      "form-control code form-control-error"
    else
      "form-control code"
    end
  end

  def manage_field_class(:schedulers, validations, field) do
    if validations && validations.errors && validations.errors[field] do
      "form-control w-100 w-50-m form-control-error"
    else
      "form-control w-100 w-50-m"
    end
  end

  def manage_field_class(_form, validations, field) do
    if validations && validations.errors && validations.errors[field] do
      "form-control w-100 form-control-error"
    else
      "form-control w-100"
    end
  end

  def input_form_field_class(:project_delete, :reason), do: "form-control w-100 w-auto-ns"
  def input_form_field_class(:project_delete, :feedback), do: "form-control w-100"
  def input_form_field_class(:project_delete, :delete_confirmation), do: "form-control w-100"

  def input_form_field_class(:notifications, _), do: "form-control w-100 w-75-m"

  def input_form_field_class(_, _) do
    "f5 black-50"
  end

  def map_repository_provider_key(key) do
    InternalApi.User.RepositoryProvider.Type.key(key)
    |> Atom.to_string()
    |> String.downcase()
  end

  # Layout Headers

  @doc """
  Returnes an element for navigation on project, workflow and job header.
  This function is used in project, workflow and job layouts.

  Values for type argument are: :project, :branch, :workflow.
  """
  def get_header_navigation_element(breadcrumbs, type, resource) when resource in [:name, :url] do
    breadcrumbs
    |> Enum.find(fn crumb -> crumb.type == type end)
    |> Map.get(resource)
  end

  def escape_unsafe_string(value) do
    value
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
  end

  def raw_safe_string(value) do
    value
    |> Phoenix.HTML.raw()
    |> Phoenix.HTML.safe_to_string()
  end

  def support_work_hours do
    "Monday–Friday: 7:00 a.m. to 8:00 p.m. UTC"
  end

  def provider_name("github"), do: "GitHub"
  def provider_name("bitbucket"), do: "Bitbucket"
  def provider_name("gitlab"), do: "GitLab"

  @spec contact_support_card(Plug.Conn.t(), LayoutModel.t()) :: renderable()
  def contact_support_card(conn, layout_model) do
    org_id = conn.assigns[:organization_id]
    valid_permissions? = layout_model.permissions["organization.contact_support"]

    with_zendesk_support? = FeatureProvider.feature_enabled?(:zendesk_support, param: org_id)
    with_pylon_help_dashboard? = pylon_help_dashboard_enabled_for_org?(org_id)

    organization_restricted? =
      FeatureProvider.feature_enabled?(:restricted_support, param: org_id)

    cond do
      with_pylon_help_dashboard? ->
        nil

      not with_zendesk_support? ->
        nil

      organization_restricted? and not valid_permissions? ->
        Phoenix.View.render(FrontWeb.LayoutView, "page_header/_menu_card.html",
          options: [disabled: true],
          card_url: "#",
          card_title: "Contact Support",
          card_description: support_card_subtitle(org_id),
          tooltip:
            "Your access to Semaphore support has been limited. Please contact your organization's Admin for more information."
        )

      true ->
        Phoenix.View.render(FrontWeb.LayoutView, "page_header/_menu_card.html",
          options: [target: "_blank", rel: "noopener"],
          card_url: Front.Zendesk.new_ticket_location(),
          card_title: "Contact Support",
          card_description: support_card_subtitle(org_id),
          tooltip: false
        )
    end
  end

  @spec pylon_contact_support_card(Plug.Conn.t(), LayoutModel.t()) :: renderable()
  def pylon_contact_support_card(conn, layout_model) do
    org_id = conn.assigns[:organization_id]
    valid_permissions? = layout_model.permissions["organization.contact_support"]

    with_pylon_help_dashboard? = pylon_help_dashboard_enabled_for_org?(org_id)

    organization_restricted? =
      FeatureProvider.feature_enabled?(:restricted_support, param: org_id)

    cond do
      not with_pylon_help_dashboard? ->
        nil

      organization_restricted? and not valid_permissions? ->
        Phoenix.View.render(FrontWeb.LayoutView, "page_header/_menu_card.html",
          options: [disabled: true],
          card_url: "#",
          card_title: "Support Portal",
          card_description: "Pylon knowledge base and support",
          tooltip:
            "Your access to Semaphore support has been limited. Please contact your organization's Admin for more information."
        )

      true ->
        Phoenix.View.render(FrontWeb.LayoutView, "page_header/_menu_card.html",
          options: [target: "_blank", rel: "noopener"],
          card_url: RouteHelper.support_path(conn, :pylon),
          card_title: "Support Portal",
          card_description: "Pylon knowledge base and support",
          tooltip: false
        )
    end
  end

  @spec support_requests_card(Plug.Conn.t(), LayoutModel.t()) :: renderable()
  def support_requests_card(conn, layout_model) do
    org_id = conn.assigns[:organization_id]
    valid_permissions? = layout_model.permissions["organization.contact_support"]

    if show_support_requests_card?(org_id, valid_permissions?) do
      Phoenix.View.render(FrontWeb.LayoutView, "page_header/_menu_card.html",
        options: [target: "_blank", rel: "noopener"],
        card_url: Front.Zendesk.my_tickets_location(),
        card_title: "My support requests",
        card_description: "Tickets you have previously opened",
        tooltip: false
      )
    end
  end

  def billing_card(conn, layout_model) do
    new_billing_enabled? =
      FeatureProvider.feature_enabled?(:new_billing, param: conn.assigns[:organization_id])

    legacy_billing_enabled? =
      FeatureProvider.feature_enabled?(:billing, param: conn.assigns[:organization_id])

    cond do
      new_billing_enabled? ->
        Phoenix.View.render(FrontWeb.LayoutView, "page_header/_menu_card.html",
          card_url: RouteHelper.billing_index_path(conn, :index, []),
          card_title: "Plans & Billing",
          card_description: "Spending, Plan and Invoices",
          tooltip: false
        )

      legacy_billing_enabled? ->
        Phoenix.View.render(FrontWeb.LayoutView, "page_header/_menu_card.html",
          card_url:
            "https://billing.#{Application.get_env(:front, :domain)}/?organization=#{layout_model.current_organization.username}",
          card_title: "Plans & Billing",
          card_description: "Spending, Plan and Invoicess",
          tooltip: false
        )

      true ->
        nil
    end
  end

  @spec support_card_subtitle(String.t()) :: String.t()
  defp support_card_subtitle(org_id) do
    on_premium_support? = FeatureProvider.feature_enabled?(:premium_support, param: org_id)
    on_advanced_support? = FeatureProvider.feature_enabled?(:advanced_support, param: org_id)

    if on_premium_support? or on_advanced_support? do
      "Report an issue"
    else
      support_work_hours()
    end
  end

  @spec pylon_help_dashboard_enabled?(Conn.t()) :: boolean()
  def pylon_help_dashboard_enabled?(conn) do
    org_id = conn.assigns[:organization_id]
    pylon_help_dashboard_enabled_for_org?(org_id)
  end

  defp pylon_help_dashboard_enabled_for_org?(org_id) do
    FeatureProvider.feature_enabled?(:pylon_support, param: org_id) and
      feature_enabled_any?(org_id, [
        :advanced_support,
        :premium_support,
        :"support-tier-3",
        :"support-tier-4"
      ])
  end

  defp show_support_requests_card?(org_id, valid_permissions?) do
    with_zendesk_support? = FeatureProvider.feature_enabled?(:zendesk_support, param: org_id)
    with_pylon_help_dashboard? = pylon_help_dashboard_enabled_for_org?(org_id)

    organization_restricted? =
      FeatureProvider.feature_enabled?(:restricted_support, param: org_id)

    premium_or_advanced? = feature_enabled_any?(org_id, [:premium_support, :advanced_support])

    with_zendesk_support? and not with_pylon_help_dashboard? and
      ((organization_restricted? and valid_permissions?) or
         (not organization_restricted? and premium_or_advanced?))
  end

  defp feature_enabled_any?(org_id, features) do
    features
    |> Enum.any?(&FeatureProvider.feature_enabled?(&1, param: org_id))
  end

  def pluralize(string, count) do
    count
    |> case do
      1 ->
        "#{count} #{string}"

      count ->
        "#{count} #{string}s"
    end
  end

  @doc """
  Formats file size in bytes to human-readable format
  """
  def format_file_size(size) when is_nil(size) or size == 0, do: "—"

  def format_file_size(size) when size < 1024, do: "#{size} B"

  def format_file_size(size) when size < 1024 * 1024 do
    kb = Float.round(size / 1024, 1)
    "#{kb} KB"
  end

  def format_file_size(size) when size < 1024 * 1024 * 1024 do
    mb = Float.round(size / (1024 * 1024), 1)
    "#{mb} MB"
  end

  def format_file_size(size) do
    gb = Float.round(size / (1024 * 1024 * 1024), 1)
    "#{gb} GB"
  end
end
