import { h } from 'preact';
import { useContext, useLayoutEffect, useReducer } from 'preact/hooks';
import { Config } from '../app';

// eslint-disable-next-line @typescript-eslint/ban-ts-comment
// @ts-ignore
import { Notice } from '../../notice';
import * as stores from '../stores';
import { Headers } from "../../flaky_tests/network/request";


export const InsightsSettings = () => {
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  const [_, dispatchLoading] = useReducer(stores.Loading.Reducer, stores.Loading.EmptyState);
  const { insightsSettingsUrl } = useContext(Config);

  const [branchState, dispatchSettingsBranch] = useReducer(stores.SettingsBranch.Reducer, stores.SettingsBranch.EmptyState);


  const Setters = (type: any) => {
    return (e: Event) => {
      const target = e.target as HTMLSelectElement;
      dispatchSettingsBranch({ type: type, value: target.value });
    };
  };

  const save = (e: Event) => {
    e.preventDefault();
    const data = {
      ci_branch_name: branchState.ciBranchName,
      ci_pipeline_file_name: branchState.ciPipelineFileName,
      cd_branch_name: branchState.cdBranchName,
      cd_pipeline_file_name: branchState.cdPipelineFileName
    };


    if (data.cd_branch_name.length == 0 && data.cd_pipeline_file_name.length != 0
        || data.cd_branch_name.length != 0 && data.cd_pipeline_file_name.length == 0) {
      Notice.error(`Both Branch Name and Pipeline File Path are required.`);
      return;
    }


    fetch(insightsSettingsUrl, {
      method: `POST`,
      credentials: `same-origin`,
      body: JSON.stringify(data),
      headers: Headers(`application/json`)
    })
      .then((response) => {
        if (!response.ok) {
          Notice.error(`Failed to save settings. Please try again.`);
          return;
        }

        Notice.notice(`Settings saved.`);
      })
      .catch(() => {
        Notice.error(`Failed to save settings. Please try again.`);
      });
  };

  useLayoutEffect(() => {
    dispatchLoading({ type: `RESET` });
    fetch(insightsSettingsUrl)
      .then(response => response.json())
      .then(json => {
        dispatchSettingsBranch({ type: `SET_STATE`, state: {
          ciBranchName: json.ci_branch_name,
          ciPipelineFileName: json.ci_pipeline_file_name,
          cdBranchName: json.cd_branch_name,
          cdPipelineFileName: json.cd_pipeline_file_name
        } });
      }).catch((err) => {
        dispatchLoading({ type: `ADD_ERROR`, error: err });
      })
      .finally(() => {
        dispatchLoading({ type: `LOADED` });
      });
  }, []);


  return (
    <div className="w-100 pa4">
      <div className="mt3 bg-white pa3 shadow-1 br3">
        <form onSubmit={save} action="javascript:">
          <label className="f3 b">Continuous Integration</label>
          <div className="measure">Tell Semaphore which is your main CI branch and which pipeline is running your tests.
          </div>
          <div className="mt3 bb b--lighter-gray pb3 mb3">

            <div className="mt3">
              <label className="db f6">Branch</label>
              <input type="text" className="form-control w6 mt2"
                onInput={Setters(`SET_CI_BRANCH_NAME`)} value={branchState.ciBranchName} placeholder="master"/>
            </div>

            <div className="mt3 mb2">
              <label className="db f6">Pipeline Path</label>
              <input type="text" className="form-control w6 mt2"
                onInput={Setters(`SET_CI_PIPELINE_FILE_NAME`)} value={branchState.ciPipelineFileName}
                placeholder=".semaphore/semaphore.yml"/>
            </div>


          </div>
          <label className="f3 b">Continuous Deployment</label>
          <div className="measure">Tell Semaphore which is your main CD branch and which pipeline is running your
          deployment scripts.
          </div>
          <div className="mt3">


            <div className="mt3">
              <label className="db f6">Branch</label>
              <input type="text" className="form-control w6 mt2"
                onInput={Setters(`SET_CD_BRANCH_NAME`)} value={branchState.cdBranchName} placeholder="master"/>
            </div>

            <div className="mt3">
              <label className="db f6">Pipeline Path</label>
              <input type="text" className="form-control w6 mt2"
                onInput={Setters(`SET_CD_PIPELINE_FILE_NAME`)} value={branchState.cdPipelineFileName}
                placeholder=".semaphore/deployment.yml"/>
            </div>
          </div>
          <div className="mt3">
            <button type="submit" className="btn btn-primary mr2 mt2">Save changes</button>
          </div>
        </form>
      </div>
    </div>
  );
};
