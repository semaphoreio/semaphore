defmodule Front.WorkflowPage.Diagram.Topology do
  def assign(pipeline, topology, tasks) do
    pipeline
    |> join(tasks)
    |> match(topology)
  end

  defp join(pipeline, tasks) do
    blocks_with_tasks =
      Enum.map(pipeline.blocks, fn block ->
        task = tasks |> Enum.find(fn task -> block.build_request_id == task.request_token end)

        if task do
          block |> Map.put(:jobs, task.jobs)
        else
          block |> Map.put(:jobs, [])
        end
      end)

    pipeline |> Map.put(:blocks, blocks_with_tasks)
  end

  defp match(pipeline, topology) do
    #
    # Note: This method returns two different kind of objects, dependending
    # on the state of the blocks.
    #
    # - If the block is not yet created, it returns
    #   Pipeline.construct_from_topology blocks.
    #
    # - If the blocks is created, it returns Pipeline.construct_blocks
    #   format and injects dependencies and jobs.
    #

    blocks =
      Enum.map(topology.blocks, fn topology_block ->
        block = pipeline.blocks |> Enum.find(fn block -> block.name == topology_block.name end)

        if block do
          merge_topology_and_block_info(topology_block, block)
        else
          topology_block
        end
      end)

    pipeline |> Map.put(:blocks, blocks)
  end

  defp merge_topology_and_block_info(topology_block, block) do
    block = block |> Map.put(:dependencies, topology_block.dependencies)

    #
    # A finished block doesn't need to have jobs. For example, if the block
    # was skipped, it is :DONE and has no jobs.
    #
    # If the executed block has no jobs, we use the ones from the topology.
    # Otherwise, we merge the jobs with the block.
    #

    if Enum.empty?(block.jobs) do
      block |> Map.put(:jobs, topology_block.jobs)
    else
      jobs =
        topology_block.jobs
        |> Enum.with_index()
        |> Enum.map(fn {_topology_job, index} ->
          block.jobs |> Enum.find(fn job -> job.index == index end)
        end)

      block |> Map.put(:jobs, jobs)
    end
  end
end
