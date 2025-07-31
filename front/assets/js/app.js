import "phoenix_html";

import $ from "jquery";
import { install } from '@github/hotkey';
import { Userpilot } from "userpilot"

import { defineTimeAgoElement } from "./time_ago";
import { Tippy } from "./tippy";
import { JumpTo } from "./jump_to/jump_to";
import { Pollman } from "./pollman";
import { Notice } from "./notice";
import { Repository } from "./repository";
import { GithubCollaborators } from "./people/github_collaborators";
import { CreateMember } from "./people/create_member";
import { Offboarding } from "./people/offboarding.js";
import { ManageSecret } from "./manage_secret";
import { Dashboard } from "./dashboard";
import { EditNotification } from "./edit_notification";
import { Timer } from "./workflow_view/timer";
import { Switch } from "./workflow_view/switch";
import { InteractivePipelineTree } from "./workflow_view/interactive_pipeline_tree";
import { TriggerEvent } from "./workflow_view/trigger_event";
import { Diagram } from "./workflow_view/diagram";
import { ForkExplanation } from "./workflow_view/fork_explanation";
import { FaviconUpdater } from "./workflow_view/favicon_updater";
import { WorkflowEditor } from "./workflow_editor/editor.js";
import { JobLogs } from "./job_logs/logs.js";
import { GeneralSettings } from "./project_settings/general.js";
import { ListPeople } from "./people/list_people.js";
import { ChangeRoleDropdown } from "./people/change_role_dropdown";
import { RetractRole } from "./people/retract_role";
import { AddToProject } from "./people/add_to_project.js";
import { GroupManagement } from "./groups/group_management.js";
import { OrganizationOktaGroupMappingApp } from "./organization_okta";
import { OrganizationSecrets } from "./organization_secrets";
import { ProjectSecrets } from "./project_settings/secrets";
import { ProjectArtifactsSettings } from "./project_settings/artifacts.js";
import { BadgeSettings } from "./project_settings/badge.js";
import { DebugSessionsSettings } from "./project_settings/debug_sessions.js";
import { TemplatePicker } from "./template_picker";
import { escapeHtml } from "./escape_html";
import { Blocked } from "./blocked";
import { WorkflowTips } from "./workflow_tips";
import { InviteProjectPeople } from "./project_onboarding/invite_people.js";
import { Me } from "./me/me";
import { Project } from "./project/project";
import { WorkflowList } from "./workflow_list.js";
import { Star } from "./star.js";
import { ActivityMonitor } from "./activity_monitor/main.js";
import { CronParser } from "./cron_parser";
import { SelfHostedAgents } from "./self_hosted_agents/main.js";
import { PreFlightChecks } from "./pre_flight_checks";
import { AuditLogs } from "./audit.js";
import { Tasks } from "./tasks";
import { DeployKeyConfig } from "./project_settings/deploy_key_config"
import { WebhookConfig } from "./project_settings/webhook_config"
import { default as GitIntegration } from "./git_integration";
import { default as TestResults } from "./test_results";
import { default as Insights } from "./insights";
import { default as Billing, TrialOverlay } from "./billing"
import { default as OrganizationHealth } from "./organization_health/index";
import { default as FlakyTests } from "./flaky_tests/index";
import { default as OrganizationOnboarding } from "./organization_onboarding"
import { default as GetStarted } from "./get_started"
import { default as Agents} from "./agents";
import { default as AddPeople } from "./people/add_people";
import { default as EditPerson } from "./people/edit_person";
import { default as SyncPeople } from "./people/sync_people";
import { default as Report } from "./report";

import { InitializingScreen } from "./project_onboarding/initializing";
import { AccountInitializingScreen } from "./me/initialization/initializing";
import { Fork } from "./project_onboarding/fork";
import { ProjectOnboardingCreate, ProjectOnboardingWorkflowSetup } from "./project_onboarding/new";

import { DeploymentTargets } from "./deployments";

import { Features } from "./features";
import { Overlay } from "./overlay";
import { RoleForm } from "./roles/role_form.js";

var ace = require('brace');
require('brace/mode/yaml');

