import { Fragment } from "preact";
import * as components from "../../components";
import * as toolbox from "js/toolbox";
import * as stores from "../../stores";
import { useContext, useCallback, useEffect } from "preact/hooks";
import { useNavigate } from "react-router-dom";
import Tippy from "@tippyjs/react";
import { useSteps } from "../../stores/create/steps";
import { handleSkipOnboarding } from "../../utils/skip_onboarding";
import { Notice } from "js/notice";

interface AgentCardProps {
  agent: stores.WorkflowSetup.Config.AgentType | stores.WorkflowSetup.Config.SelfHostedAgentType;
  isCloud?: boolean;
  isSelected?: boolean;
  onClick?: () => void;
}

const AgentCard = ({ agent, isCloud, isSelected, onClick }: AgentCardProps) => {
  return (
    <Fragment>
      <button
        onClick={onClick}
        className={`link pointer bn w-100 tl db dark-gray bg-white shadow-1 shadow-hover pa3 br3`}
        style={isSelected ? `box-shadow: 0 0 0 3px #00359f; border-radius: 3px;` : ``}
      >
        <div className="flex items-center">
          <toolbox.Asset
            path={isCloud ? `images/icn-cloud.svg` : `images/icn-self-hosted.svg`}
            className="db mr2"
            style="width: 26px; height:26px;"
          />
          <span className="f4 b truncate">{agent.type}</span>
        </div>
      </button>
    </Fragment>
  );
};

