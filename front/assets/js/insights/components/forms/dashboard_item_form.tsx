import { h } from 'preact';
// eslint-disable-next-line @typescript-eslint/ban-ts-comment
// @ts-ignore
import { Notice } from '../../../notice';
import { useState } from 'preact/hooks';

interface Props {
  toggle: () => void;
  saveHandler: (o: object) => void;
}


export const DashboardItemForm = ({ toggle, saveHandler }: Props) => {
  const [state, setState] = useState({
    dashboardName: ``,
    metric: ``,
    branchName: ``,
    pipelineFileName: ``,
    notes: ``,
  });

  const cleanupState = () => {
    setState({
      dashboardName: ``,
      metric: ``,
      branchName: ``,
      pipelineFileName: ``,
      notes: ``,
    });
  };

  const onInputName = (e: any) => {
    const { value } = e.target;
    setState({ ...state, dashboardName: value });
  };

  const onInputPipeline = (e: any) => {
    const { value } = e.target;
    setState({ ...state, pipelineFileName: value });
  };

  const onInputNotes = (e: any) => {
    const { value } = e.target;
    setState({ ...state, notes: value });
  };

  const onInputBranch = (e: any) => {
    const { value } = e.target;
    setState({ ...state, branchName: value });
  };


  const onChangeMetric = (e: any) => {
    const { value } = e.target;
    setState({ ...state, metric: value });
  };

  const onSubmit = (e: any) => {
    e.preventDefault();
    const errorMessage = validateState(state.dashboardName, state.branchName, state.metric);
    if (errorMessage.length > 0) {
      Notice.error(errorMessage);
      return;
    }
    saveHandler(state);
    cleanupState();
    toggle();
  };

  return (
    <form onSubmit={onSubmit} id="dashboard-item-form">
      <div className="bg-white shadow-1 br3 pa3 mt1" id="custom-zero">
        <p className="b f5">New Metric</p>

        <div className="mb3">
          <label className="db mb1 f6" htmlFor="name">Name</label>
          <input id="name"
            style="max-width: 276px;"
            className="w-100 form-control"
            placeholder="ex. Duration"
            value={state.dashboardName}
            onInput={onInputName}/>
        </div>

        <div className="mb3">
          <label className="db mb1 f6" htmlFor="metric">Metric</label>
          <select id="metric"
            style="max-width: 296px;"
            value={state.metric}
            onChange={onChangeMetric}
            className="w-100 form-control">
            <option value="">Select a metric</option>
            <option value="1">Pipeline Performance</option>
            <option value="2">Pipeline Frequency</option>
            <option value="3">Pipeline Reliability</option>
          </select>
        </div>

        <div className="mb3" hidden={state.metric.length === 0}>
          <label className="db mb1 f6" htmlFor="branch_name">Branch Name</label>
          <input id="branch_name" className="w-100 form-control"
            placeholder="ex. main"
            style="max-width: 276px;"
            value={state.branchName}
            onInput={onInputBranch}/>
        </div>

        <div className="mb3" hidden={state.metric.length === 0}>
          <label className="db mb1 f6" htmlFor="pipeline_file_name">Pipeline Path</label>
          <input id="pipeline_file_name" className="w-100 form-control"
            placeholder=".semaphore/semaphore.yml"
            style="max-width: 276px;"
            value={state.pipelineFileName}
            onInput={onInputPipeline}/>
        </div>

        <div className="mb3" hidden={state.metric.length === 0}>
          <label className="db mb1 f6" htmlFor="notes">Description <span className="normal black-60">(optional)</span></label>
          <textarea id="notes" className="w-100 form-control"
            type="text"
            rows={5}
            cols={30}
            placeholder="This metric is used to measure..."
            value={state.notes}
            onInput={onInputNotes}/>
        </div>

        <div className="flex mt4">
          <button className="btn btn-primary" type="submit">Save</button>
          <button className="btn btn-secondary ml2" type="reset" onClick={toggle}>Cancel</button>
        </div>
      </div>
    </form>
  );
};


const validateState = (name: string, branch: string, metric: string) => {
  if (name.length === 0) {
    return `Name is missing`;
  }

  if (metric.length === 0) {
    return `please select a Metric`;
  }

  return ``;
};
