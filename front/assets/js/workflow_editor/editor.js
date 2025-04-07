import $ from "jquery";
import _ from "lodash";

import { Layout } from "./layout"

import { Workflow } from "./models/workflow"
import { Secrets  } from "./models/secrets"
import { Agent    } from "./models/agent"
import { Promotion } from "./models/promotion";

import { Tabs         } from "./components/tabs"
import { MonacoCodeEditor } from "./components/monaco_code_editor"
import { CodeEditor    } from "./components/code_editor"
import { Diagram       } from "./components/diagram"
import { CommitPanel   } from "./components/commit_panel"
import { Configurator  } from "./components/configurator"

import { SelectionRegister } from "./selection_register"

import { Features } from "../features";

function assertKey(object, key, errMessage) {
  if(!_.has(object, key) || object[key] === undefined) { throw errMessage }
}

export class WorkflowEditor {
  static init() {
    let config = {
      projectName: InjectedDataByBackend.ProjectName,
      canDismissAndExit: InjectedDataByBackend.CanDismissAndExit,
      orgSecretNames: InjectedDataByBackend.OrgSecretNameList,
      projectSecretNames: InjectedDataByBackend.ProjectSecretNameList || [],
      workflowData: InjectedDataByBackend.WorkflowData,
      agentTypes: InjectedDataByBackend.AgentTypes,
      deploymentTargets: InjectedDataByBackend.DeploymentTargetsList,
      checkFetchingJobPath: InjectedDataByBackend.CheckFetchingJobPath,
      fetchingJobId: InjectedDataByBackend.FetchingJobId,
      commitInfo: {
        paths: {
          dismiss: InjectedDataByBackend.CommitForm.DismissPath,
          commit: InjectedDataByBackend.CommitForm.CommitPath,
          checkWorkflow: InjectedDataByBackend.CommitForm.CheckWorkflowPath,
          checkCommitJob: InjectedDataByBackend.CommitForm.CheckCommitJobPath
        },
        pushBranch: InjectedDataByBackend.CommitForm.PushBranch,
        initialBranch: InjectedDataByBackend.CommitForm.InitialBranch,
        commiterAvatar: InjectedDataByBackend.CommitForm.Avatar
      },
    }

    //
    // Validate early that the Editor has all the necessary information to
    // start working.
    //

    assertKey(config.commitInfo, "pushBranch", "Push Branch is not configured")
    assertKey(config.commitInfo, "initialBranch", "InitialBranch Branch is not configured")
    assertKey(config.commitInfo, "commiterAvatar", "Commiter Avatar is not configured")
    assertKey(config.commitInfo.paths, "dismiss", "Dismiss path is not configured")
    assertKey(config.commitInfo.paths, "commit",  "Commit path is not configured")
    assertKey(config.commitInfo.paths, "checkWorkflow", "Check Workflow path is not configured")
    assertKey(config.commitInfo.paths, "checkCommitJob", "Check Job path is not configured")

    //
    // If everything is cocher, start the editor.
    //

    return new WorkflowEditor(config)
  }

  constructor(config) {
    this.config = config;

    Promotion.setProjectName(this.config.projectName);
    Promotion.setValidDeploymentTargets(this.config.deploymentTargets);
    Secrets.setValidSecretNames(this.config.orgSecretNames, this.config.projectSecretNames);
    Agent.setValidAgentTypes(this.config.agentTypes);

    if(Features.isEnabled("useFetchingJob")) {
      this.registerLeavePageHandler(); 
      
      this.disableButtonsInHeader();

      this.toggleWorkflowEditor();

      this.toggleZeroState();

      this.waitForFetchingJob();
    } else {
      this.setUpModelComponentEventLoop();

      this.registerLeavePageHandler();
  
      this.preselectFirstBlock();
    }
  }

  disableButtonsInHeader() {
    $("[data-action=editorDismiss]").prop("disabled", true);
    $("[data-action=toggleCommitDialog]").prop("disabled", true);
  }

  enableButtonsInHeader() {
    $("[data-action=editorDismiss]").prop("disabled", false);
    $("[data-action=toggleCommitDialog]").prop("disabled", false);
  }

  toggleWorkflowEditor() {
    $("#workflow-editor-tabs").toggle();
    $("#workflow-editor-container").toggle();
  }

  toggleZeroState() {
    $("#zero-state-loading-message").toggle();
  }

  waitForFetchingJob() {
    let url = this.config.checkFetchingJobPath + `?job_id=${this.config.fetchingJobId}`;

    console.log(`Checking fetching job ${url}`);

    fetch(url)
    .then((res) => {
      const contentType = res.headers.get("content-type");

      if(contentType && contentType.includes("application/json")) {
        return res.json();
      } else {
        throw new Error(res.statusText);
      }
    })
    .then((res) => {
      if(res.error) {
        throw new Error(res.error);
      } else {
        return res;
      }
    })
    .then((data) => {
      if(!data.finished) {
        setTimeout(this.waitForFetchingJob.bind(this), 1000);
      } else {
        this.fetchFilesAndShowEditor(data.signed_urls);
      }
    })
    .catch(
      (reason) => { 
        console.log(reason); 
        this.enableExitAndShowErrorMessage();
      }
    )
  }