window.Pollman = Pollman; // make Pollman globally available
window.Notice = Notice;
window.escapeHtml = escapeHtml;
window.ActivityMonitor = ActivityMonitor;
window.SelfHostedAgents = SelfHostedAgents


export var App = {
  agents: function () {
    Agents({
      dom: document.getElementById("agents-app"),
      config: InjectedDataByBackend.AgentsConfig,
    })
  },
  activity_monitor: function () {
    window.ActivityMonitor.start(
      InjectedDataByBackend.ActivityMonitor.Data,
      InjectedDataByBackend.ActivityMonitor.RefreshDataURL
    )
  },
  self_hosted_agents_new: function () {
    SelfHostedAgents.handleNameFieldChange()
    SelfHostedAgents.handleNameAssignmentSwitch()
    SelfHostedAgents.handleNameReleaseSwitch()
  },
  self_hosted_agents_show: function () {
    SelfHostedAgents.waitForAgents({
      agentTypeName: InjectedDataByBackend.SelfHostedAgents.AgentTypeName,
      canManage: InjectedDataByBackend.SelfHostedAgents.CanManage,
      firstPageUrl: InjectedDataByBackend.SelfHostedAgents.FirstPageUrl,
      nextPageUrl: InjectedDataByBackend.SelfHostedAgents.NextPageUrl,
      latestAgentVersion: InjectedDataByBackend.SelfHostedAgents.LatestAgentVersion
    })
  },
  self_hosted_agents_create: function () {
    SelfHostedAgents.waitForAgents({
      agentTypeName: InjectedDataByBackend.SelfHostedAgents.AgentTypeName,
      canManage: InjectedDataByBackend.SelfHostedAgents.CanManage,
      firstPageUrl: InjectedDataByBackend.SelfHostedAgents.FirstPageUrl,
      nextPageUrl: InjectedDataByBackend.SelfHostedAgents.NextPageUrl,
      latestAgentVersion: InjectedDataByBackend.SelfHostedAgents.LatestAgentVersion
    })
    SelfHostedAgents.handleInstructionsChange()
    SelfHostedAgents.handleTokenReveal()
  },
  self_hosted_agents_token_reset: function () {
    SelfHostedAgents.waitForAgents({
      agentTypeName: InjectedDataByBackend.SelfHostedAgents.AgentTypeName,
      canManage: InjectedDataByBackend.SelfHostedAgents.CanManage,
      firstPageUrl: InjectedDataByBackend.SelfHostedAgents.FirstPageUrl,
      nextPageUrl: InjectedDataByBackend.SelfHostedAgents.NextPageUrl,
      latestAgentVersion: InjectedDataByBackend.SelfHostedAgents.LatestAgentVersion
    })
    SelfHostedAgents.handleTokenReveal()
  },
  organization_pfcs: function () {
    window.preFlightChecks = PreFlightChecks.init('organization_pfc')
  },
  project_pfcs: function () {
    window.preFlightChecks = PreFlightChecks.init('project_pfc')
    new Star();
  },
  role_form: function () {
    window.roleForm = RoleForm.init()
  },
  audit_logs: function () {
    window.auditLogs = AuditLogs.init()
  },
  offboarding: function () {
    Offboarding.init();
  },
  people_member_new: function () {
    GithubCollaborators.init();
    CreateMember.handlePasswordReveal();
  },
  people_show: function () {
    CreateMember.handlePasswordReveal();
  },
  people_sync: function () {
    GithubCollaborators.init();
  },
  logs: function () {
    Pollman.init();
    window.JobLogs = JobLogs.init();
  },
  workflow_editor: function () {
    detectBrowser();
    WorkflowTips.init();
    window.WorkflowEditor = WorkflowEditor.init();
  },
  workflow_view: function () {
    window.Diagram = Diagram;
    window.Switch = Switch;
    window.InteractivePipelineTree = InteractivePipelineTree;
    window.FaviconUpdater = FaviconUpdater.init({
      onStatusChange: () => {
        Pollman.poll({ forceRefresh: true });
      }
    });

    if (window.InjectedDataByBackend.pipelineStatusUrl) {
      window.FaviconUpdater.setPipelineStatusUrl(window.InjectedDataByBackend.pipelineStatusUrl);
    }

    Pollman.init({ interval: 4000, forceRefreshCycle: 10, saveScrollElements: ["#workflow-tree-container", "#diagram"] });
    Timer.init();
    Switch.init();
    InteractivePipelineTree.init();
    TriggerEvent.init();
    WorkflowTips.init();
    ForkExplanation.init();
  },
  new_project: function () {
    Fork.init(window.InjectedDataByBackend.Fork.DefaultProvider);
  },
  index_new_project: function () {
    ProjectOnboardingCreate({
      dom: document.getElementById("new-project-app"),
      config: window.InjectedDataByBackend.NewProjectConfig,
    });
  },
  index_project_bootstrap: function () {
    ProjectOnboardingWorkflowSetup({
      dom: document.getElementById("new-project-app"),
      config: window.InjectedDataByBackend.NewProjectBootstrapConfig,
    });
  },
  repository: function () {
    Repository.init();
  },
  blocked: function () {
    Blocked.init();
  },
  notification: function () {
    EditNotification.init();
  },
  secret: function () {
    ManageSecret.init();
  },
  me_page: function () {
    window.WorkflowList = WorkflowList;
    window.WorkflowList.init();

    Me.init();
    Timer.init();
    Pollman.init();
  },
  branch_page: function () {
    window.WorkflowList = WorkflowList;
    window.WorkflowList.init();

    Pollman.init();
    Timer.init();
  },
  project_page: function () {
    window.WorkflowList = WorkflowList;
    window.WorkflowList.init();

    Pollman.init();
    Project.init();
    Timer.init();
  },
  project_artifacts: function () {
    new Star();
  },
  tasks: function () {
    const config = InjectedDataByBackend.Tasks;
    if (config && config.Page && config.CanLoad === true) {
      window.SchedulerTasks = Tasks.init(config.Page)

      if (Tasks.shouldPoll(config.Page)) {
        Pollman.init({ interval: 5000 });
        Timer.init();
      }
    }

    CronParser.init();
    new Star();
  },
  task_history: function () {
    window.task_history = TaskHistory.init();
    new Star();
  },
  project_header: function () {
    new Star();
  },
  general_project_settings: function () {
    GeneralSettings.init();

    document.querySelectorAll("#deploy-key-config-app").forEach((dom) => {
      DeployKeyConfig({
        dom: dom,
        config: dom.dataset
      })
    });

    document.querySelectorAll("#webhook-config-app").forEach((dom) => {
      WebhookConfig({
        dom: dom,
        config: dom.dataset
      })
    });
    new Star();
  },
  people_page: function () {
    ListPeople.init();
    ChangeRoleDropdown.init();
    RetractRole.init();
    AddToProject.init();
    GroupManagement.init();
    new Star();

    const addPeopleAppRoot = document.getElementById("add-people");
    if (addPeopleAppRoot) {
      AddPeople({
        dom: addPeopleAppRoot,
        config: addPeopleAppRoot.dataset,
      });
    }

    document.querySelectorAll(".app-edit-person").forEach((editPersonAppRoot) => {
      EditPerson({
        dom: editPersonAppRoot,
        config: editPersonAppRoot.dataset
      })
    });

    document.querySelectorAll(".app-sync-people").forEach((syncPeopleAppRoot) => {
      SyncPeople({
        dom: syncPeopleAppRoot,
        config: syncPeopleAppRoot.dataset
      })
    });
  },
  organization_okta: function () {
    OrganizationOktaGroupMappingApp({
      dom: document.getElementById("group-mapping-container"),
      config: window.InjectedDataByBackend.OrganizationOktaConfig
    });
  },
  organization_secrets: function () {
    OrganizationSecrets.init(InjectedDataByBackend); // njsscan-ignore: node_secret
  },
  project_secrets: function () {
    ProjectSecrets.init(InjectedDataByBackend); // njsscan-ignore: node_secret
    new Star();
  },
  badge_settings: function () {
    BadgeSettings.init();
    new Star();
  },
  debug_sessions_settings: function () {
    DebugSessionsSettings.init();
    new Star();
  },
  project_artifacts_settings: function () {
    ProjectArtifactsSettings.init();
    new Star();
  },
  dashboard: function () {
    window.WorkflowList = WorkflowList;
    window.WorkflowList.init();

    Pollman.init({ interval: 10000 });
    Dashboard.init();
    Timer.init();
    new Star();
  },
  support: function () { },
  testResults: function () {
    Pollman.init({ interval: 4000 })
    TestResults({
      dom: document.getElementById("test-results"),
      jsonURL: InjectedDataByBackend.jsonArtifactsURL,
      scope: InjectedDataByBackend.scope,
      encodedEmail: InjectedDataByBackend.encodedEmail,
      pplTreeLoader: InteractivePipelineTree,
      pollURL: InjectedDataByBackend.pollURL,
      pipelineId: InjectedDataByBackend.pipelineId,
      pipelineStatus: InjectedDataByBackend.pipelineStatus,
      pipelineName: InjectedDataByBackend.pipelineName,
      workflowSummaryURL: InjectedDataByBackend.workflowSummaryUrl,
    });
  },
  projectSetupTextEditor: function () {
    if (document.getElementById("editor")) {
      var editor = ace.edit("editor");
      editor.setTheme("ace/theme/textmate");
      editor.session.setMode("ace/mode/yaml");
      editor.setAutoScrollEditorIntoView(true);
      editor.setOption("maxLines", 50);
      editor.setOption("minLines", 30);
      editor.renderer.setScrollMargin(10, 10, 10, 10);
      editor.renderer.setOption("showPrintMargin", false);

      var textarea = document.querySelector('#commit-config textarea');

      textarea.value = editor.getSession().getValue();

      editor.session.on('change', function (delta) {
        textarea.value = editor.getSession().getValue();
      });

      document.querySelectorAll('.x-editor-language').forEach(function (item) {
        item.onclick = function (event) {
          document.querySelectorAll('.x-editor-language').forEach(function (item) {
            item.classList.remove("bg-dark-gray");
            item.classList.remove("white");
            item.classList.add("hover-bg-lightest-blue");
            item.classList.add("bg-washed-gray");
          })

          event.target.classList.add("bg-dark-gray");
          event.target.classList.add("white");
          event.target.classList.remove("hover-bg-lightest-blue");
          event.target.classList.remove("bg-washed-gray");

          editor.getSession().setValue(event.target.dataset.template);
        }
      });
    }
  },
  templatePicker: function () {
    TemplatePicker.init();
  },
  inviteProjectPeople: function () {
    InviteProjectPeople.init();
  },
  projectOnboardingInitializing: function () {
    InitializingScreen.run();
  },
  accountPermissionsInitializing: function () {
    AccountInitializingScreen.run();
  },
  organization_health_tab: function () {
    OrganizationHealth({
      dom: document.getElementById("organization-health-app"),
      config: InjectedDataByBackend.OrganizationHealthConfig,
    });
  },
  flaky_tests_tab: function () {
    FlakyTests({
      dom: document.getElementById("flaky-tests-app"),
      config: InjectedDataByBackend.FlakyTestsConfig,
    });
  },
  insights: function () {
    Insights({
      dom: document.getElementById("insights-app"),
      config: InjectedDataByBackend.InsightsConfig,
    })
    new Star();
  },
  deployments_index: function () {
    window.deployments = DeploymentTargets.index()
    new Star();
  },
  deployments_show: function () {
    window.deployments = DeploymentTargets.show()
    new Star();
  },
  deployments_new: function () {
    if (InjectedDataByBackend.Deployments.Accessible) {
      window.deployments = DeploymentTargets.new()
    }
    new Star();
  },
  deployments_edit: function () {
    if (InjectedDataByBackend.Deployments.Accessible) {
      window.deployments = DeploymentTargets.edit()
    }
    new Star();
  },
  billingDashboard: function () {
    Billing({
      dom: document.getElementById("billing-app"),
      config: InjectedDataByBackend.BillingConfig,
    })
  },
  gitIntegration: function () {
    GitIntegration({
      dom: document.getElementById("git-integration-app"),
      config: InjectedDataByBackend.GitIntegrationConfig,
    })
  },
  organizationOnboarding: function () {
    OrganizationOnboarding({
      dom: document.getElementById("organization-onboarding-app"),
      config: InjectedDataByBackend.OrganizationOnboardingConfig,
    })
  },
  getStarted: function () {
    GetStarted({
      dom: document.getElementById("get-started-app"),
      config: InjectedDataByBackend.GetStartedConfig,
    })
  },
  report: function() {
    Report({
      dom: document.getElementById("report-app"),
      config: InjectedDataByBackend.ReportConfig,
    })
  },
  // App.run() is invoked at the bottom of the body element
  run: function () {
    Features.init(InjectedDataByBackend.Features || {});

    Overlay.init();
    if (InjectedDataByBackend.InitialPlan) {
      TrialOverlay({
        dom: document.getElementById("trial-overlay"),
        config: InjectedDataByBackend.InitialPlan,
      })
    }

    defineTimeAgoElement()
    managePageHeaderShaddows()
    enableMagicBreadcrumbs()
    maybeEnableUserpilot()


    if (InjectedDataByBackend.JumpTo !== undefined) {
      window.jumpTo = JumpTo.init();
    }

    window.Tippy = Tippy;
    Tippy.defaultTip('[data-tippy-content]');
    Tippy.otherDefaultTip('.default-tip');
    Tippy.defaultDropdown('.js-dropdown-menu-trigger');
    Tippy.defaultDropdown('.js-job-dropdown-menu-trigger');
    Tippy.colorDropdown('.js-dropdown-color-trigger');

    window.Notice.init();

    $(document).on("click", ".x-select-on-click", function (event) {
      event.currentTarget.setSelectionRange(0, event.currentTarget.value.length);
    });

    for (const el of document.querySelectorAll('[data-hotkey]')) {
      install(el);
    }
  }
};

