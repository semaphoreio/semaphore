import { Routes, Route } from "react-router-dom";
import { useSteps } from "../stores/create/steps";
import { useEffect, useLayoutEffect, useState } from "preact/hooks";

import * as toolbox from "js/toolbox";
import { TargetedEvent } from "react-dom/src";

export const Page = () => {
  const { dispatch } = useSteps();

  const steps = [
    { id: `select-type`, title: `Select project type` },
    { id: `setup-project`, title: `Setup the project` },
    { id: `select-environment`, title: `Select the environment` },
    { id: `setup-workflow`, title: `Setup workflow` },
  ];

  useLayoutEffect(() => {
    dispatch([`SET_STEPS`, steps]);
  }, []);

  return (
    <Routes>
      <Route path="/" element={<FirstStep/>}/>
    </Routes>
  );
};

const FirstStep = () => {
  const { dispatch } = useSteps();

  useEffect(() => {
    dispatch([`SET_CURRENT`, `setup-project`]);
  }, []);

  return (
    <div className="pt3 pb5">
      <div className="relative mw8 center">
        <div className="flex-l">
          <div className="w-third ph4-l">
            <h1 className="f2 f1-m mb0">Connect repository</h1>
            <p className="mb4 measure">
              Configure repository access and integration settings.
            </p>
            <div>
              <toolbox.Asset path="images/ill-girl-looking-down.svg" className="db ml2"/>

            </div>
            <p className="f6 black-60 measure mv3">
              TODO
            </p>
          </div>
          <div className="w-two-thirds">
            <div className="pb3 mb3 bb b--black-10">
              <div className="flex justify-between items-center">
                <p>Create generic git repository</p>
                <p>TODO</p>
              </div>
            </div>
            <div className="pb3 mb3">
              <GenericGitRepositoryCreator/>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

const GenericGitRepositoryCreator = () => {
  const [repository, setRepository] = useState({
    url: ``,
    projectName: ``,
    signingSecret: `abcdefghijklmnopqrstuvwxyz0123456789`,
  });

  const setUrl = (url) => setRepository(prev => ({ ...prev, url }));
  const setProjectName = (projectName) => setRepository(prev => ({ ...prev, projectName }));
  const setSigningSecret = (signingSecret) => setRepository(prev => ({ ...prev, signingSecret }));

  return <div>
    <pre>
      {JSON.stringify(repository)}
    </pre>
    <br/>
    <div className="flex flex-column">
      <label>
        <p className="mb1">Project name</p>
        <input className="form-control" type="text" value={repository.projectName} onInput={(e) => setProjectName(e.currentTarget.value)}/>
      </label>
      <label>
        <p className="mb1">Repository url</p>
        <input className="form-control" type="text" value={repository.url} onInput={(e) => setUrl(e.currentTarget.value)}/>
      </label>
      <label>
        <p className="mb1">Signing Secret</p>
        <input className="form-control" type="text" value={repository.signingSecret} onInput={(e) => setSigningSecret(e.currentTarget.value)}/>
      </label>
    </div>
  </div>;
};
