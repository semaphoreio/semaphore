defmodule Ppl.LatestWfs.Model.LatestWfsQueries do
  @moduledoc """
  LatestWfs Queries
  Operations on LatestWfs  type
  """

  import Ecto.Query

  alias Ppl.LatestWfs.Model.LatestWfs
  alias Util.ToTuple
  alias LogTee, as: LT
  alias Ppl.EctoRepo, as: Repo

  @doc """
  Insert or update  LatestWf record into DB with given parameters
  """
  def insert_or_update(latest_wf, ppl_req, wf_num) do
    params = form_params(ppl_req, wf_num)

    try do
      latest_wf |> LatestWfs.changeset(params) |> Repo.insert_or_update()
      |> process_response(params)
    rescue
      e -> {:error, e}
    catch
      a, b -> {:error, [a, b]}
    end
  end

  defp form_params(%{request_args: args, wf_id: wf_id}, wf_num) do
    %{
      organization_id: Map.get(args, "organization_id"),
      project_id:      Map.get(args, "project_id"),
      git_ref:         args |> Map.get("branch_name") |> ref(),
      git_ref_type:    args |> Map.get("branch_name") |> ref_type(),
      wf_id:           wf_id,
      wf_number:       wf_num
    }
  end

  def ref("refs/tags/" <> ref), do: ref
  def ref("pull-request-" <> ref), do: ref
  def ref(ref), do: ref

  def ref_type("refs/tags/" <> _rest), do: "tag"
  def ref_type("pull-request-" <> _rest), do: "pr"
  def ref_type(_rest), do: "branch"

  defp process_response({:error, %Ecto.Changeset{errors: [one_wf_per_git_ref_on_project: _message]}}, params) do
    params.git_ref
    |> LT.info("LatestWfsQueries.insert() - There is already latest_wf for project #{params.project_id}"
                <> " and #{params.git_ref_type} ")
    {:error, {:latest_wf_exists, params}}
  end
  defp process_response({:error, %Ecto.Changeset{errors: [{key, message}]}}, _) do
    {:error, Map.put(%{}, key, message)}
  end
  defp process_response({:ok, latest_wf}, params) do
    "wf_id: #{latest_wf.wf_id}, wf_number: #{latest_wf.wf_number}"
    |> LT.info("Project #{params.project_id} and #{params.git_ref_type} #{params.git_ref}"
                <> "latest_wf details updated")
    |> ToTuple.ok()
  end

  @doc """
  Finds LatestWf record for given pipeline
  """
  def lock_and_get(ppl) do
    {git_ref, git_ref_type} = {ref(ppl.branch_name), ref_type(ppl.branch_name)}
    lock_and_get_(ppl.project_id, git_ref, git_ref_type)
  end
  defp lock_and_get_(project_id, git_ref, git_ref_type) do
      LatestWfs
      |> where(project_id: ^project_id)
      |> where(git_ref_type: ^git_ref_type)
      |> where(git_ref: ^git_ref)
      |> lock("FOR UPDATE")
      |> Repo.one()
      |> return_tuple("LatestWfs for project #{project_id} and #{git_ref_type}"
                      <> " #{git_ref} not found.")
    rescue
      e -> {:error, e}
  end

  defp return_tuple(nil, nil_msg), do: ToTuple.error(nil_msg)
  defp return_tuple(value, _),     do: ToTuple.ok(value)
end