function detectBrowser() {
  //
  // Detect browser and set up CSS body class
  // This class is used in design (or code) to implement browser specific
  // workarounds.
  //
  // Executing this as the first thing, makes sure that no other code is loaded
  // that depends on this value.
  //
  // The checks need to be specified in this order

  if ((navigator.userAgent.indexOf("Opera") || navigator.userAgent.indexOf('OPR')) != -1) {
    document.body.classList.add("browser-opera");
  } else if (navigator.userAgent.indexOf("Chrome") != -1) {
    document.body.classList.add("browser-chrome");
  } else if (navigator.userAgent.indexOf("Safari") != -1) {
    document.body.classList.add("browser-safari");
  } else if (navigator.userAgent.indexOf("Firefox") != -1) {
    document.body.classList.add("browser-firefox");
  } else if ((navigator.userAgent.indexOf("MSIE") != -1) || (!!document.documentMode == true)) {
    document.body.classList.add("browser-ie");
  }
}

function managePageHeaderShaddows() {
  $(window).scroll(function () {
    if ($(this).scrollTop() > 0) {
      $('#global-page-header').addClass('js-header-shadow');
    } else {
      $('#global-page-header').removeClass('js-header-shadow');
    }
  })
}

function enableMagicBreadcrumbs() {
  $(window).scroll(function () {
    var fromtop = $(document).scrollTop();
    if ($(this).scrollTop() > 150) {
      $('#magicBreadcrumb').css({ 'opacity': '1', 'margin-top': '48px', 'z-index': '999' });
    } else {
      $('#magicBreadcrumb').css({ 'opacity': '0', 'margin-top': '16px', 'z-index': '5' });
    }
  })
}

function maybeEnableUserpilot() {
  if (window.InjectedDataByBackend.Userpilot.token) {
    let { userCreatedAt, userId, organizationId, organizationCreatedAt, token } = window.InjectedDataByBackend.Userpilot
    let companyData = {}
    if (organizationId) {
      companyData = {
        created_at: userCreatedAt,
        company: {
          id: organizationId,
          created_at: organizationCreatedAt
        }
      }
    }
    Userpilot.initialize(token);
    Userpilot.identify(userId, companyData);
  }
}

App.run()
if (InjectedDataByBackend.JS != "" && InjectedDataByBackend.JS !== undefined) {
  App[InjectedDataByBackend.JS]();
}
