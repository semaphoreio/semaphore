import * as stores from "../../stores";
import * as components from "../";
import { useContext, useState } from "preact/hooks";
import { Fragment, h, VNode } from "preact";
import styled from "styled-components";

export const name = `AWS`;
export const icon = `images/icn-os-aws.svg`;

export const Component = (): VNode => {
  const hostname = location.hostname;

  const { state } = useContext(stores.SelfHostedAgent.Context);

  type osType = `linux` | `windows` | `macos`;
  const [selectedOs, setSelectedOs] = useState<osType>(`linux`);

  interface SubOSProps extends h.JSX.HTMLAttributes {
    name: string;
    active: boolean;
  }
  const SubOS = (
    props: SubOSProps
  ) => {
    const ButtonEl = styled.button`
      &:hover,
      &.active {
        box-shadow: 0 0 0 3px #00359f !important;
      }
    `;
    return (
      <ButtonEl
        onClick={props.onClick}
        className={`btn btn-secondary flex items-center mr3 bw1 br3 wf-insights-hover ${
          props.active ? `active` : ``
        }`}
      >
        {props.children}
        <span className="ml2">{props.name}</span>
      </ButtonEl>
    );
  };

  return (
    <Fragment>
      <div className="flex ph3-l mb4">
        <SubOS
          name="Linux"
          onClick={() => setSelectedOs(`linux`)}
          active={selectedOs == `linux`}
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            fill="#000000"
            width="16px"
            viewBox="0 0 304.998 304.998"
            xmlSpace="preserve"
          >
            <g id="XMLID_91_">
              <path
                id="XMLID_92_"
                d="M274.659,244.888c-8.944-3.663-12.77-8.524-12.4-15.777c0.381-8.466-4.422-14.667-6.703-17.117   c1.378-5.264,5.405-23.474,0.004-39.291c-5.804-16.93-23.524-42.787-41.808-68.204c-7.485-10.438-7.839-21.784-8.248-34.922   c-0.392-12.531-0.834-26.735-7.822-42.525C190.084,9.859,174.838,0,155.851,0c-11.295,0-22.889,3.53-31.811,9.684   c-18.27,12.609-15.855,40.1-14.257,58.291c0.219,2.491,0.425,4.844,0.545,6.853c1.064,17.816,0.096,27.206-1.17,30.06   c-0.819,1.865-4.851,7.173-9.118,12.793c-4.413,5.812-9.416,12.4-13.517,18.539c-4.893,7.387-8.843,18.678-12.663,29.597   c-2.795,7.99-5.435,15.537-8.005,20.047c-4.871,8.676-3.659,16.766-2.647,20.505c-1.844,1.281-4.508,3.803-6.757,8.557   c-2.718,5.8-8.233,8.917-19.701,11.122c-5.27,1.078-8.904,3.294-10.804,6.586c-2.765,4.791-1.259,10.811,0.115,14.925   c2.03,6.048,0.765,9.876-1.535,16.826c-0.53,1.604-1.131,3.42-1.74,5.423c-0.959,3.161-0.613,6.035,1.026,8.542   c4.331,6.621,16.969,8.956,29.979,10.492c7.768,0.922,16.27,4.029,24.493,7.035c8.057,2.944,16.388,5.989,23.961,6.913   c1.151,0.145,2.291,0.218,3.39,0.218c11.434,0,16.6-7.587,18.238-10.704c4.107-0.838,18.272-3.522,32.871-3.882   c14.576-0.416,28.679,2.462,32.674,3.357c1.256,2.404,4.567,7.895,9.845,10.724c2.901,1.586,6.938,2.495,11.073,2.495   c0.001,0,0,0,0.001,0c4.416,0,12.817-1.044,19.466-8.039c6.632-7.028,23.202-16,35.302-22.551c2.7-1.462,5.226-2.83,7.441-4.065   c6.797-3.768,10.506-9.152,10.175-14.771C282.445,250.905,279.356,246.811,274.659,244.888z M124.189,243.535   c-0.846-5.96-8.513-11.871-17.392-18.715c-7.26-5.597-15.489-11.94-17.756-17.312c-4.685-11.082-0.992-30.568,5.447-40.602   c3.182-5.024,5.781-12.643,8.295-20.011c2.714-7.956,5.521-16.182,8.66-19.783c4.971-5.622,9.565-16.561,10.379-25.182   c4.655,4.444,11.876,10.083,18.547,10.083c1.027,0,2.024-0.134,2.977-0.403c4.564-1.318,11.277-5.197,17.769-8.947   c5.597-3.234,12.499-7.222,15.096-7.585c4.453,6.394,30.328,63.655,32.972,82.044c2.092,14.55-0.118,26.578-1.229,31.289   c-0.894-0.122-1.96-0.221-3.08-0.221c-7.207,0-9.115,3.934-9.612,6.283c-1.278,6.103-1.413,25.618-1.427,30.003   c-2.606,3.311-15.785,18.903-34.706,21.706c-7.707,1.12-14.904,1.688-21.39,1.688c-5.544,0-9.082-0.428-10.551-0.651l-9.508-10.879   C121.429,254.489,125.177,250.583,124.189,243.535z M136.254,64.149c-0.297,0.128-0.589,0.265-0.876,0.411   c-0.029-0.644-0.096-1.297-0.199-1.952c-1.038-5.975-5-10.312-9.419-10.312c-0.327,0-0.656,0.025-1.017,0.08   c-2.629,0.438-4.691,2.413-5.821,5.213c0.991-6.144,4.472-10.693,8.602-10.693c4.85,0,8.947,6.536,8.947,14.272   C136.471,62.143,136.4,63.113,136.254,64.149z M173.94,68.756c0.444-1.414,0.684-2.944,0.684-4.532   c0-7.014-4.45-12.509-10.131-12.509c-5.552,0-10.069,5.611-10.069,12.509c0,0.47,0.023,0.941,0.067,1.411   c-0.294-0.113-0.581-0.223-0.861-0.329c-0.639-1.935-0.962-3.954-0.962-6.015c0-8.387,5.36-15.211,11.95-15.211   c6.589,0,11.95,6.824,11.95,15.211C176.568,62.78,175.605,66.11,173.94,68.756z M169.081,85.08   c-0.095,0.424-0.297,0.612-2.531,1.774c-1.128,0.587-2.532,1.318-4.289,2.388l-1.174,0.711c-4.718,2.86-15.765,9.559-18.764,9.952   c-2.037,0.274-3.297-0.516-6.13-2.441c-0.639-0.435-1.319-0.897-2.044-1.362c-5.107-3.351-8.392-7.042-8.763-8.485   c1.665-1.287,5.792-4.508,7.905-6.415c4.289-3.988,8.605-6.668,10.741-6.668c0.113,0,0.215,0.008,0.321,0.028   c2.51,0.443,8.701,2.914,13.223,4.718c2.09,0.834,3.895,1.554,5.165,2.01C166.742,82.664,168.828,84.422,169.081,85.08z    M205.028,271.45c2.257-10.181,4.857-24.031,4.436-32.196c-0.097-1.855-0.261-3.874-0.42-5.826   c-0.297-3.65-0.738-9.075-0.283-10.684c0.09-0.042,0.19-0.078,0.301-0.109c0.019,4.668,1.033,13.979,8.479,17.226   c2.219,0.968,4.755,1.458,7.537,1.458c7.459,0,15.735-3.659,19.125-7.049c1.996-1.996,3.675-4.438,4.851-6.372   c0.257,0.753,0.415,1.737,0.332,3.005c-0.443,6.885,2.903,16.019,9.271,19.385l0.927,0.487c2.268,1.19,8.292,4.353,8.389,5.853   c-0.001,0.001-0.051,0.177-0.387,0.489c-1.509,1.379-6.82,4.091-11.956,6.714c-9.111,4.652-19.438,9.925-24.076,14.803   c-6.53,6.872-13.916,11.488-18.376,11.488c-0.537,0-1.026-0.068-1.461-0.206C206.873,288.406,202.886,281.417,205.028,271.45z    M39.917,245.477c-0.494-2.312-0.884-4.137-0.465-5.905c0.304-1.31,6.771-2.714,9.533-3.313c3.883-0.843,7.899-1.714,10.525-3.308   c3.551-2.151,5.474-6.118,7.17-9.618c1.228-2.531,2.496-5.148,4.005-6.007c0.085-0.05,0.215-0.108,0.463-0.108   c2.827,0,8.759,5.943,12.177,11.262c0.867,1.341,2.473,4.028,4.331,7.139c5.557,9.298,13.166,22.033,17.14,26.301   c3.581,3.837,9.378,11.214,7.952,17.541c-1.044,4.909-6.602,8.901-7.913,9.784c-0.476,0.108-1.065,0.163-1.758,0.163   c-7.606,0-22.662-6.328-30.751-9.728l-1.197-0.503c-4.517-1.894-11.891-3.087-19.022-4.241c-5.674-0.919-13.444-2.176-14.732-3.312   c-1.044-1.171,0.167-4.978,1.235-8.337c0.769-2.414,1.563-4.91,1.998-7.523C41.225,251.596,40.499,248.203,39.917,245.477z"
              />
            </g>
          </svg>
        </SubOS>
        <SubOS
          name="MacOS"
          onClick={() => setSelectedOs(`macos`)}
          active={selectedOs == `macos`}
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            fill="#000000"
            width="16px"
            viewBox="0 0 305 305"
            xmlSpace="preserve"
          >
            <g id="XMLID_228_">
              <path
                id="XMLID_229_"
                d="M40.738,112.119c-25.785,44.745-9.393,112.648,19.121,153.82C74.092,286.523,88.502,305,108.239,305   c0.372,0,0.745-0.007,1.127-0.022c9.273-0.37,15.974-3.225,22.453-5.984c7.274-3.1,14.797-6.305,26.597-6.305   c11.226,0,18.39,3.101,25.318,6.099c6.828,2.954,13.861,6.01,24.253,5.815c22.232-0.414,35.882-20.352,47.925-37.941   c12.567-18.365,18.871-36.196,20.998-43.01l0.086-0.271c0.405-1.211-0.167-2.533-1.328-3.066c-0.032-0.015-0.15-0.064-0.183-0.078   c-3.915-1.601-38.257-16.836-38.618-58.36c-0.335-33.736,25.763-51.601,30.997-54.839l0.244-0.152   c0.567-0.365,0.962-0.944,1.096-1.606c0.134-0.661-0.006-1.349-0.386-1.905c-18.014-26.362-45.624-30.335-56.74-30.813   c-1.613-0.161-3.278-0.242-4.95-0.242c-13.056,0-25.563,4.931-35.611,8.893c-6.936,2.735-12.927,5.097-17.059,5.097   c-4.643,0-10.668-2.391-17.645-5.159c-9.33-3.703-19.905-7.899-31.1-7.899c-0.267,0-0.53,0.003-0.789,0.008   C78.894,73.643,54.298,88.535,40.738,112.119z"
              />
              <path
                id="XMLID_230_"
                d="M212.101,0.002c-15.763,0.642-34.672,10.345-45.974,23.583c-9.605,11.127-18.988,29.679-16.516,48.379   c0.155,1.17,1.107,2.073,2.284,2.164c1.064,0.083,2.15,0.125,3.232,0.126c15.413,0,32.04-8.527,43.395-22.257   c11.951-14.498,17.994-33.104,16.166-49.77C214.544,0.921,213.395-0.049,212.101,0.002z"
              />
            </g>
          </svg>
        </SubOS>
        <SubOS
          name="Windows"
          onClick={() => setSelectedOs(`windows`)}
          active={selectedOs == `windows`}
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            fill="#000000"
            width="16px"
            viewBox="0 0 305 305"
            xmlSpace="preserve"
          >
            <g id="XMLID_108_">
              <path
                id="XMLID_109_"
                d="M139.999,25.775v116.724c0,1.381,1.119,2.5,2.5,2.5H302.46c1.381,0,2.5-1.119,2.5-2.5V2.5   c0-0.726-0.315-1.416-0.864-1.891c-0.548-0.475-1.275-0.687-1.996-0.583L142.139,23.301   C140.91,23.48,139.999,24.534,139.999,25.775z"
              />
              <path
                id="XMLID_110_"
                d="M122.501,279.948c0.601,0,1.186-0.216,1.644-0.616c0.544-0.475,0.856-1.162,0.856-1.884V162.5   c0-1.381-1.119-2.5-2.5-2.5H2.592c-0.663,0-1.299,0.263-1.768,0.732c-0.469,0.469-0.732,1.105-0.732,1.768l0.006,98.515   c0,1.25,0.923,2.307,2.16,2.477l119.903,16.434C122.274,279.94,122.388,279.948,122.501,279.948z"
              />
              <path
                id="XMLID_138_"
                d="M2.609,144.999h119.892c1.381,0,2.5-1.119,2.5-2.5V28.681c0-0.722-0.312-1.408-0.855-1.883   c-0.543-0.475-1.261-0.693-1.981-0.594L2.164,42.5C0.923,42.669-0.001,43.728,0,44.98l0.109,97.521   C0.111,143.881,1.23,144.999,2.609,144.999z"
              />
              <path
                id="XMLID_169_"
                d="M302.46,305c0.599,0,1.182-0.215,1.64-0.613c0.546-0.475,0.86-1.163,0.86-1.887l0.04-140   c0-0.663-0.263-1.299-0.732-1.768c-0.469-0.469-1.105-0.732-1.768-0.732H142.499c-1.381,0-2.5,1.119-2.5,2.5v117.496   c0,1.246,0.918,2.302,2.151,2.476l159.961,22.504C302.228,304.992,302.344,305,302.46,305z"
              />
            </g>
          </svg>
        </SubOS>

        {/* <components.OsBox
          name="Linux"
          icon="images/icn-os-linux.svg"
          active={selectedOs == `linux`}
          onClick={() => setSelectedOs(`linux`)}
        />
        <components.OsBox
          name="MacOS"
          icon="images/icn-os-mac.svg"
          active={selectedOs == `macos`}
          onClick={() => setSelectedOs(`macos`)}
        />
        <components.OsBox
          name="Windows"
          icon="images/icn-os-windows.svg"
          active={selectedOs == `windows`}
          onClick={() => setSelectedOs(`windows`)}
        /> */}
      </div>
      <components.InstructionList>
        <ol>
          <li>
            <div className="mb2">
              Install the{` `}
              <a
                href="https://github.com/renderedtext/agent-aws-stack/releases"
                target="_blank"
                rel="noreferrer"
              >
                latest AWS stack
              </a>
              {` `}
              and dependencies
            </div>
            <components.PreCopy
              title="Installing AWS stack and dependencies"
              content={`curl -sL https://github.com/renderedtext/agent-aws-stack/archive/refs/tags/v0.3.6.tar.gz -o agent-aws-stack.tar.gz
                        tar -xf agent-aws-stack.tar.gz
                        cd agent-aws-stack-0.3.6
                        npm install`}
            />
          </li>
          <li>
            <div className="mb2">
              Build the AMI images Build the container images using Packer.io.
              You can build Linux, Windows, and macOS images Images are built by
              default for the &qout;us-east-1&qout; region. To change regions
              add
              <components.Code content="AWS_REGION"/> to the Packer command.
            </div>
            <div className="mb2">For example:</div>
            <components.PreCopy
              title="Changing AWS region"
              content={`make packer.build AWS_REGION=us-west-1`}
            />

            <div className="mt2">
              {selectedOs == `linux` && (
                <components.PreCopy
                  title="Build Ubuntu-based Docker image"
                  content={`make packer.init
                          make packer.build`}
                />
              )}

              {selectedOs == `windows` && (
                <components.PreCopy
                  title="Build Windows Server-based image"
                  content={`make packer.init
                          make packer.build PACKER_OS=windows`}
                />
              )}

              {selectedOs == `macos` && (
                <components.PreCopy
                  title="Build macOS image"
                  content={`make packer.init

                          # To build an AMD AMI (EC2 mac1 family)
                          make packer.build PACKER_OS=macos AMI_ARCH=x86_64 AMI_INSTANCE_TYPE=mac1.metal

                          # To build an ARM AMI (EC2 mac2 family)
                          make packer.build PACKER_OS=macos AMI_ARCH=arm64 AMI_INSTANCE_TYPE=mac2.metal`}
                />
              )}
            </div>
          </li>
          <li>
            <div className="mb2">Encrypt your registration token</div>
            <div className="mb2">
              The registration token created when registering the agent must be
              encrypted on AWS using{` `}
              <a
                target="_blank"
                href="https://docs.aws.amazon.com/systems-manager/latest/userguide/ssm-agent.html"
                rel="noreferrer"
              >
                SSM
              </a>
            </div>
            <div className="mb2">
              To create an SSM secret, run the following command:
              <components.ResetTokenButton/>
            </div>
            <components.PreCopy
              title="Creating an SSM secret"
              content={`aws ssm put-parameter \\
                          --name <ssm-parameter-name> \\
                          --value "${state.token}" \\
                          --type SecureString`}
            />
            <div className="mt2">
              Replace:
              <ul>
                <li>
                  <components.Code content="<ssm-parameter-name>"/> with the
                  name for the secret, e.g.{` `}
                  <components.Code content="semaphore-registration-token"/>
                </li>
              </ul>
            </div>
          </li>
          <li>
            <div className="mb2">
              Create an execution policy for Cloudformation
            </div>
            <div className="mb2">
              Run the following command to create execution-policy.json. This
              instructs CDK to list the Cloudformation permissions it needs to
              deploy the self-hosted agents
            </div>
            <components.PreCopy
              title="Obtaining the Cloudformation policy"
              content={`aws iam create-policy \\
                          --policy-name agent-aws-stack-cfn-execution-policy \\
                          --policy-document file://$(pwd)/execution-policy.json \\
                          --description "Cloudformation policy to deploy the agent-aws-stack"`}
            />
          </li>
          <li>
            <div className="mb2">Configure the stack</div>
            <div className="mb2">
              Create configuration files for all the image types you plan to
              use. These files are used by the self-hosted agent to access your
              Semaphore organization
            </div>
            {selectedOs == `linux` && (
              <components.PreCopy
                title="config.json"
                content={`{
                            "SEMAPHORE_AGENT_STACK_NAME": "<stack-name>",
                            "SEMAPHORE_AGENT_TOKEN_PARAMETER_NAME": "<ssm-parameter-name>",
                            "SEMAPHORE_AGENT_TOKEN_KMS_KEY": "<ssm-parameter-name>",
                            "SEMAPHORE_ENDPOINT": "${hostname}"
                          }`}
              />
            )}

            {selectedOs == `windows` && (
              <components.PreCopy
                title="config.json"
                content={`{
                            "SEMAPHORE_AGENT_STACK_NAME": "<stack-name>",
                            "SEMAPHORE_AGENT_TOKEN_PARAMETER_NAME": "<ssm-parameter-name>",
                            "SEMAPHORE_AGENT_TOKEN_KMS_KEY": "<ssm-parameter-name>",
                            "SEMAPHORE_ENDPOINT": "${hostname}",
                            "SEMAPHORE_AGENT_OS": "windows"
                          }`}
              />
            )}

            {selectedOs == `macos` && (
              <Fragment>
                <components.PreCopy
                  title="config.json"
                  content={`{
                            "SEMAPHORE_AGENT_STACK_NAME": "<stack-name>",
                            "SEMAPHORE_AGENT_TOKEN_PARAMETER_NAME": "<ssm-parameter-name>",
                            "SEMAPHORE_AGENT_TOKEN_KMS_KEY": "<ssm-parameter-name>",
                            "SEMAPHORE_ENDPOINT": "${hostname},
                            "SEMAPHORE_AGENT_OS": "macos",
                            "SEMAPHORE_AGENT_DISCONNECT_AFTER_IDLE_TIMEOUT": "86400",
                            "SEMAPHORE_AGENT_MAC_FAMILY": "mac1",
                            "SEMAPHORE_AGENT_INSTANCE_TYPE": "mac1.metal",
                            "SEMAPHORE_AGENT_AZS": "us-east-1a,us-east-1b,us-east-1d",
                            "SEMAPHORE_AGENT_LICENSE_CONFIGURATION_ARN": "arn:aws:license-manager:<region>:<accountId>:license-configuration:<license-configuration>"
                        }`}
                />
                <div className="mt2 mb2">
                  When a macOS instance is terminated it may take a long time
                  for new one to start in its place. This may affect the time to
                  rotate agents.
                </div>
                <div className="mt2 mb2">
                  macOS dedicated hosts are allocated for a minimum of 24 hours.
                  It is recommended to set
                  <a
                    href="https://docs.semaphoreci.com/reference/agent-aws-stack#disconnect-after-idle-timeout"
                    target="_blank"
                    rel="noreferrer"
                  >
                    <components.Code content="SEMAPHORE_AGENT_DISCONNECT_AFTER_IDLE_TIMEOUT"/>
                  </a>
                  to at least 24 hours for macOS-based agents. This means that
                  new instances started up due to a burst of demand may continue
                  running idle for a long time before being shutdown.
                </div>
                <div className="mt2 mb2">
                  See{` `}
                  <a
                    target="_blank"
                    href="https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-mac-instances.html"
                    rel="noreferrer"
                  >
                    Amazon EC2 Mac instances
                  </a>
                  {` `}
                  for more information.
                </div>
              </Fragment>
            )}
            <div className="mb2">
              Replace:
              <ul>
                <li>
                  <components.Code content="<stack-name>"/> with the name of
                  the stack, e.g.
                  <components.Code content="my-aws-agents-linux"/>
                </li>
                <li>
                  <components.Code content="<ssm-parameter-name>"/> with the
                  name of the secret created on Step 3
                </li>
                <li>
                  <components.Code content="<license-configuration>"/> the
                  license information from Apple (only for macOS)
                </li>
              </ul>
            </div>
          </li>
          <li>
            <div className="mb2">Bootstrap the CDK application</div>
            <div className="mb2">
              Open the file <components.Code content="execution-policy.json"/>
              {` `}
              created in Step 4 and copy the ARN value.
            </div>
            <components.PreCopy
              title="Bootstrapping the CDK application"
              content={`SEMAPHORE_AGENT_STACK_CONFIG=config.json \\
                        npm run bootstrap -- aws://<AWS_ACCOUNT_ID>/<AWS_REGION> \\
                        --cloudformation-execution-policies <Arn>`}
            />
            <div className="mt2 mb2">
              Replace:
              <ul>
                <li>
                  <components.Code content="<Arn>"/> with the value from the
                  policy file
                </li>
                <li>
                  <components.Code content="<AWS_ACCOUNT_ID>"/> your AWS
                  account id
                </li>
                <li>
                  <components.Code content="<AWS_REGION>"/> your AWS region
                </li>
              </ul>
            </div>
            <div className="mb2">
              If you omit the option{` `}
              <components.Code content="--cloudformation-execution-policies"/>
              the stack will be deployed using full AdministratorAccess policies
            </div>
          </li>
          <li>
            <div className="mb2">Deploy the stack</div>
            <div className="mb2">
              To deploy the stack, execute the following command
            </div>
            <components.PreCopy
              title="Deploy the stack"
              content="SEMAPHORE_AGENT_STACK_CONFIG=config.json npm run deploy"
            />
          </li>
        </ol>
      </components.InstructionList>
    </Fragment>
  );
};