export const Projectenvironment = () => {
  const { state: configState } = useContext(stores.WorkflowSetup.Config.Context);
  const { state: envState, setSelectedAgentType, setYamlPath } = stores.WorkflowSetup.Environment.useEnvironmentStore();
  const navigate = useNavigate();

  const { dispatch } = useSteps();

  useEffect(() => {
    dispatch([`SET_CURRENT`, `select-environment`]);
  }, []);

  const handleAgentSelect = useCallback(
    (agent: stores.WorkflowSetup.Config.AgentType | stores.WorkflowSetup.Config.SelfHostedAgentType) => {
      const isCloudAgent = `available_os_images` in agent;

      setSelectedAgentType({
        type: agent.type,
        available_os_images: isCloudAgent ? agent.available_os_images : undefined,
      });
    },
    [setSelectedAgentType]
  );

  useEffect(() => {
    // Only select if no agent is currently selected
    if (!envState.selectedAgentType && configState.agentTypes) {
      // Try to select first cloud agent, if available
      if (configState.agentTypes.cloud.length > 0) {
        handleAgentSelect(configState.agentTypes.cloud[0]);
      }
      // Otherwise try to select first self-hosted agent
      else if (configState.agentTypes.selfHosted.length > 0) {
        handleAgentSelect(configState.agentTypes.selfHosted[0]);
      }
    }
  }, [configState.agentTypes, envState.selectedAgentType, handleAgentSelect]);

  const handleContinue = async () => {
    if (!envState.selectedAgentType || !configState.updateProjectUrl) return;

    try {
      const response = await fetch(configState.updateProjectUrl, {
        method: `PUT`,
        headers: {
          "Content-Type": `application/json`,
          "x-csrf-token": configState.csrfToken,
        },
        body: JSON.stringify({
          initial_pipeline_file: envState.yamlPath,
        }),
      });

      if (!response.ok) {
        throw new Error(`Failed to update pipeline file`);
      }

      // Navigate to starter template
      navigate(`/starter_template`);
    } catch (error) {
      Notice.error(`Failed to update pipeline file. Please try again.`);
    }
  };

  const onSkipOnboarding = (e: Event) => {
    e.preventDefault();

    void handleSkipOnboarding({
      skipOnboardingUrl: configState.skipOnboardingUrl,
      csrfToken: configState.csrfToken,
      projectUrl: configState.projectUrl,
    });
  };

  return (
    <div className="pt3 pb5">
      <div className="relative mw8 center">
        <div className="flex-l">
          <components.InfoPanel
            svgPath="images/ill-girl-finger-up.svg"
            title="Select agent"
            subtitle="Choose the execution environment for your pipeline jobs."
            additionalInfo="Agents determine where your pipeline jobs run. Select a machine type that matches your project's requirements."
          />
          <div className="flex-auto w-two-thirds">
            <div className="pb3 mb3 bb b--black-10">
              <div className="flex justify-between items-center">
                <div>
                  <h2 className="f3 fw6 mb2">Agent configuration</h2>
                  <p className="black-70 mv0">Start configuring your workflow YAML by selecting an agent on which jobs will run.</p>
                </div>
              </div>
            </div>
            <div>
              <p className="f4 f3-m mb0">Configuration Location</p>
              <p className="f6 gray mb1">Specify the path for the pipeline configuration YAML file in your repository.</p>
              <div className="relative flex items-center ba b--black-20 br2 bg-white">
                <toolbox.Asset
                  path="images/icn-file.svg"
                  className="flex-shrink-0 mh2"
                  style="width: 16px; height: 16px;"
                />
                <input
                  type="text"
                  id="yaml-path"
                  className="form-control w-100 bn"
                  style="outline: none; box-shadow: none;"
                  value={envState.yamlPath}
                  onChange={(e) => setYamlPath(e.currentTarget.value)}
                />
              </div>
            </div>

            <div className="mt3">
              <p className="f4 f3-m mb0">Available Agents</p>
              <p className="f6 gray mb1">Select the agent you want to use for this project.</p>

              {configState.agentTypes?.cloud.length > 0 && (
                <Fragment>
                  <p className="f5 gray mb2">Cloud Machines</p>
                  <div className="flex flex-wrap">
                    {configState.agentTypes?.cloud.map((agent) => (
                      <Tippy
                        key={agent.type}
                        content={
                          <div>
                            {agent.vcpu} vCPU, {agent.ram} GB RAM, {agent.disk} GB SSD
                          </div>
                        }
                        placement="top"
                        trigger="mouseenter"
                      >
                        <div className="w-third pa2">
                          <AgentCard
                            key={agent.type}
                            agent={agent}
                            isCloud={true}
                            isSelected={envState.selectedAgentType?.type === agent.type}
                            onClick={() => handleAgentSelect(agent)}
                          />
                        </div>
                      </Tippy>
                    ))}
                  </div>
                </Fragment>
              )}

              {configState.agentTypes?.selfHosted.length > 0 && (
                <div>
                  <p className="f5 gray mb2">Self-hosted Machines</p>
                  <div className="flex flex-wrap">
                    {configState.agentTypes?.selfHosted.map((agent) => (
                      <div className="w-third pa2" key={agent.type}>
                        <AgentCard
                          agent={agent}
                          isCloud={false}
                          isSelected={envState.selectedAgentType?.type === agent.type}
                          onClick={() => handleAgentSelect(agent)}
                        />
                      </div>
                    ))}
                    {/* button for create new agent. */}
                    <div className={`w-third pa2`}>
                      <a href={configState.createSelfHostedAgentUrl} className={`link db btn btn-primary pa3 br3`}>
                        <div className="flex items-center">
                          <span className="material-symbols-outlined mr2 b">add</span>
                          <span className="f4 truncate">Create new</span>
                        </div>
                      </a>
                    </div>
                  </div>
                </div>
              )}

              {!configState.agentTypes?.cloud.length && !configState.agentTypes?.selfHosted.length && (
                <div className="pa3 bg-lightest-silver br2 gray tc">No machine types available at the moment</div>
              )}
            </div>

            <div className="mt3">
              <p className="f4 f3-m mb0">Initial Pipeline Configuration</p>
              <p className="f6 gray mb1">
                Base YAML configuration with selected agent. The rest of the pipeline will be configured in the next step.
              </p>
              <toolbox.YamlEditor
                value={envState.yamlContent}
                readOnly={true}
                height="208px"
              />
            </div>
            <div className="mt3">
              <div className="flex justify-between items-center">
                <div className="flex items-center">
                  <p className="f6 gray mb0 mr1">Next, we&apos;ll define your build steps and workflow. or you can </p>
                  <a
                    href="#"
                    onClick={onSkipOnboarding}
                    className="f6 link dim gray underline"
                    title="Skip the onboarding process and go directly to the project"
                  >
                    skip onboarding
                  </a>
                </div>
                <Tippy
                  placement="top"
                  content="Select an agent type to continue"
                  visible={envState.selectedAgentType ? false : true}
                >
                  <div>
                    <button
                      onClick={() => void handleContinue()}
                      className={`btn ${envState.selectedAgentType ? `btn-primary` : `btn-disabled`}`}
                      disabled={!envState.selectedAgentType}
                    >
                      Continue
                    </button>
                  </div>
                </Tippy>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
