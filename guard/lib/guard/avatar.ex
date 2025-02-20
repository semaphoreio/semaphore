defmodule Guard.Avatar do
  @github_avatars_base_url "https://avatars.githubusercontent.com/u"
  @semaphore_design_url "https://storage.googleapis.com/semaphore-design/release-465924d"

  def avatar_by_provider(provider_uid, "github") when is_binary(provider_uid) do
    github_avatar(provider_uid)
  end

  def avatar_by_provider(_provider_uid, _repo_host), do: default_provider_avatar()
  def default_provider_avatar, do: "#{@semaphore_design_url}/images/org-b.svg"

  def inject_avatar(members) when is_list(members),
    do: Enum.map(members, fn member -> inject_avatar(member) end) |> return_ok_tuple()

  def inject_avatar(member) when not is_nil(member) do
    Map.merge(member, %{avatar_url: extract_avatar(member)})
  end

  def inject_avatar(_), do: ""

  defp extract_avatar(member) do
    case extract_github_uid(member) do
      nil -> other_avatar(member)
      github_uid -> github_avatar(github_uid)
    end
  end

  defp extract_github_uid(%{providers: providers}) do
    Enum.find_value(providers, fn p -> if p.provider == "github", do: p.uid end)
  end

  defp extract_github_uid(%{provider: "github"} = member), do: member.uid
  defp extract_github_uid(_), do: nil

  def github_avatar(uid), do: "#{@github_avatars_base_url}/#{uid}?v=4"

  defp other_avatar(%{email: email, display_name: display_name})
       when is_nil(email) or email == "",
       do: fallback(display_name)

  defp other_avatar(%{email: email, display_name: display_name}),
    do: "#{gravatar(email)}?d=#{URI.encode_www_form(fallback(display_name))}"

  defp other_avatar(%{display_name: display_name}),
    do: fallback(display_name)

  defp gravatar(email),
    do: "https://secure.gravatar.com/avatar/#{md5(email)}"

  defp fallback(display_name),
    do:
      "https://ui-avatars.com/api/#{URI.encode_www_form(display_name)}/128/000000/ffffff/2/0.5/true/true/false/png"

  defp md5(value), do: :crypto.hash(:md5, value) |> Base.encode16(case: :lower)

  defp return_ok_tuple(value), do: {:ok, value}
end
