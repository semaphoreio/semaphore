import { Routes, Route, useNavigate, useParams, Outlet } from "react-router-dom";
import * as stores from "../stores";
import * as types from "../types";
import { useSteps } from "../stores/create/steps";
import { Dispatch, StateUpdater, useContext, useEffect, useLayoutEffect, useState } from "preact/hooks";

import * as toolbox from "js/toolbox";
import { createContext, h } from "preact";

import Editor from "@monaco-editor/react";
import dedent from "dedent";

enum Step {
  SelectType = `select-type`,
  RepositorySetup = `repository-setup`,
  ConnectRepository = `connect-repository`,
  ConfigureHook = `configure-hook`,
}

export const Page = () => {
  const { dispatch } = useSteps();

  const steps = [
    { id: Step.SelectType, title: `Select project type` },
    { id: Step.RepositorySetup, title: `Setup the project` },
    { id: Step.ConnectRepository, title: `Connect repository` },
    { id: Step.ConfigureHook, title: `Configure hook` },
  ];

  const [repository, setRepository] = useState<Repository>(EmptyRepository);

  useLayoutEffect(() => {
    dispatch([`SET_STEPS`, steps]);
  }, []);

  return (
    <RepositoryContext.Provider value={{ repository, setRepository: setRepository }}>
      <Routes>
        <Route path="/" element={<RepositorySetup/>}/>
        <Route path="/:projectName" element={<LoadRepository/>}>
          <Route path="" element={<ConnectRepository/>}/>
          <Route path="hook" element={<ConfigureHook/>}/>
        </Route>
      </Routes>
    </RepositoryContext.Provider>
  );
};

