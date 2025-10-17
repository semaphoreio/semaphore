import { Fragment } from "preact";
import { useNavigate } from "react-router-dom";
import * as toolbox from "js/toolbox";
import { useContext, useEffect, useState } from "preact/hooks";
import * as stores from "js/agents/stores";
import type * as types from "js/agents/types";
import type { TargetedEvent } from "preact/compat";
import _ from "lodash";

// eslint-disable-next-line @typescript-eslint/ban-ts-comment
// @ts-ignore
import { Notice } from "js/notice";

export const Edit = () => {
  const { state } = useContext(stores.SelfHostedAgent.Context);
  const navigate = useNavigate();
  const config = useContext(stores.Config.Context);
  const [loading, setLoading] = useState(false);
  const [agentType, setAgentType] = useState<types.SelfHosted.AgentType>(null);

  useEffect(() => {
    if (state.type && !agentType) {
      setAgentType(state.type);
    }
  }, [state.type]);

  if (!agentType) {
    return;
  }

  const onAssignmentOriginChange = (e: TargetedEvent) => {
    const target = e.currentTarget as HTMLInputElement;
    const value = target.value;

    setAgentNameAssignmentOrigin(value);
  };

  const onAgentNameReleaseChange = (e: TargetedEvent) => {
    const target = e.currentTarget as HTMLInputElement;
    const value = target.value;
    if (value == `yes`) {
      setAgentNameRelease(0);
    } else {
      setAgentNameRelease(60);
    }
  };

  const setAgentNameRelease = (value: number) => {
    agentType.settings.nameReleaseAfter = value;

    setAgentType(_.cloneDeep(agentType));
  };

  const setAgentNameAssignmentOrigin = (value: string) => {
    agentType.settings.assignmentOrigin =
      value as types.SelfHosted.AssignmentOrigin;

    setAgentType(_.cloneDeep(agentType));
  };

  const changeAwsAccount = (e: TargetedEvent) => {
    const target = e.currentTarget as HTMLInputElement;
    agentType.settings.awsAccount = target.value;

    setAgentType(_.cloneDeep(agentType));
  };

  const changeAwsRolePatterns = (e: TargetedEvent) => {
    const target = e.currentTarget as HTMLInputElement;
    agentType.settings.awsRolePatterns = target.value;
    setAgentType(_.cloneDeep(agentType));
  };

  const save = () => {
    setLoading(true);
    return agentType
      .update(config.selfHostedUrl)
      .catch(Notice.error)
      .then(() => {
        Notice.notice(`Agent type ${agentType.name} updated`);
        navigate(`..`);
      })
      .finally(() => setLoading(false));
  };

  return (
    <Fragment>
      <div className="bg-white shadow-1 br3 mb3">
        <div className="pa3 pa4-l">
          <div className="flex items-start">
            <toolbox.Asset
              path="images/icn-self-hosted.svg"
              className="db w2 h2 mr4"
            />
            <div>
              <div className="flex items-center">
                <div className="bg-white pl2 pr1 pv1 bl bt bb br3 br--left b--light-gray">
                  s1-
                </div>
                <input
                  className="form-control br--right"
                  value={agentType.settings.nameSuffix}
                  size={40}
                  disabled
                />
              </div>
              <div>
                <p className="f5 b mb2 mt2">Agent name assignment origin</p>
                <div className="flex items-center">
                  <label>
                    <input
                      type="radio"
                      name="assignmentOrigin"
                      className="mr2"
                      value="ASSIGNMENT_ORIGIN_AGENT"
                      onChange={onAssignmentOriginChange}
                      checked={
                        agentType.settings.assignmentOrigin ===
                        `ASSIGNMENT_ORIGIN_AGENT`
                      }
                    />
                    Agent name is directly assigned by the agent.
                  </label>
                </div>
                <div className="flex items-center">
                  <label>
                    <input
                      type="radio"
                      name="assignmentOrigin"
                      className="mr2"
                      value="ASSIGNMENT_ORIGIN_AWS_STS"
                      onChange={onAssignmentOriginChange}
                      checked={
                        agentType.settings.assignmentOrigin ===
                        `ASSIGNMENT_ORIGIN_AWS_STS`
                      }
                    />
                    Agent name is assigned from a pre-signed AWS STS
                    GetCallerIdentity URL
                  </label>
                </div>
                {agentType.settings.isAwsConfigRequired() && (
                  <div>
                    <div className="ml3 mv3 pv2 ph3 ba b--lighter-gray bg-white br2">
                      <div className="mv3">
                        <p className="f5 b mb1">What is the AWS account ID?</p>
                        <div className="mt2">
                          <input
                            className="form-control w-25"
                            type="text"
                            value={agentType.settings.awsAccount}
                            onChange={changeAwsAccount}
                          />
                          <p className="f6 mt1 mb0">
                            Only agent registrations using pre-signed URLs for
                            this account will be allowed.
                          </p>
                        </div>
                      </div>
                      <div className="mv3">
                        <p className="f5 b mb1">
                          What are the AWS IAM role names allowed?
                        </p>
                        <div className="mt2">
                          <input
                            className="form-control w-50"
                            type="text"
                            value={agentType.settings.awsRolePatterns}
                            onChange={changeAwsRolePatterns}
                            placeholder="my-role-1,another-role-*"
                          />
                          <p className="f6 mt1 mb0">
                            A comma-separated list of role names allowed. You
                            can use wildcard characters (*).
                          </p>
                        </div>
                      </div>
                    </div>
                  </div>
                )}
              </div>
              <div>
                <p className="f5 b mb2 mt2">Agent name release</p>
                <div className="flex items-center">
                  <label>
                    <input
                      type="radio"
                      name="agentNameRelease"
                      className="mr2"
                      onChange={onAgentNameReleaseChange}
                      value="yes"
                      checked={agentType.settings.isNameReleasedImmediately()}
                    />
                    Agent name is reusable immediately after it disconnects
                    disconnecting
                  </label>
                </div>
                <div className="flex items-center">
                  <label>
                    <input
                      type="radio"
                      name="agentNameRelease"
                      className="mr2"
                      onChange={onAgentNameReleaseChange}
                      value="no"
                      checked={!agentType.settings.isNameReleasedImmediately()}
                    />
                    Agent name is reusable only after some time from it
                    disconnecting
                  </label>
                </div>
                {!agentType.settings.isNameReleasedImmediately() && (
                  <div>
                    <div
                      id="name-release-options"
                      className="hide ml3 mv3 pv2 ph3 ba b--lighter-gray bg-white br2"
                      style="display: block;"
                    >
                      <div className="mv3">
                        <p className="f5 b mb1">How much time (in seconds)?</p>
                        <div className="mt2">
                          <input
                            className="form-control w-25"
                            type="number"
                            value={agentType.settings.nameReleaseAfter}
                            onChange={(e) =>
                              setAgentNameRelease(
                                parseInt(e.currentTarget.value)
                              )
                            }
                          />
                        </div>
                      </div>
                    </div>
                  </div>
                )}
              </div>

              <div className="f6 mt4 mb3">
                <div className="flex">
                  <button
                    className="btn btn-primary mr3"
                    id="register-self-hosted-agent"
                    onClick={() => void save()}
                    disabled={loading}
                  >
                    Looks good. Update
                    {loading && (
                      <toolbox.Asset
                        path="images/spinner.svg"
                        className="ml1"
                      />
                    )}
                  </button>
                  <button
                    className="btn btn-secondary"
                    onClick={() => navigate(`..`)}
                    disabled={loading}
                  >
                    Cancel
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Fragment>
  );
};