  enableExitAndShowErrorMessage() {
    this.disableOnLeaveConfirm();
    $("[data-action=editorDismiss]").prop("disabled", false);

    $("#zero-state-title").text('Searching git repository for .yml files has failed.');

    const message1 = "There was an issue with searching your git repository for .yml files.";
    $("#zero-state-paragraph-one").text(message1);
    $("#zero-state-paragraph-one").addClass("red");

    const message2 = 'Please try reloading the page and contact support if the issue persists.';
    $("#zero-state-paragraph-two").text(message2);
    $("#zero-state-paragraph-two").addClass("red");
  }

  fetchFilesAndShowEditor(urls) {
   fetchFilesWithConcurrencyLimit(urls)
    .then(({ fetchedFiles, errors }) => {
      if (errors.length > 0) {
        console.warn("Some files failed to fetch:", errors);

        this.enableExitAndShowErrorMessage();
      } else {
        console.log("All .yml files were fetched successfully.");

        this.config.workflowData.yamls = fetchedFiles;

        this.toggleZeroState();

        this.toggleWorkflowEditor();

        this.enableButtonsInHeader();
        
        this.setUpModelComponentEventLoop();
    
        this.preselectFirstBlock();
      }
    });
  }
  

  //
  // Sets up a model-component event loop.
  //
  // The model is the workflow and handles YAML related information,
  // YAML errors, adding and removing jobs/blocks/etc.. It knows nothing
  // about the the components and the UI.
  //
  // The components are handling the view logic of the editor. They store
  // internal data that represents the state of the UI component, for example,
  // which sub-tree is expanded in the diagram. They are responsible for
  // rendering the UI in the DOM.
  //
  // The components are reacting to the changes in the model.
  // Every time a model changes, the components are updated.
  //
  setUpModelComponentEventLoop() {
    this.workflow = new Workflow(this.config.workflowData)

    let divs = {
      tabs: "#workflow-editor-tabs",
      code: "#workflow-editor-code-editor",
      diagram: "#workflow-editor-diagram",
      config: "#workflow-editor-config-panel"
    }

    this.layout = Layout.handle(divs.diagram, divs.config)

    const codeEditor = Features.isEnabled("uiMonacoWorkflowCodeEditor") ?
      new MonacoCodeEditor(divs.code) :
      new CodeEditor(divs.code)

    this.components = {
      tabs: new Tabs(this, divs.tabs, this.config.canDismissAndExit),
      codeEditor: codeEditor,
      diagram: new Diagram(this, this.workflow, divs.diagram),
      configurator: new Configurator(this, this.workflow, divs.config),
      commitPanel: new CommitPanel(this, this.workflow, this.config.commitInfo)
    }

    //
    // On every change in the models, we update the editor.
    //
    this.workflow.onUpdate(this.update.bind(this))
    SelectionRegister.onUpdate(this.update.bind(this))

    // We do an initial update cycle to render the initial state.
    this.update()
  }

  update() {
    // First, we make sure that the model is valid and calculate the errors.
    this.workflow.validate()

    // Update visibility based on current tab selection
    if(this.components.tabs.isVisualActive()) {
      this.components.codeEditor.hide()
      this.components.configurator.show()
      this.components.diagram.show()
    } else {
      this.components.codeEditor.show(this.components.tabs.pipeline)
      this.components.configurator.hide()
      this.components.diagram.hide()
    }

    // Update layout
    this.layout.update()

    // Then, we update every component in the system.
    _.forIn(this.components, (component) => component.update())
  }

  disableOnLeaveConfirm() {
    window.onbeforeunload = null;
  }

  on(event, selector, callback) {
    this.debugLog(`Registering event: '${event}', target: '${selector}'.`)

    let handler = (e) => {
      this.debugLog(`Event for '${event}' on ${selector} started`)
      let result = callback(e)
      this.debugLog(`Event for '${event}' on ${selector} finished`)

      return result
    }

    $("body").on(event, selector, (e) => {
      return handler(e)
    })
  }

  debugLog(message) {
    if(this.debugMode) {
      console.log(message)
    }
  }

  debugLightshow() {
    $("body").append(`
       <style>
          @keyframes lightUp {
            0% {
              background: orange;
            }
            100% {
              background: inherit;
            }
          }

          * {
            animation: lightUp 0.1s linear;
          }
       </style>
    `)
  }

  //
  // Used in tests to find and update the code editor.
  //
  getCodeEditor() {
    return this.components.codeEditor
  }

  registerLeavePageHandler() {
    window.onbeforeunload = function(){
      return 'Are you sure you want to leave?'
    }
  }

  preselectFirstBlock() {
    let uid = this.workflow.findInitialPipeline().blocks[0].uid
    SelectionRegister.setCurrentSelectionUid(uid)
  }
}

async function fetchFilesWithConcurrencyLimit(fileList, maxConcurrency = 3) {
  const errors = [];
  let currentIndex = 0;

  const fetchNext = async () => {
    if (currentIndex >= fileList.length) return;

    const fileObj = fileList[currentIndex];
    const filePath = Object.keys(fileObj)[0];
    const signedUrl = fileObj[filePath];
    currentIndex++;

    try {
      const response = await fetch(signedUrl);
      if (!response.ok) {
        throw new Error(`Failed to fetch ${filePath}: ${response.statusText}`);
      }
      const content = await response.text();
      fileObj[filePath] = content;
    } catch (err) {
      errors.push({ filePath, error: err });
    }

    await fetchNext();
  };

  const tasks = [];
  for (let i = 0; i < maxConcurrency; i++) {
    tasks.push(fetchNext());
  }

  await Promise.all(tasks);

  return {
    updatedFiles: fileList,
    errors,
  };
}