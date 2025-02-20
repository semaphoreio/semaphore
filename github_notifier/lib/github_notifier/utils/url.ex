defmodule GithubNotifier.Utils.Url do
  def prepare(project, wf_id, ppl_id, to_summary_tab? \\ false) do
    organization = GithubNotifier.Models.Organization.find(project.org_id)

    summary_tab_fragment =
      if to_summary_tab? do
        "/summary"
      else
        ""
      end

    "https://#{organization.name}.#{Application.fetch_env!(:github_notifier, :host)}/workflows/#{wf_id}#{summary_tab_fragment}?pipeline_id=#{ppl_id}"
  end
end
