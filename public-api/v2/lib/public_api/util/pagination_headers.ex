defmodule PublicAPI.Util.Headers do
  @moduledoc """
  Helpers for paginating API responses with [Scrivener](https://github.com/drewolson/scrivener) and HTTP headers. Implements [RFC-5988](https://mnot.github.io/I-D/rfc5988bis/), the proposed standard for Web linking.

  Use `paginate/2` to set the pagination headers:

      def index(conn, params) do
        page = MyApp.Person
               |> where([p], p.age > 30)
               |> order_by([p], desc: p.age)
               |> preload(:friends)
               |> MyApp.Repo.paginate(params)

        conn
        |> PublicAPI.Util.Headers.paginate(page)
        |> render("index.json", people: page.entries)
      end
  """

  import Plug.Conn, only: [put_resp_header: 3, get_req_header: 2]

  @default_header_keys %{
    link: "link",
    next_page_token: "next-page-token",
    prev_page_token: "previous-page-token",
    per_page: "per-page"
  }

  @doc """
  Add HTTP headers for a `PublicAPI.Util.Page`.
  """
  @spec paginate(Plug.Conn.t(), PublicAPI.Util.Page.t(), opts :: keyword()) :: Plug.Conn.t()
  def paginate(conn, page, opts \\ [])

  def paginate(conn, page, opts) do
    use_x_forwarded = Keyword.get(opts, :use_x_forwarded, false)
    header_keys = generate_header_keys(opts)
    uri = generate_uri(conn, use_x_forwarded)
    page = page_struct(page)
    do_paginate(conn, page, uri, header_keys)
  end

  defp page_struct(page = %PublicAPI.Util.Page{}), do: page
  defp page_struct(page), do: struct(PublicAPI.Util.Page, page)

  defp generate_uri(conn, true) do
    %URI{
      scheme: get_x_forwarded_or_conn(conn, :scheme, "proto", &Atom.to_string/1),
      host: get_x_forwarded_or_conn(conn, :host, "host"),
      port: get_x_forwarded_or_conn(conn, :port, "port", & &1, &String.to_integer/1),
      path: conn.request_path,
      query: conn.query_string
    }
  end

  defp generate_uri(conn, false) do
    %URI{
      scheme: Atom.to_string(conn.scheme),
      host: conn.host,
      port: conn.port,
      path: conn.request_path,
      query: conn.query_string
    }
  end

  defp do_paginate(conn, page, uri, header_keys) do
    conn
    |> put_resp_header(header_keys.link, build_link_header(uri, page))
    |> put_resp_header(header_keys.per_page, Integer.to_string(page.page_size))
    |> maybe_put_header(header_keys.next_page_token, page.next_page_token)
    |> maybe_put_header(header_keys.prev_page_token, page.prev_page_token)
  end

  defp maybe_put_header(conn, key, value) when is_binary(value) and value != "",
    do: put_resp_header(conn, key, value)

  defp maybe_put_header(conn, _, _), do: conn

  defp get_x_forwarded_or_conn(
         conn,
         conn_prop,
         header_name,
         parse_conn \\ & &1,
         parse_header \\ & &1
       ) do
    case get_req_header(conn, "x-forwarded-#{header_name}") do
      [] -> conn |> Map.get(conn_prop) |> parse_conn.()
      [value | _] -> parse_header.(value)
    end
  end

  @spec build_link_header(URI.t(), PublicAPI.Util.Page.t()) :: String.t()
  defp build_link_header(uri, page = %{}) do
    prev_page = {Map.get(page, :prev_page_token, ""), page.prev_page_dir, page.with_direction}
    next_page = {Map.get(page, :next_page_token, ""), page.next_page_dir, page.with_direction}
    first_page = {"", page.next_page_dir, page.with_direction}

    [link_str(uri, first_page, "first")]
    |> maybe_add(uri, prev_page, "prev")
    |> maybe_add(uri, next_page, "next")
    |> Enum.join(", ")
  end

  @spec link_str(URI.t(), {String.t(), String.t(), boolean()}, String.t()) :: String.t()
  defp link_str(uri = %{query: req_query}, {token, dir, with_dir?}, rel) do
    query =
      req_query
      |> URI.decode_query()
      |> Map.put("page_token", token)
      |> maybe_put("direction", with_dir?, dir)
      |> URI.encode_query()

    uri_str =
      %URI{uri | query: query}
      |> URI.to_string()

    ~s(<#{uri_str}>; rel="#{rel}")
  end

  defp maybe_add(links, uri, page_token = {token, _, _}, rel)
       when token != "" and not is_nil(token) do
    [link_str(uri, page_token, rel) | links]
  end

  defp maybe_add(links, _uri, _token, _rel) do
    links
  end

  defp maybe_put(query, key, maybe, value) when maybe, do: Map.put(query, key, value)
  defp maybe_put(query, _key, maybe, _value) when not maybe, do: query

  defp generate_header_keys(header_keys: header_keys) do
    custom_header_keys = Map.new(header_keys)

    Map.merge(@default_header_keys, custom_header_keys)
  end

  defp generate_header_keys(_), do: @default_header_keys
end
