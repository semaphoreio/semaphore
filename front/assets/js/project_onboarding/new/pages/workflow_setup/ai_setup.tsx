import { useContext, useState, useEffect, useRef, useCallback } from "preact/hooks";
import { WorkflowSetup } from "../../stores";
import { useNavigate } from "react-router-dom";
// eslint-disable-next-line @typescript-eslint/ban-ts-comment
// @ts-ignore
import { Notice } from "js/notice";
import { useSteps } from "../../stores/create/steps";

type OnboardingStatus = "running" | "completed" | "failed";

interface StatusResponse {
  status: OnboardingStatus;
  yaml_content?: string;
  commit_sha?: string;
  branch?: string;
  error?: string;
  tool_log?: string[];
}

const TOOL_LABELS: Record<string, string> = {
  describe_project: "Analyzing repository",
  get_files: "Listing project files",
  get_repository_file: "Reading file",
  validate_yaml: "Validating pipeline config",
  commit_semaphore_yml: "Committing pipeline",
};

function formatToolName(name: string): string {
  return TOOL_LABELS[name] || name;
}

const POLL_INTERVAL_MS = 3000;

export const AiSetup = () => {
  const { state: configState } = useContext(WorkflowSetup.Config.Context);
  const navigate = useNavigate();
  const { dispatch } = useSteps();

  const [status, setStatus] = useState<OnboardingStatus | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [toolLog, setToolLog] = useState<string[]>([]);

  const sessionKeyRef = useRef<string | null>(null);
  const pollTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const startedRef = useRef(false);

  useEffect(() => {
    dispatch([`SET_CURRENT`, `setup-workflow`]);
  }, []);

  const checkWorkflow = useCallback(async (branch: string, commitSha: string) => {
    if (!configState.checkWorkflowUrl) return;

    const params = new URLSearchParams({ branch, commit_sha: commitSha });
    const url = `${configState.checkWorkflowUrl}?${params.toString()}`;

    try {
      const response = await fetch(url);
      const data = await response.json();

      if (data.artifact_url !== null && data.artifact_url !== undefined) {
        const shaResponse = await fetch(data.artifact_url);
        const sha = await shaResponse.text();
        setTimeout(() => void checkWorkflow(branch, sha.trim()), 1000);
        return;
      }

      if (data.workflow_url == null) {
        setTimeout(() => void checkWorkflow(branch, commitSha), 1000);
      } else {
        window.location.href = data.workflow_url;
      }
    } catch (error) {
      Notice.error(`Error starting the workflow: ${error}`);
    }
  }, [configState.checkWorkflowUrl]);

  const pollStatus = useCallback(async () => {
    if (!configState.aiOnboardingStatusUrl || !sessionKeyRef.current) return;

    const params = new URLSearchParams({ session_key: sessionKeyRef.current });
    const url = `${configState.aiOnboardingStatusUrl}?${params.toString()}`;

    try {
      const response = await fetch(url);
      const data: StatusResponse = await response.json();

      if (data.tool_log && data.tool_log.length > 0) {
        setToolLog(data.tool_log);
      }

      if (data.error && data.status !== "running") {
        setStatus("failed");
        setErrorMessage(data.error);
        return;
      }

      setStatus(data.status);

      if (data.status === "completed" && data.branch && data.commit_sha) {
        void checkWorkflow(data.branch, data.commit_sha);
        return;
      }

      if (data.status === "failed") {
        setErrorMessage(data.error || "An unexpected error occurred.");
        return;
      }

      // Still running — schedule next poll
      pollTimerRef.current = setTimeout(() => void pollStatus(), POLL_INTERVAL_MS);
    } catch {
      // Network error — retry
      pollTimerRef.current = setTimeout(() => void pollStatus(), POLL_INTERVAL_MS);
    }
  }, [configState.aiOnboardingStatusUrl, checkWorkflow]);

  const startOnboarding = useCallback(async () => {
    if (!configState.aiOnboardingUrl) return;

    try {
      const response = await fetch(configState.aiOnboardingUrl, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": configState.csrfToken,
        },
      });

      const data = await response.json();

      if (data.error) {
        setStatus("failed");
        setErrorMessage(data.error);
        return;
      }

      sessionKeyRef.current = data.session_key;
      setStatus("running");

      // Start polling
      pollTimerRef.current = setTimeout(() => void pollStatus(), POLL_INTERVAL_MS);
    } catch (error) {
      setStatus("failed");
      setErrorMessage(`Failed to start AI onboarding: ${error}`);
    }
  }, [configState.aiOnboardingUrl, configState.csrfToken, pollStatus]);

  useEffect(() => {
    if (startedRef.current) return;
    startedRef.current = true;
    void startOnboarding();

    return () => {
      if (pollTimerRef.current) clearTimeout(pollTimerRef.current);
    };
  }, [startOnboarding]);

  // Deduplicate consecutive tool names for cleaner display
  const displaySteps = toolLog.reduce<string[]>((acc, name) => {
    if (acc.length === 0 || acc[acc.length - 1] !== name) {
      acc.push(name);
    }
    return acc;
  }, []);

  const isCompleted = status === "completed";

  return (
    <div className="pt3 pb5">
      <div className="relative mw7 center">
        <div className="bg-white br3 shadow-1 pa4 pa5-l">
          {status !== "failed" ? (
            <>
              <h2 className="f3 fw6 mb2 tc">AI is setting up your pipeline</h2>
              <p className="black-60 tc mt0 mb4">
                The AI agent is analyzing your repository and generating a CI/CD configuration.
              </p>

              <div className="ph3 ph4-l">
                {displaySteps.length > 0 ? (
                  displaySteps.map((toolName, index) => {
                    const isDone = isCompleted || index < displaySteps.length - 1;
                    const isActive = !isCompleted && index === displaySteps.length - 1;

                    return (
                      <div key={`${toolName}-${index}`} className="flex items-center mb3">
                        <div className="mr3 flex-shrink-0" style="width: 24px; height: 24px;">
                          {isDone ? (
                            <span className="material-symbols-outlined green" style="font-size: 24px;">
                              check_circle
                            </span>
                          ) : isActive ? (
                            <div
                              className="br-100 ba b--blue"
                              style="width: 24px; height: 24px; border-width: 3px; border-top-color: transparent; animation: spin 1s linear infinite;"
                            />
                          ) : (
                            <div
                              className="br-100 ba b--black-20"
                              style="width: 24px; height: 24px;"
                            />
                          )}
                        </div>
                        <span className={`f5 ${isDone ? "green" : isActive ? "dark-gray fw5" : "black-40"}`}>
                          {formatToolName(toolName)}
                        </span>
                      </div>
                    );
                  })
                ) : (
                  <div className="flex items-center mb3">
                    <div className="mr3 flex-shrink-0" style="width: 24px; height: 24px;">
                      <div
                        className="br-100 ba b--blue"
                        style="width: 24px; height: 24px; border-width: 3px; border-top-color: transparent; animation: spin 1s linear infinite;"
                      />
                    </div>
                    <span className="f5 dark-gray fw5">Starting up...</span>
                  </div>
                )}
              </div>

              {isCompleted && (
                <p className="tc black-60 mt4 mb0">Redirecting to your workflow...</p>
              )}

              <div className="tc mt4">
                <button
                  className="btn bg-transparent black-50 pointer"
                  onClick={() => navigate("/starter_template")}
                >
                  Skip — set up manually
                </button>
              </div>
            </>
          ) : (
            <>
              <div className="tc">
                <span className="material-symbols-outlined red mb3" style="font-size: 48px;">
                  error
                </span>
                <h2 className="f3 fw6 mb2">Something went wrong</h2>
                <p className="black-60 mt0 mb4">
                  {errorMessage || "The AI agent encountered an error while setting up your pipeline."}
                </p>

                <div className="flex justify-center gap-3">
                  <button
                    className="btn btn-primary"
                    onClick={() => navigate("/starter_template")}
                  >
                    Set up manually
                  </button>
                </div>
              </div>
            </>
          )}
        </div>
      </div>

      <style>{`
        @keyframes spin {
          to { transform: rotate(360deg); }
        }
      `}</style>
    </div>
  );
};
