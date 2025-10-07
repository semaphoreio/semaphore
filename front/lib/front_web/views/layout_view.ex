defmodule FrontWeb.LayoutView do
  use FrontWeb, :view
  alias Front.Async

  def login_url(conn) do
    org_id = conn.assigns.organization_id
    origin_url = Plug.Conn.request_url(conn)
    domain = Application.get_env(:front, :domain)

    "https://id.#{domain}/login?org_id=#{org_id}&redirect_to=#{origin_url}"
    |> URI.encode()
  end

  def logout_url(conn) do
    origin_url = Plug.Conn.request_url(conn)
    domain = Application.get_env(:front, :domain)

    "https://id.#{domain}/logout?back_url=#{origin_url}"
    |> URI.encode()
  end

  def signup_url(conn) do
    origin_url = Plug.Conn.request_url(conn)
    domain = Application.get_env(:front, :domain)

    "https://id.#{domain}/signup?redirect_to=#{origin_url}"
    |> URI.encode()
  end

  def me_url(conn) do
    me_host = Application.get_env(:front, :me_host)
    domain = Application.get_env(:front, :domain)

    # Dev environment only
    if me_host == nil do
      me_path(conn, :show)
    else
      "https://me.#{domain}"
    end
  end

  def organization_url(conn, org_username) do
    domain = Application.get_env(:front, :domain)
    env = Application.get_env(:front, :environment)

    if env == :dev do
      dashboard_path(conn, :index)
    else
      "https://#{org_username}.#{domain}"
    end
  end

  def render_layout(layout, assigns, do: content) do
    render(layout, Map.put(assigns, :nested_layout, content))
  end

  def header(conn) do
    if conn.assigns[:header] do
      {:ok, html} = Async.await(conn.assigns[:header])

      html
    else
      ""
    end
  end

  def sidebar(conn) do
    if conn.assigns[:sidebar] do
      {:ok, html} = Async.await(conn.assigns[:sidebar])

      html
    else
      ""
    end
  end

  def title(conn) do
    case conn.assigns[:title] do
      nil -> "Semaphore"
      title -> title
    end
  end

  def description(conn) do
    case project_and_org(conn) do
      nil ->
        ""

      {project, org} ->
        social_description(org, project)
    end
  end

  def social_metatags(conn) do
    if conn.assigns[:social_metatags] do
      case project_and_org(conn) do
        nil ->
          []

        {project, org} ->
          [
            meta_tag("twitter:image:src", social_image(org)),
            meta_tag("twitter:site", "@semaphoreci"),
            meta_tag("twitter:card", "summary"),
            meta_tag("twitter:title", social_title(org, project)),
            meta_tag("twitter:description", social_description(org, project)),
            meta_tag("og:image", social_image(org)),
            meta_tag("og:site_name", "Semaphore"),
            meta_tag("og:type", "object"),
            meta_tag("og:title", social_title(org, project)),
            meta_tag("og:url", social_url(conn, org, project)),
            meta_tag("og:description", social_description(org, project))
          ]
      end
    end
  end

  defp social_title(org, project) do
    "#{org.name}/#{project.name} CI/CD"
  end

  defp social_description(org, project) do
    [
      project.description,
      "View CI/CD pipelines of #{org.name}/#{project.name} on Semaphore."
    ]
    |> Enum.filter(fn s -> s != nil and s != "" end)
    |> Enum.join(". ")
  end

  defp social_url(conn, _org, project) do
    "#{conn.scheme}://#{conn.host}#{project_path(conn, :show, project.name)}"
  end

  defp social_image(_org) do
    "#{assets_path()}/images/semaphore-logo-320.png"
  end

  defp meta_tag(name, content) do
    [
      tag(:meta, name: name, content: content),
      "\n"
    ]
  end

  defp project_and_org(conn) do
    if conn.assigns[:project] == nil or conn.assigns[:organization] == nil do
      nil
    else
      {conn.assigns[:project], conn.assigns[:organization]}
    end
  end

  def tos_violation_suspension?(suspensions) do
    suspensions != nil && Enum.member?(suspensions, :VIOLATION_OF_TOS)
  end

  ### Project Layout

  def star_tippy_content(true), do: "Unstar Project"
  def star_tippy_content(false), do: "Star Project"

  def star_class(true), do: "yellow"
  def star_class(false), do: "washed-gray"

  @doc ~S"""
  Fetches organization id from connection's layout model

  ## Examples

    iex> org_id = Ecto.UUID.generate()
    iex> conn = Phoenix.ConnTest.build_conn() |> Plug.Conn.assign(:layout_model, %{current_organization: %{id: org_id}})
    iex> fetch_organization_id(conn)
    org_id

    iex> fetch_organization_id(Phoenix.ConnTest.build_conn())
    ""

    iex> fetch_organization_id(%{})
    ""
  """
  @spec fetch_organization_id(Plug.Conn.t()) :: String.t()
  def fetch_organization_id(conn) do
    conn
    |> layout_model()
    |> case do
      %{current_organization: %{id: id}} ->
        id

      _ ->
        ""
    end
    |> safe_string()
  end

  @doc ~S"""
  Fetches user id from connection's layout model

  ## Examples

    iex> user_id = Ecto.UUID.generate()
    iex> conn = Phoenix.ConnTest.build_conn() |> Plug.Conn.assign(:layout_model, %{user: %{id: user_id}})
    iex> fetch_user_id(conn)
    user_id

    iex> fetch_user_id(Phoenix.ConnTest.build_conn())
    ""

    iex> fetch_user_id(%{})
    ""
  """
  @spec fetch_user_id(Plug.Conn.t()) :: String.t()
  def fetch_user_id(conn) do
    conn
    |> layout_model()
    |> case do
      %{user: %{id: id}} ->
        id

      _ ->
        ""
    end
    |> safe_string()
  end

  @doc ~S"""
  Fetches user email from connection's layout model

  ## Examples

    iex> conn = Phoenix.ConnTest.build_conn() |> Plug.Conn.assign(:layout_model, %{user: %{email: "john@example.com"}})
    iex> fetch_user_email(conn)
    "john@example.com"

    iex> fetch_user_email(Phoenix.ConnTest.build_conn())
    ""

    iex> fetch_user_email(%{})
    ""
  """
  @spec fetch_user_email(Plug.Conn.t()) :: String.t()
  def fetch_user_email(conn) do
    conn
    |> layout_model()
    |> case do
      %{user: %{email: email}} ->
        email

      _ ->
        ""
    end
    |> safe_string()
  end

  @doc ~S"""
  Fetches layout model from connection

  ## Examples
    iex> conn = Phoenix.ConnTest.build_conn() |> Plug.Conn.assign(:layout_model, %{user_id: "1234"})
    iex> layout_model(conn)
    %{user_id: "1234"}

    iex> layout_model(Phoenix.ConnTest.build_conn())
    %{}
  """
  @spec layout_model(Plug.Conn.t()) :: map()
  def layout_model(conn) do
    conn
    |> case do
      %{assigns: %{layout_model: layout_model}} when is_map(layout_model) ->
        layout_model

      _ ->
        %{}
    end
  end

  @doc ~S"""
  Makes sure that passed variable can be safely used as a string.

  ## Examples

      iex> safe_string("test")
      "test"

      iex> safe_string(2134)
      ""

      iex> safe_string(nil)
      ""

      iex> safe_string(%{})
      ""
  """
  @spec safe_string(term()) :: String.t()
  def safe_string(var) when is_bitstring(var), do: var
  def safe_string(_var), do: ""

  @spec posthog_config_json(Plug.Conn.t()) :: binary()
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  def posthog_config_json(conn) do
    api_key = Application.get_env(:front, :posthog_api_key)
    api_host = Application.get_env(:front, :posthog_host)
    organization_id = Map.get(conn.assigns, :organization_id)
    user_id = Map.get(conn.assigns, :user_id)
    user_created_at = Map.get(conn.assigns, :user_created_at) |> to_iso8601()
    org_created_at = Map.get(conn.assigns, :organization_created_at) |> to_iso8601()

    feature_enabled? =
      organization_id
      |> case do
        nil ->
          # On /me page we don't have an organization_id. We still want to enable PostHog there.
          true

        _ ->
          FeatureProvider.feature_enabled?(:experimental_posthog, param: organization_id)
      end

    api_key_present? = api_key != "" and api_key != nil

    user_data_present? = user_id != "" and user_id != nil

    if feature_enabled? and api_key_present? and user_data_present? do
      %{
        apiKey: api_key,
        apiHost: api_host,
        organizationId: organization_id,
        organizationCreatedAt: org_created_at,
        userId: user_id,
        userCreatedAt: user_created_at
      }
    else
      %{}
    end
    |> Poison.encode!()
  end

  defp to_iso8601(nil), do: nil

  defp to_iso8601(seconds_str) when is_binary(seconds_str) do
    seconds_str
    |> String.to_integer()
    |> to_iso8601()
  end

  defp to_iso8601(seconds) when is_integer(seconds) do
    seconds
    |> DateTime.from_unix!()
    |> to_iso8601()
  end

  defp to_iso8601(datetime = %DateTime{}) do
    datetime
    |> DateTime.to_date()
    |> Date.to_iso8601()
  end

  defp protobuf_timestamp_to_datetime(%Google.Protobuf.Timestamp{seconds: s, nanos: _n})
       when is_integer(s) do
    DateTime.from_unix!(s)
  rescue
    _ -> nil
  end

  defp protobuf_timestamp_to_datetime(_), do: nil

  def license_soon_expiry?(%{valid: true, expires_at: expires_at}) when not is_nil(expires_at) do
    dt = protobuf_timestamp_to_datetime(expires_at)

    dt && DateTime.diff(dt, DateTime.now!("Etc/UTC"), :day) < 10 and
      DateTime.diff(dt, DateTime.now!("Etc/UTC"), :day) >= 0
  end

  def license_soon_expiry?(_), do: false

  @doc """
  Returns the license expiry date as a formatted string, or nil.
  """
  def license_expiry_date(%{expires_at: nil}), do: nil

  def license_expiry_date(%{expires_at: expires_at}) when is_binary(expires_at) do
    case DateTime.from_iso8601(expires_at) do
      {:ok, dt, _} -> format_utc(dt)
      _ -> expires_at
    end
  end

  def license_expiry_date(%{expires_at: %DateTime{} = expires_at}), do: format_utc(expires_at)

  def license_expiry_date(%{expires_at: %Google.Protobuf.Timestamp{} = expires_at}) do
    case protobuf_timestamp_to_datetime(expires_at) do
      nil -> nil
      dt -> format_utc(dt)
    end
  end

  def license_expiry_date(_), do: nil

  defp format_utc(dt = %DateTime{}) do
    dt = DateTime.shift_zone!(dt, "Etc/UTC")
    "#{dt.year}-#{pad(dt.month)}-#{pad(dt.day)} #{pad(dt.hour)}:#{pad(dt.minute)} UTC"
  end

  defp pad(n) when is_integer(n) and n < 10, do: "0" <> Integer.to_string(n)
  defp pad(n), do: Integer.to_string(n)
end
