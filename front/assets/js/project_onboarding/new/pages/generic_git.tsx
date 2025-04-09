import { Routes, Route } from "react-router-dom";
import * as stores from "../stores";
import * as types from "../types";
import { useSteps } from "../stores/create/steps";
import { Dispatch, StateUpdater, useContext, useEffect, useLayoutEffect,useState } from "preact/hooks";

import * as toolbox from "js/toolbox";
import { Repository } from "js/repository";
import { createContext, h } from "preact";


enum Step {
  SelectType = `select-type`,
  RepositorySetup = `repository-setup`,
  VerifyConnection = `verify-connection`,
}


export const Page = () => {
  const { dispatch } = useSteps();

  const steps = [
    { id: Step.SelectType, title: `Select project type` },
    { id: Step.RepositorySetup, title: `Repository setup` },
    { id: Step.VerifyConnection, title: `Verify connection` },
  ];

  const [repository, setRepository] = useState<Repository>({
    url: ``,
    projectName: ``,
  });

  useLayoutEffect(() => {
    dispatch([`SET_STEPS`, steps]);
  }, []);

  useEffect(() => {
    setRepository((prev) => ({ ...prev, url: `git@git.kutryj.pl/repos/agnostic.git` }));
  }, []);

  const nameFromUrl = (url: string) => {
    // Match SSH Git URLs like: git@github.com:user/repo.git
    const sshGitRegex = /^[\w.-]+@[\w.-]+:?[\w./-]+\.git$/;

    if (sshGitRegex.test(url)) {
      const parts = url.split(`/`);
      const repoWithGit = parts[parts.length - 1];
      return repoWithGit.replace(/\.git$/, ``);
    }

    return ``;
  };

  useEffect(() => {
    if(repository.projectName.length == 0) {
      const projectName = nameFromUrl(repository.url);
      setRepository((prev) => ({ ...prev, projectName }));
    }

  }, [repository.url]);

  useEffect(() => {
    dispatch([`SET_CURRENT`, Step.RepositorySetup]);
  }, [repository]);

  return (
    <RepositoryContext.Provider value={{ repository, setRepository: setRepository }}>
      <Routes>
        <Route path="/" element={<RepositorySetup/>}/>
        <Route path="/:projectName" element={<RepositoryConnect/>}/>
      </Routes>
    </RepositoryContext.Provider>
  );
};

const RepositoryConnect = () => {
  return <div>YEASH</div>;
};


const RepositorySetup = () => {
  return (
    <div className="flex-l">
      <div className="w-third ph4-l">
        <h1 className="f2 f1-m mb0">Connect repository</h1>
        <p className="mb4 measure">
          Give use some details about your repository and we&apos;ll help you set up
        </p>
        <div>
          <toolbox.Asset
            path="images/ill-girl-looking-down.svg"
            className="db ml2"
          />
        </div>
        <p className="f6 black-60 measure mv3">
          Semaphore will use this information to set up your project.
        </p>
      </div>
      <div className="w-two-thirds">
        <div className="pb3 mb3 bb b--black-10">
          <div>
            <h2 className="f3 fw6 mb2">Repository Details</h2>
            <p className="black-70 mv0">
              Configure access credentials and integration settings.
            </p>
          </div>
        </div>
        <div className="pb3 mb3">
          <SetRepositoryURL className="mb4"/>
          <SetProjectName className="mb4"/>
          <CreateRepository className="pt4 bt b--black-10"/>
        </div>
      </div>
    </div>
  );
};

const CreateRepository = (props: h.JSX.HTMLAttributes) => {
  const config = useContext(stores.Create.Config.Context);
  const { repository, setRepository } = useContext(RepositoryContext);

  const createRepository = () => {
    const url = new toolbox.APIRequest.Url<any>(`post`,config.createProjectUrl );

    void url.call({ body: {
      url: repository.url,
      integration_type: types.Provider.IntegrationType.Git,
      duplicate: `true`,
      name: repository.projectName,
    } }).then((response) => {
      console.log(response);
    } );

  };

  return <div className={props.className}>
    <div className="flex flex-column">
      <a className="btn btn-primary br2 f6 f5-m" onClick={createRepository}>
        <toolbox.Asset
          path="images/icn-plus.svg"
          className="self-center mr2"
          style={{ width: `16px`, height: `16px` }}
        />
        Create repository
      </a>
    </div>
  </div>;
};

const SetProjectName = (props: h.JSX.HTMLAttributes) => {
  const { repository, setRepository } = useContext(RepositoryContext);

  const setProjectName = (projectName) => setRepository((prev) => ({ ...prev, projectName }));
  return (
    <div className={props.className}>
      <div className="flex flex-column">
        <p className="f4 f3-m mb0">Project name</p>
        <p className="f6 gray mb1">
        A unique identifier for this project in Semaphore
        </p>
        <div>
          <div className="input-group relative flex items-center br2 bg-white flex-auto items-stretch mr2">
            <div
              className="flex br2 br--left"
              style={{
                boxShadow: `0 0 0 1px rgba(0, 0, 0, .2), inset 0 1px 1px 0 #E5E8EA`,
              }}
            >
              <toolbox.Asset
                path="images/icn-project.svg"
                className="self-center mh2"
                style={{ width: `16px`, height: `16px` }}
              />
            </div>
            <input
              type="text"
              className="form-control w-100 bn"
              value={repository.projectName}
              placeholder="project-name"
              onInput={(e) => setProjectName(e.currentTarget.value)}
            />
          </div>
        </div>
      </div>
    </div>
  );
};

const SetRepositoryURL = (props: h.JSX.HTMLAttributes) => {
  const { repository, setRepository } = useContext(RepositoryContext);

  const setUrl = (url: string) => setRepository((prev) => ({ ...prev, url }));
  return (
    <div className={props.className}>
      <div className="flex flex-column">
        <p className="f4 f3-m mb0">Repository URL</p>
        <p className="f6 gray mb1">
        A SSH URL to the Git repository where your code is hosted
        </p>
        <div>
          <div className="input-group relative flex items-center br2 bg-white flex-auto items-stretch mr2">
            <div
              className="flex br2 br--left"
              style={{
                boxShadow: `0 0 0 1px rgba(0, 0, 0, .2), inset 0 1px 1px 0 #E5E8EA`,
              }}
            >
              <span className="self-center mh2">ssh://</span>
            </div>
            <input
              type="text"
              className="form-control w-100 bn"
              value={repository.url}
              placeholder="username@hostname:port/path/to/repo.git"
              onInput={(e) => setUrl(e.currentTarget.value)}
            />
          </div>
        </div>
      </div>
    </div>
  );
};


const RepositoryContext = createContext<{
  repository: Repository;
  setRepository: Dispatch<StateUpdater<Repository>>;
}>(null);

interface Repository {
  url: string;
  projectName: string;
}
