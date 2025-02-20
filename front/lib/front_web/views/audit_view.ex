defmodule FrontWeb.AuditView do
  use FrontWeb, :view

  def secret_options(changeset, secrets) do
    available_secrets = MapSet.new(secrets, & &1.name)

    selected_secret =
      changeset |> Ecto.Changeset.get_field(:secret_name, []) |> List.wrap() |> MapSet.new()

    stale_secrets = MapSet.difference(selected_secret, available_secrets)

    fresh_options = Enum.into(available_secrets, [], &to_fresh_option/1)
    stale_options = Enum.into(stale_secrets, [], &to_stale_option/1)
    fresh_options ++ stale_options
  end

  defp to_fresh_option(value), do: to_fresh_option(value, value)
  defp to_fresh_option(key, value), do: [key: key, value: value]

  defp to_stale_option(value), do: to_stale_option(value, value)
  defp to_stale_option(key, value), do: [key: key, value: value, disabled: true]

  @kb 1024
  @mb 1204 * @kb
  @gb 1204 * @mb
  @tb 1204 * @gb

  def audit_file_size(size_in_bytes) when size_in_bytes < @kb, do: "#{size_in_bytes}B"
  def audit_file_size(size_in_bytes) when size_in_bytes < @mb, do: "#{div(size_in_bytes, @kb)}KB"
  def audit_file_size(size_in_bytes) when size_in_bytes < @gb, do: "#{div(size_in_bytes, @mb)}MB"
  def audit_file_size(size_in_bytes) when size_in_bytes < @tb, do: "#{div(size_in_bytes, @gb)}GB"

  def audit_file_size(_size_in_bytes),
    do: raise("this can't be right, audit log can't be in terrabytes")
end