const RepositorySetup = () => {
  const { dispatch } = useSteps();
  const { repository, setRepository } = useContext(RepositoryContext);
  const config = useContext(stores.Create.Config.Context);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(``);
  const navigate = useNavigate();

  useEffect(() => {
    dispatch([`SET_CURRENT`, Step.RepositorySetup]);
  }, []);

  const setUrl = (url: string) => setRepository((prev) => ({ ...prev, url }));
  const setProjectName = (projectName) => setRepository((prev) => ({ ...prev, name: projectName }));

  const createRepository = () => {
    const url = new toolbox.APIRequest.Url<{ project_name: string, error?: string }>(`post`, config.createProjectUrl);
    setLoading(true);
    setError(``);

    void url
      .call({
        body: {
          url: repository.url,
          integration_type: types.Provider.IntegrationType.Git,
          name: repository.name,
          duplicate: `true`,
        },
      })
      .then((response) => {
        if (response.error || response.data?.error) {
          setError(response.data.error);
          return;
        }

        navigate(`./${response.data.project_name}`);
      })
      .finally(() => {
        setTimeout(() => {
          setLoading(false);
        }, 2000);
      });
  };

  return (
    <div className="flex-l">
      <div className="w-third ph4-l">
        <h1 className="f2 f1-m mb0">Setup project</h1>
        <p className="mb4 measure">Define how Semaphore should recognize and reference your project.</p>
        <div>
          <toolbox.Asset path="images/ill-girl-looking-down.svg" className="db ml2"/>
        </div>
        <p className="f6 black-60 measure mv3">Semaphore will use this information to set up your project.</p>
      </div>
      <div className="w-two-thirds">
        <div className="pb3 mb3 bb b--black-10">
          <div>
            <h2 className="f3 fw6 mb2">Project Information</h2>
            <p className="black-70 mv0">Provide the repository URL and choose a name for your project.</p>
          </div>
        </div>
        <div className="pb3 mb3">
          <p className="f4 f3-m mb0">Repository URL</p>
          <p className="f6 gray mb1">The Git repository address where your code is hosted</p>
          <input
            type="text"
            className="form-control w-100 bn"
            value={repository.url}
            placeholder="ssh://username@hostname:user/repo.git"
            onInput={(e) => setUrl(e.currentTarget.value)}
          />
          <p className="f6 gray mt1">
            Must be a valid SSH Git URL (e.g. <code>ssh://git@example.com:user/repo.git</code>)
          </p>
          <div className="mt2">
            <p className="f4 f3-m mb0">Project name</p>
            <p className="f6 gray mb1">A unique identifier for this project in Semaphore</p>
            <div className="flex items-center">
              <div className="relative flex items-center ba b--black-20 br2 bg-white flex-auto mr2">
                <toolbox.Asset
                  path="images/icn-project.svg"
                  className="self-center mh2"
                  style={{ width: `16px`, height: `16px` }}
                />
                <input
                  type="text"
                  id="project-name"
                  placeholder="project-name"
                  className="form-control w-100 bn"
                  style="outline: none; box-shadow: none;"
                  value={repository.name}
                  onInput={(e) => setProjectName(e.currentTarget.value)}
                />
              </div>
              <button
                className="btn btn-primary flex"
                onClick={createRepository}
                disabled={loading}
              >
                {loading && <toolbox.Asset path="images/spinner-2.svg" style={{ width: `20px`, height: `20px`, margin: `0` }}/>}
                {!loading && <span>✓</span>}
              </button>
            </div>
            {!loading && <div className="red mt2 tc">{error}</div>}
          </div>
        </div>
      </div>
    </div>
  );
};

const LoadRepository = () => {
  const { projectName } = useParams();
  const navigate = useNavigate();
  const { setRepository } = useContext(RepositoryContext);

  useEffect(() => {
    let timeoutId: number;

    const fetchRepository = () => {
      const url = new toolbox.APIRequest.Url<any>(`get`, `/projects/${projectName}/repository_status`);

      void url
        .call()
        .then((response) => {
          if (response.error) {
            throw `oops`;
          }

          setRepository((prev) => ({
            ...prev,
            name: response.data.project_name,
            connected: response.data.connected,
            resetWebhookSecretUrl: response.data.reset_webhook_secret_url,
            agentName: response.data.agent_name,
            agentConfigUrl: response.data.agent_config_url,
            publicKey: response.data.deploy_key?.public_key,
          }));

          // Retry if not connected
          if (!response.data.connected) {
            timeoutId = window.setTimeout(fetchRepository, 5000);
          }
        })
        .catch(() => {
          navigate(`/`);
        });
    };

    fetchRepository();

    // Cleanup on unmount
    return () => {
      clearTimeout(timeoutId);
    };
  }, [projectName]);

  return <Outlet/>;
};

const ConfigureHook = () => {
  const { dispatch } = useSteps();
  const { setRepository, repository } = useContext(RepositoryContext);

  useEffect(() => {
    dispatch([`SET_CURRENT`, Step.ConfigureHook]);
  }, []);

  const generateWebhookSecret = () => {
    const url = new toolbox.APIRequest.Url<{ secret: string, endpoint: string }>(`post`, `${repository.resetWebhookSecretUrl}`);

    void url.call().then((response) => {
      if (response.data) {
        setRepository((prev) => ({ ...prev, webhookSecret: response.data.secret, webhookEndpoint: response.data.endpoint }));
      }
    });
  };

  const GenerateWebhookButton = (props: h.JSX.IntrinsicElements[`button`]) => {
    return (
      <div>
        {repository.connected && (
          <div className="mv3 bg-washed-yellow pa2 br2">
            <p>
              <span>⚠️</span>
              <span className={`ml2`}>Script already generated</span>
            </p>
            <p className="mb0">
              We see that you&apos;ve already generated a webhook script. If you want to regenerate it - click the button below.
            </p>
          </div>
        )}
        <button className={props.className} onClick={generateWebhookSecret}>
          {repository.connected && `Regenerate Script`}
          {!repository.connected && `Generate Script`}
        </button>
      </div>
    );
  };

  const ConfigureWorkflowButton = () => {
    if (!repository.connected) {
      return (
        <button className="btn btn-secondary flex" disabled={true}>
          <toolbox.Asset path="images/spinner-2.svg" style={{ width: `20px`, height: `20px` }}/>
          Waiting for first webhook
        </button>
      );
    } else {
      return (
        <button
          className="btn btn-primary flex"
          onClick={() => {
            window.location.href = `/projects/${repository.name}`;
          }}
        >
          Configure workflow
        </button>
      );
    }
  };

  return (
    <div className="flex-l">
      <div className="w-third ph4-l">
        <h1 className="f2 f1-m mb0">Install Git Hook</h1>
        <p className="mb4 measure">Set up an automatic connection between your Git repository and Semaphore.</p>
        <div>
          <toolbox.Asset path="images/ill-girl-looking-down.svg" className="db ml2"/>
        </div>
        <p className="f6 black-60 measure mv3">Semaphore will use this information to set up your project.</p>
      </div>
      <div className="w-two-thirds">
        <div>
          <p>
            To enable automatic workflow execution on push, Semaphore uses a custom{` `}
            <span className="bg-washed-yellow ph2 ba b--black-075 br3">post-receive</span> Git hook. This hook sends events to Semaphore
            every time you push new commits.
          </p>
        </div>
        {!repository.webhookSecret && <p>We will generate a script for you, which you can install in your Git repository.</p>}
        {repository.webhookSecret && (
          <>
            <p>
              Copy the following <span className="bg-washed-yellow ph2 ba b--black-075 br3">post-receive</span> script into the{` `}
              <span className="bg-washed-yellow ph2 ba b--black-075 br3">hooks</span> directory of your <strong>bare</strong> Git
              repository:
            </p>
            <div style="height: 50vh;">
              <ConnectRepositoryEditor/>
            </div>
            <div className="mv3 pa3 bg-washed-yellow br2">
              After installing the hook, push any commit to trigger a webhook and complete the setup.
            </div>
            <div className="mv3 flex justify-end">
              <ConfigureWorkflowButton/>
            </div>
          </>
        )}
        {!repository.webhookSecret && <GenerateWebhookButton className="btn btn-green flex mr3"/>}
      </div>
    </div>
  );
};

const ConnectRepositoryEditor = () => {
  const { repository } = useContext(RepositoryContext);

  const data = `#!/bin/bash

  read oldrev newrev refname
  # === Config ===
  SECRET="${repository.webhookSecret}"
  ENDPOINT="${repository.webhookEndpoint}"

  commit_message=$(git log -1 --pretty=format:%s $newrev)
  author_name=$(git log -1 --pretty=format:%an $newrev)
  author_email=$(git log -1 --pretty=format:%ae $newrev)
  branch_name="\${refname#refs/heads/}"

  # === Build JSON payload ===
  payload_file=$(mktemp)
  cat > "$payload_file" <<EOF
  {
    "event": "deploy",
    "status": "success",
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "reference": "refs/heads/$branch_name",
    "commit": {
      "sha": "$newrev",
      "message": "$commit_message"
    },
    "author": {
      "name": "$author_name",
      "email": "$author_email"
    }
  }
  EOF

  # === Sign the payload with HMAC-SHA256 ===
  SIGNATURE=$(openssl dgst -sha256 -hmac "$SECRET" "$payload_file" | awk '{print $2}' | tr 'A-F' 'a-f')
  SIGNATURE="sha256=$SIGNATURE"

  # === Send via curl ===
  curl "$ENDPOINT" \\
    -H "Content-Type: application/json" \\
    -H "X-Hub-Signature: $SIGNATURE" \\
    --data-binary @"$payload_file"

  rm -f "$payload_file"
  `;

  return (
    <Editor
      height="100%"
      defaultLanguage="shell"
      value={dedent(data)}
      path={`post-receive`}
      options={{
        minimap: { enabled: false },
        scrollBeyondLastLine: false,
        fontSize: 14,
        lineNumbers: `on`,
        renderLineHighlight: `none`,
        scrollbar: {
          vertical: `auto`,
          horizontal: `auto`,
        },
        readOnly: true,
      }}
      theme="vs-light"
    />
  );
};

const RepositoryContext = createContext<{
  repository: Repository;
  setRepository: Dispatch<StateUpdater<Repository>>;
}>(null);

interface Repository {
  url: string;
  name: string;
  publicKey: string;
  webhookSecret: string;
  webhookEndpoint: string;
  connected: boolean;
  resetWebhookSecretUrl: string;
  agentName: string;
  agentConfigUrl: string;
}

const EmptyRepository: Repository = {
  url: ``,
  name: ``,
  publicKey: ``,
  resetWebhookSecretUrl: ``,
  webhookSecret: ``,
  webhookEndpoint: ``,
  agentName: ``,
  agentConfigUrl: ``,
  connected: false,
};

const ConnectRepository = () => {
  const { dispatch } = useSteps();
  const { repository } = useContext(RepositoryContext);

  useEffect(() => {
    dispatch([`SET_CURRENT`, Step.ConnectRepository]);
  }, []);

  const navigate = useNavigate();

  return (
    <div className="flex-l">
      <div className="w-third ph4-l">
        <h1 className="f2 f1-m mb0">Authorize Semaphore to access your repository</h1>
        <p className="mb4 measure">To allow Semaphore to access your Git repository we need to set up an SSH key.</p>
        <div>
          <toolbox.Asset path="images/ill-girl-looking-down.svg" className="db ml2"/>
        </div>
        <p className="f6 black-60 measure mv3">We&apos;ll use this ssh key to connect to your Git repository</p>
      </div>
      <div className="w-two-thirds">
        {!repository.agentName && (
          <div className="mb4">
            <h2 className="f3 fw6">Agent Configuration</h2>
            <div className="mv3 bg-washed-yellow pa2 br2">
              <p>
                <span>⚠️</span>
                <span className={`ml2`}>No agent configuration for initialization job found.</span>
              </p>
              <p className="mb0">
                The initialization job is responsible for setting up the environment for your workflow. Please add an agent configuration in
                your
                <a
                  href={`${repository.agentConfigUrl}`}
                  className="ml1 link underline"
                  target="_blank"
                  rel="noreferrer"
                >
                  project agent settings
                </a>
                .
              </p>
            </div>
          </div>
        )}

        <div className="mb4">
          <h2 className="f3 fw6">Authorize Semaphore to access your repository</h2>

          <p className="mb2">
            We will use this SSH key to connect to your Git repository to fetch the code and trigger builds.
            <br/>
            This key is unique to this project.
          </p>

          <p className="mb2">
            To authorize access, you need to{` `}
            <a
              href="https://git-scm.com/book/en/v2/Git-on-the-Server-Setting-Up-the-Server"
              target="_blank"
              rel="noreferrer"
            >
              add
            </a>{` `}
            the following public key to your Git server.
          </p>
          <toolbox.PreCopy content={repository.publicKey || `Loading public key...`} className="pr4"/>
        </div>
        <div className="flex justify-between items-center mt4">
          <p className="f6 gray mb0">Next we&apos;ll configure the webhook to trigger builds on push.</p>
          <button
            className="btn btn-primary"
            onClick={() => {
              navigate(`./hook`);
            }}
          >
            Continue
          </button>
        </div>
      </div>
    </div>
  );
};
