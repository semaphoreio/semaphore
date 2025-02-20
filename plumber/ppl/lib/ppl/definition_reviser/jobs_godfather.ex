defmodule Ppl.DefinitionReviser.JobsGodfather do
  @moduledoc """
  Validates that all non-blank job and booster names within block are unique and
  fills empty ones.
  """

  alias Util.ToTuple

  def name_jobs(definition) do
    with {:ok, definition} <- do_name_jobs(definition, "blocks"),
         {:ok, definition} <- do_name_jobs(definition, "after_pipeline")
    do
      ToTuple.ok(definition)
    end
  end

  defp do_name_jobs(definition, "blocks") do
    with {:ok, blocks} <- Map.fetch(definition, "blocks"),
         {:ok, baptized_jobs} <- set_names_for_nameless_jobs(blocks),
         do: {:ok, Map.put(definition, "blocks", baptized_jobs)}
  end

  defp do_name_jobs(definition, "after_pipeline") do
    Map.get(definition, "after_pipeline")
    |> case do
      nil ->
        {:ok, definition}

      _ ->
        with {:ok, blocks} <- Map.fetch(definition, "after_pipeline"),
             {:ok, baptized_jobs} <- set_names_for_nameless_jobs(blocks),
             do: {:ok, Map.put(definition, "after_pipeline", baptized_jobs)}
    end
  end

  defp set_names_for_nameless_jobs(blocks) do
    blocks
    |> Enum.reduce([], &process_block(&1, &2))
    |> Enum.reverse
    |> ToTuple.ok()
  catch
    e -> e
  end

  defp process_block(block, block_acc) do
    {jobs, boosters, all_names} = get_block_parts(block)

    with {:ok, :no_duplicates} <- validate_user_defined_names(all_names),
         {jobs, all_names, _} <- fill_in_empty_names(jobs, all_names),
         {boosters, _, _} <- fill_in_empty_names(boosters, all_names) do
      update_block_acc(block_acc, block, jobs, boosters)
    else
      e -> throw e
    end
  end

  defp get_block_parts(block) do
    jobs = get_in(block, ["build", "jobs"]) |> List.wrap
    boosters = get_in(block, ["build", "boosters"]) |> List.wrap
    all_names = jobs ++ boosters |> Enum.map(&Map.get(&1, "name"))

    {jobs, boosters, all_names}
  end

  defp validate_user_defined_names(all_names),
    do: all_names |> get_duplicate_job_names |> validate_job_names

  defp get_duplicate_job_names(all_names) do
    all_names
    |> Enum.reject(&is_nil/1)
    |> Enum.sort
    |> Enum.chunk_by(fn x -> x end)
    |> Enum.filter(fn name_group -> length(name_group) > 1 end)
  end

  defp validate_job_names(duplicates) when duplicates == [],
    do: {:ok, :no_duplicates}
  defp validate_job_names(duplicates),
    do: {:error, {:malformed, {:duplicate_names, duplicates}}}

  defp fill_in_empty_names(jobs, all_names) when jobs != [] do
    Enum.reduce(jobs, {[], all_names, 1}, fn job, {job_acc, all_names, i} ->
      case Map.get(job, "name") do
        nil ->
          {name, i} = unique_name(i, all_names)
          {
            [Map.put(job, "name", name) | job_acc],
            [name | all_names],
            i + 1
          }
        _ ->
          {[job | job_acc], all_names, i}
      end
    end)
    |> reverse_first_element
  end
  defp fill_in_empty_names(jobs, all_names),
    do: {jobs, all_names, 0}

  defp update_block_acc(block_acc, block, jobs, boosters) do
    block
    |> update_block("jobs", jobs)
    |> update_block("boosters", boosters)
    |> do_update_block_acc(block_acc)
  end

  defp update_block(block, _, []), do: block
  defp update_block(block, key, value), do: put_in(block, ["build", key], value)

  defp do_update_block_acc(block, block_acc), do: [block | block_acc]

  defp unique_name(i, all_names) do
    name = "Nameless #{i}"
    if name in all_names, do: unique_name(i + 1, all_names), else: {name, i}
  end

  defp reverse_first_element({list, x, y}), do: {Enum.reverse(list), x, y}
end
