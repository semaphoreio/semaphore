defmodule Notifications.Util.Endpoint do
  import Bitwise
  require Record

  Record.defrecordp(
    :hackney_url,
    Record.extract(:hackney_url, from_lib: "hackney/include/hackney_lib.hrl")
  )

  @methods %{"" => :post, "post" => :post, "put" => :put, "patch" => :patch}

  @blocked_ipv4 [
    {{0, 0, 0, 0}, 8},
    {{10, 0, 0, 0}, 8},
    {{100, 64, 0, 0}, 10},
    {{127, 0, 0, 0}, 8},
    {{169, 254, 0, 0}, 16},
    {{172, 16, 0, 0}, 12},
    {{192, 0, 0, 0}, 24},
    {{192, 168, 0, 0}, 16},
    {{198, 18, 0, 0}, 15},
    {{224, 0, 0, 0}, 4},
    {{240, 0, 0, 0}, 4}
  ]

  @blocked_ipv6 [
    {{0x0064, 0xFF9B, 0x0001, 0, 0, 0, 0, 0}, 48},
    {{0x0100, 0, 0, 0, 0, 0, 0, 0}, 64},
    {{0x2001, 0, 0, 0, 0, 0, 0, 0}, 23},
    {{0x2002, 0, 0, 0, 0, 0, 0, 0}, 16},
    {{0xFC00, 0, 0, 0, 0, 0, 0, 0}, 7},
    {{0xFE80, 0, 0, 0, 0, 0, 0, 0}, 10},
    {{0xFEC0, 0, 0, 0, 0, 0, 0, 0}, 10},
    {{0xFF00, 0, 0, 0, 0, 0, 0, 0}, 8}
  ]

  @embedded_ipv4 [
    {{0, 0, 0, 0, 0, 0, 0, 0}, 96},
    {{0, 0, 0, 0, 0, 0xFFFF, 0, 0}, 96},
    {{0, 0, 0, 0, 0xFFFF, 0, 0, 0}, 96},
    {{0x0064, 0xFF9B, 0, 0, 0, 0, 0, 0}, 96}
  ]

  def validate_url(url) when is_binary(url) do
    uri = URI.parse(url)

    cond do
      not String.match?(url, ~r/\A[\x21-\x7E]+\z/) ->
        {:error, "Endpoint #{inspect(url)} contains characters that are not allowed in a URL"}

      uri.scheme not in ["http", "https"] or not String.starts_with?(url, uri.scheme <> "://") ->
        {:error, "Endpoint #{inspect(url)} must start with http:// or https://"}

      not is_binary(uri.host) or not String.match?(uri.host, ~r/\A[a-zA-Z0-9._:-]+\z/) or
          hackney_host(url) != String.downcase(uri.host) ->
        {:error, "Endpoint #{inspect(url)} does not have a valid host"}

      true ->
        :ok
    end
  end

  def validate_url(url),
    do: {:error, "Endpoint #{inspect(url)} must start with http:// or https://"}

  def method(nil), do: method("")

  def method(action) when is_binary(action) do
    case Map.fetch(@methods, String.downcase(action)) do
      {:ok, method} ->
        {:ok, method}

      :error ->
        {:error, "Webhook action #{inspect(action)} is not supported, use POST, PUT or PATCH"}
    end
  end

  def method(action),
    do: {:error, "Webhook action #{inspect(action)} is not supported, use POST, PUT or PATCH"}

  def check_destination(url) do
    with :ok <- validate_url(url),
         true <- Application.get_env(:notifications, :block_internal_endpoints, true) do
      host = URI.parse(url).host
      charlist = String.to_charlist(host)

      addresses =
        case :inet.parse_address(charlist) do
          {:ok, address} ->
            [address]

          {:error, _} ->
            Enum.flat_map([:inet, :inet6], fn family ->
              case :inet.getaddrs(charlist, family) do
                {:ok, addresses} -> addresses
                {:error, _} -> []
              end
            end)
        end

      cond do
        addresses == [] ->
          {:error, "Endpoint host #{host} could not be resolved"}

        Enum.any?(addresses, &blocked?/1) ->
          {:error, "Endpoint host #{host} resolves to an address that is not allowed"}

        true ->
          :ok
      end
    else
      {:error, _} = error -> error
      _guard_off -> :ok
    end
  end

  def blocked?(address = {_, _, _, _}), do: in_any?(address, @blocked_ipv4)

  def blocked?(address = {_, _, _, _, _, _, g, h}) do
    if in_any?(address, @embedded_ipv4) do
      blocked?({g >>> 8, g &&& 0xFF, h >>> 8, h &&& 0xFF})
    else
      in_any?(address, @blocked_ipv6)
    end
  end

  defp in_any?(address, ranges) do
    bits = if tuple_size(address) == 4, do: 8, else: 16
    width = tuple_size(address) * bits
    to_integer = fn parts -> parts |> Tuple.to_list() |> Enum.reduce(0, &(&2 <<< bits ||| &1)) end

    Enum.any?(ranges, fn {base, prefix} ->
      to_integer.(address) >>> (width - prefix) == to_integer.(base) >>> (width - prefix)
    end)
  end

  defp hackney_host(url) do
    url |> :hackney_url.parse_url() |> hackney_url(:host) |> to_string() |> String.downcase()
  rescue
    _ -> nil
  end
end
