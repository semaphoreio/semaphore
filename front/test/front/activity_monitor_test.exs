defmodule Front.ActivityMonitor.Test do
  use ExUnit.Case

  import Mock

  alias Front.ActivityMonitor.{Activity, AgentStats, Items}

  alias Front.ActivityMonitor.Repo

  setup do
    Support.Stubs.Feature.set_org_defaults("org_1")

    :ok
  end

  test "valid data from repo => valid Activity structure is returned" do
    with_mock Repo, load: &mocked_repo_load(&1, &2, &3) do
      assert activity_data = Front.ActivityMonitor.load("org_1", "user_1", nil)

      assert %Activity{
               org_name: "TestOrg",
               org_path: "/organization",
               default_priority: 50,
               increase_quota_link: "/increase_quota",
               agent_stats: agent_stats,
               items: items
             } = activity_data

      assert %AgentStats{agent_types: agent_types} = agent_stats

      assert [
               %{
                 name: "a1-standard-4",
                 occupied_count: 1,
                 waiting_count: 3,
                 total_count: 2
               },
               %{
                 name: "a1-standard-8",
                 occupied_count: 1,
                 waiting_count: 0,
                 total_count: 2
               },
               %{
                 name: "e1-standard-2",
                 occupied_count: 3,
                 waiting_count: 2,
                 total_count: 8
               },
               %{
                 name: "e1-standard-4",
                 occupied_count: 1,
                 waiting_count: 1,
                 total_count: 8
               },
               %{
                 name: "e1-standard-8",
                 occupied_count: 2,
                 waiting_count: 0,
                 total_count: 2
               }
             ] == agent_types

      assert_valid_items_in_response(items)
    end
  end

  test "when there are no active pipelines => valid empty Activity structure is returned" do
    with_mock Repo, load: &empty_mock(&1, &2, &3) do
      assert activity_data = Front.ActivityMonitor.load("org_1", "user_1", nil)

      assert %Activity{
               org_name: "TestOrg",
               org_path: "/organization",
               default_priority: 50,
               increase_quota_link: "/increase_quota",
               agent_stats: agent_stats,
               items: items
             } = activity_data

      assert items == %Items{
               lobby: %Front.ActivityMonitor.Lobby{
                 non_visible_pipelines_count: 0,
                 items: []
               },
               waiting: %Front.ActivityMonitor.Waiting{
                 non_visible_job_count: 0,
                 items: []
               },
               running: %Front.ActivityMonitor.Running{
                 non_visible_job_count: 0,
                 items: []
               }
             }

      assert %AgentStats{agent_types: agent_types} = agent_stats

      assert [
               %{
                 name: "a1-standard-4",
                 occupied_count: 0,
                 waiting_count: 0,
                 total_count: 2
               },
               %{
                 name: "a1-standard-8",
                 occupied_count: 0,
                 waiting_count: 0,
                 total_count: 2
               },
               %{
                 name: "e1-standard-2",
                 occupied_count: 0,
                 waiting_count: 0,
                 total_count: 8
               },
               %{
                 name: "e1-standard-4",
                 occupied_count: 0,
                 waiting_count: 0,
                 total_count: 8
               },
               %{
                 name: "e1-standard-8",
                 occupied_count: 0,
                 waiting_count: 0,
                 total_count: 2
               }
             ] == agent_types
    end
  end

  def empty_mock(_, _, _) do
    {:ok,
     %{
       accessable_projects: [
         %{
           description: "The coolest project",
           id: "78114608-be8a-465a-b9cd-81970fb802c6",
           name: "renderedtext"
         }
       ],
       active_debug_sessions: [],
       active_jobs: [],
       active_pipelines: [],
       org: %{
         avatar_url: "avatar1.jpg",
         created_at: DateTime.utc_now(),
         name: "TestOrg",
         open_source: false,
         org_id: "78114608-be8a-465a-b9cd-81970fb802c7",
         org_username: "renderedtext",
         owner_id: "",
         quotas: [
           %{type: :MAX_PARALLEL_E1_STANDARD_2, value: 12},
           %{type: :MAX_PARALLEL_E1_STANDARD_4, value: 8},
           %{type: :MAX_PARALLEL_E1_STANDARD_8, value: 6},
           %{type: :MAX_PARALLEL_A1_STANDARD_4, value: 4}
         ],
         suspended: false
       },
       users: []
     }}
  end

  def mocked_repo_load(_, _, _) do
    {:ok,
     %{
       org: org(),
       accessable_projects: [%{id: "pr_1", name: "front"}, %{id: "pr_3", name: "zebra"}],
       users: users(),
       active_pipelines: pipelines(),
       active_jobs: jobs(),
       active_debug_sessions: debugs()
     }}
  end

  defp users do
    [
      %{id: "user_1", name: "Petar", avatar_url: "avatar1.jpg"},
      %{id: "user_2", name: "Igor", avatar_url: "avatar2.jpg"},
      %{id: "user_3", name: "Marko", avatar_url: "avatar3.jpg"},
      %{id: "user_4", name: "Darko", avatar_url: "avatar4.jpg"},
      %{id: "user_5", name: "Nandor", avatar_url: "avatar5.jpg"},
      %{id: "user_6", name: "Lukas", avatar_url: "avatar6.jpg"}
    ]
  end

  defp org do
    %{
      name: "TestOrg",
      org_id: "org_1",
      org_username: "testorg",
      quotas: [
        %{type: :MAX_PARALLEL_E1_STANDARD_2, value: 12},
        %{type: :MAX_PARALLEL_E1_STANDARD_4, value: 8},
        %{type: :MAX_PARALLEL_E1_STANDARD_8, value: 6},
        %{type: :MAX_PARALLEL_A1_STANDARD_4, value: 4}
      ]
    }
  end

  defp pipelines do
    [
      # Pipelines in Running section
      %{
        project_id: "pr_1",
        requester_id: "user_1",
        promoter_id: "",
        name: "Unit tests",
        commit_message: "Merge Pull Request #48: Increase Profitability",
        commiter_username: "",
        commiter_avatar_url: "",
        wf_id: "wf_1",
        ppl_id: "ppl_1",
        git_ref: "master",
        git_ref_type: :BRANCH,
        created_at: "2 days ago",
        priority: 50,
        state: :RUNNING,
        branch_id: "123",
        blocks: [
          %{
            state: :RUNNING,
            jobs: [
              %{machine_type: "e1-standard-2", state: :STARTED, status: "scheduled"},
              %{machine_type: "e1-standard-2", state: :STARTED, status: "scheduled"},
              %{machine_type: "e1-standard-4", state: :STARTED, status: "scheduled"}
            ]
          },
          %{state: :WAITING, jobs: [%{status: "pending"}, %{status: "pending"}]}
        ]
      },
      %{
        project_id: "pr_2",
        requester_id: "user_2",
        promoter_id: "",
        name: "Unit tests",
        commit_message: "Merge Pull Request #49",
        commiter_username: "",
        commiter_avatar_url: "",
        wf_id: "wf_2",
        ppl_id: "ppl_2",
        git_ref: "v1.0",
        git_ref_type: :TAG,
        created_at: "2 days ago",
        priority: 50,
        state: :RUNNING,
        branch_id: "123",
        blocks: [
          %{
            state: :RUNNING,
            jobs: [
              %{machine_type: "e1-standard-2", state: :STARTED, status: "scheduled"},
              %{machine_type: "a1-standard-4", state: :STARTED, status: "scheduled"}
            ]
          },
          %{state: :WAITING, jobs: [%{status: "pending"}, %{status: "pending"}]}
        ]
      },
      # Pipelines in waiting section
      %{
        project_id: "pr_3",
        requester_id: "user_2",
        promoter_id: "user_3",
        name: "Unit tests",
        commit_message: "Change text color",
        commiter_username: "",
        commiter_avatar_url: "",
        wf_id: "wf_3",
        ppl_id: "ppl_3",
        git_ref: "pull-request-123",
        git_ref_type: :PR,
        created_at: "2 days ago",
        priority: 50,
        state: :RUNNING,
        branch_id: "123",
        blocks: [
          %{
            state: :RUNNING,
            jobs: [
              %{machine_type: "e1-standard-2", state: :ENQUEUED, status: "scheduled"},
              %{machine_type: "a1-standard-4", state: :ENQUEUED, status: "scheduled"},
              %{machine_type: "e1-standard-4", state: :ENQUEUED, status: "scheduled"}
            ]
          },
          %{state: :WAITING, jobs: [%{status: "pending"}, %{status: "pending"}]}
        ]
      },
      %{
        project_id: "pr_2",
        requester_id: "user_2",
        promoter_id: "",
        name: "Unit tests",
        commit_message: "Merge Pull Request #49",
        commiter_username: "",
        commiter_avatar_url: "",
        wf_id: "wf_4",
        ppl_id: "ppl_4",
        git_ref: "v1.0",
        git_ref_type: :TAG,
        created_at: "2 days ago",
        priority: 50,
        state: :RUNNING,
        branch_id: "123",
        blocks: [
          %{
            state: :RUNNING,
            jobs: [
              %{machine_type: "e1-standard-2", state: :ENQUEUED, status: "scheduled"},
              %{machine_type: "a1-standard-4", state: :ENQUEUED, status: "scheduled"}
            ]
          },
          %{state: :WAITING, jobs: [%{status: "pending"}, %{status: "pending"}]}
        ]
      },
      # Pipelines in Lobby section
      %{
        project_id: "pr_3",
        requester_id: "",
        promoter_id: "",
        name: "Unit tests",
        commit_message: "Change text color",
        commiter_username: "Non_Semaphore_user",
        commiter_avatar_url: "github_avatar.jpg",
        wf_id: "wf_5",
        ppl_id: "ppl_5",
        git_ref: "master",
        git_ref_type: :BRANCH,
        created_at: "2 days ago",
        priority: 50,
        state: :QUEUING,
        branch_id: "123",
        blocks: [
          %{state: :WAITING, jobs: [%{status: "pending"}, %{status: "pending"}]},
          %{state: :WAITING, jobs: [%{status: "pending"}, %{status: "pending"}]}
        ]
      },
      %{
        project_id: "pr_2",
        requester_id: "user_1",
        promoter_id: "",
        name: "Unit tests",
        commit_message: "Change text color",
        commiter_username: "",
        commiter_avatar_url: "",
        wf_id: "wf_6",
        ppl_id: "ppl_6",
        git_ref: "master",
        git_ref_type: :BRANCH,
        created_at: "2 days ago",
        priority: 50,
        state: :QUEUING,
        branch_id: "123",
        blocks: [
          %{state: :WAITING, jobs: [%{status: "pending"}, %{status: "pending"}]},
          %{state: :WAITING, jobs: [%{status: "pending"}, %{status: "pending"}]}
        ]
      }
    ]
  end

  defp jobs do
    [
      # e1-standard-2
      %{machine_type: "e1-standard-2", priority: 100, state: :STARTED},
      %{machine_type: "e1-standard-2", priority: 50, state: :STARTED},
      %{machine_type: "e1-standard-2", priority: 80, state: :STARTED},
      %{machine_type: "e1-standard-2", priority: 50, state: :ENQUEUED},
      %{machine_type: "e1-standard-2", priority: 50, state: :ENQUEUED},
      # e1-standard-4
      %{machine_type: "e1-standard-4", priority: 50, state: :STARTED},
      %{machine_type: "e1-standard-4", priority: 50, state: :ENQUEUED},
      # a1-standard-4
      %{machine_type: "a1-standard-4", priority: 50, state: :STARTED},
      %{machine_type: "a1-standard-4", priority: 50, state: :ENQUEUED},
      %{machine_type: "a1-standard-4", priority: 50, state: :ENQUEUED},
      # a1-standard-8
      %{machine_type: "a1-standard-8", priority: 50, state: :STARTED}
    ]
  end

  defp debugs do
    [
      %{
        debug_user_id: "user_4",
        type: :JOB,
        debug_session: %{
          id: "debug_1",
          machine_type: "e1-standard-8",
          state: :STARTED,
          timeline: %{created_at: "2 days ago"},
          project_id: "pr_1"
        },
        debugged_job: %{
          name: "Failing Job 1",
          id: "debugged_1",
          machine_type: "e1-standard-2",
          state: :FINISHED,
          ppl_id: "d_ppl_1",
          branch_id: "d_branch_1",
          pipeline: %{
            commit_message: "Refactor app",
            wf_id: "d_wf_1",
            name: "Unit tests",
            ppl_id: "d_ppl_1",
            branch_name: "master",
            branch_id: "d_branch_1"
          }
        }
      },
      %{
        debug_user_id: "user_5",
        type: :JOB,
        debug_session: %{
          id: "debug_2",
          machine_type: "e1-standard-8",
          state: :STARTED,
          timeline: %{created_at: "2 days ago"},
          project_id: "pr_2"
        },
        debugged_job: %{
          name: "Check yaml syntax",
          id: "debugged_2",
          machine_type: "e1-standard-2",
          state: :FINISHED,
          ppl_id: "d_ppl_2",
          branch_id: "d_tag_1",
          pipeline: %{
            commit_message: "New image for svc 1",
            wf_id: "d_wf_2",
            name: "Deploy to K8s",
            ppl_id: "d_ppl_2",
            branch_name: "v1.2.3",
            branch_id: "d_tag_1"
          }
        }
      },
      %{
        debug_user_id: "user_6",
        type: :JOB,
        debug_session: %{
          id: "debug_3",
          machine_type: "a1-standard-4",
          state: :ENQUEUED,
          timeline: %{created_at: "2 days ago"},
          project_id: "pr_3"
        },
        debugged_job: %{
          name: "Upload to AppStore",
          id: "debugged_3",
          machine_type: "a1-standard-4",
          state: :FINISHED,
          ppl_id: "d_ppl_3",
          branch_id: "d_pr_123",
          pipeline: %{
            commit_message: "Use new Xcode",
            wf_id: "d_wf_3",
            name: "Deploy",
            ppl_id: "d_ppl_3",
            branch_name: "123",
            branch_id: "d_pr_123"
          }
        }
      }
    ]
  end

  defp assert_valid_items_in_response(items) do
    assert %Front.ActivityMonitor.Items{
             lobby: %Front.ActivityMonitor.Lobby{
               items: [
                 %Front.ActivityMonitor.ItemPipeline{
                   created_at: "2 days ago",
                   item_id: _,
                   item_type: "Pipeline",
                   job_stats: %Front.ActivityMonitor.JobStats{
                     left: 4,
                     running: %Front.ActivityMonitor.JobStatsRunning{
                       job_count: 0,
                       machine_types: %{}
                     },
                     waiting: %Front.ActivityMonitor.JobStatsWaiting{
                       job_count: 0,
                       machine_types: %{}
                     }
                   },
                   name: "Unit tests",
                   pipeline_path: "/workflows/wf_5?pipeline_id=ppl_5",
                   priority: 50,
                   project_name: "zebra",
                   project_path: "/projects/zebra",
                   ref_name: "master",
                   ref_path: "/branches/123",
                   ref_type: "Branch",
                   title: "Change text color",
                   user_icon_path: "github_avatar.jpg",
                   user_name: "Non_Semaphore_user",
                   workflow_path: "/workflows/wf_5"
                 }
               ],
               non_visible_pipelines_count: 1
             },
             running: %Front.ActivityMonitor.Running{
               items: [
                 %Front.ActivityMonitor.ItemDebugSession{
                   created_at: "2 days ago",
                   debug_job_name: "Failing Job 1",
                   debug_job_path: "/jobs/debugged_1",
                   debug_type: "Job",
                   item_id: _,
                   item_type: "Debug Session",
                   job_stats: %Front.ActivityMonitor.JobStats{
                     left: 0,
                     running: %Front.ActivityMonitor.JobStatsRunning{
                       job_count: 1,
                       machine_types: %{"e1-standard-8" => 1}
                     },
                     waiting: %Front.ActivityMonitor.JobStatsWaiting{
                       job_count: 0,
                       machine_types: %{}
                     }
                   },
                   pipeline_name: "Unit tests",
                   pipeline_path: "/workflows/d_wf_1?pipeline_id=d_ppl_1",
                   project_name: "front",
                   project_path: "/projects/front",
                   ref_name: "master",
                   ref_path: "/branches/d_branch_1",
                   user_icon_path: "avatar4.jpg",
                   user_name: "Darko",
                   workflow_name: "Refactor app",
                   workflow_path: "/workflows/d_wf_1"
                 },
                 %Front.ActivityMonitor.ItemPipeline{
                   created_at: "2 days ago",
                   item_id: _,
                   item_type: "Pipeline",
                   job_stats: %Front.ActivityMonitor.JobStats{
                     left: 2,
                     running: %Front.ActivityMonitor.JobStatsRunning{
                       job_count: 3,
                       machine_types: %{
                         "e1-standard-2" => 2,
                         "e1-standard-4" => 1
                       }
                     },
                     waiting: %Front.ActivityMonitor.JobStatsWaiting{
                       job_count: 0,
                       machine_types: %{}
                     }
                   },
                   name: "Unit tests",
                   pipeline_path: "/workflows/wf_1?pipeline_id=ppl_1",
                   priority: 50,
                   project_name: "front",
                   project_path: "/projects/front",
                   ref_name: "master",
                   ref_path: "/branches/123",
                   ref_type: "Branch",
                   title: "Merge Pull Request #48: Increase Profitability",
                   user_icon_path: "avatar1.jpg",
                   user_name: "Petar",
                   workflow_path: "/workflows/wf_1"
                 }
               ],
               non_visible_job_count: 3
             },
             waiting: %Front.ActivityMonitor.Waiting{
               items: [
                 %Front.ActivityMonitor.ItemDebugSession{
                   created_at: "2 days ago",
                   debug_job_name: "Upload to AppStore",
                   debug_job_path: "/jobs/debugged_3",
                   debug_type: "Job",
                   item_id: _,
                   item_type: "Debug Session",
                   job_stats: %Front.ActivityMonitor.JobStats{
                     left: 0,
                     running: %Front.ActivityMonitor.JobStatsRunning{
                       job_count: 0,
                       machine_types: %{}
                     },
                     waiting: %Front.ActivityMonitor.JobStatsWaiting{
                       job_count: 1,
                       machine_types: %{"a1-standard-4" => 1}
                     }
                   },
                   pipeline_name: "Deploy",
                   pipeline_path: "/workflows/d_wf_3?pipeline_id=d_ppl_3",
                   project_name: "zebra",
                   project_path: "/projects/zebra",
                   ref_name: "123",
                   ref_path: "/branches/d_pr_123",
                   user_icon_path: "avatar6.jpg",
                   user_name: "Lukas",
                   workflow_name: "Use new Xcode",
                   workflow_path: "/workflows/d_wf_3"
                 },
                 %Front.ActivityMonitor.ItemPipeline{
                   created_at: "2 days ago",
                   item_id: _,
                   item_type: "Pipeline",
                   job_stats: %Front.ActivityMonitor.JobStats{
                     left: 2,
                     running: %Front.ActivityMonitor.JobStatsRunning{
                       job_count: 0,
                       machine_types: %{}
                     },
                     waiting: %Front.ActivityMonitor.JobStatsWaiting{
                       job_count: 3,
                       machine_types: %{
                         "a1-standard-4" => 1,
                         "e1-standard-2" => 1,
                         "e1-standard-4" => 1
                       }
                     }
                   },
                   name: "Unit tests",
                   pipeline_path: "/workflows/wf_3?pipeline_id=ppl_3",
                   priority: 50,
                   project_name: "zebra",
                   project_path: "/projects/zebra",
                   ref_name: "pull-request-123",
                   ref_path: "/branches/123",
                   ref_type: "Pull request",
                   title: "Change text color",
                   user_icon_path: "avatar3.jpg",
                   user_name: "Marko",
                   workflow_path: "/workflows/wf_3"
                 }
               ],
               non_visible_job_count: 2
             }
           } = items
  end
end
