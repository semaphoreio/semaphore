import { Fragment } from "preact";
import { useContext, useLayoutEffect, useReducer, useState } from "preact/hooks";
import * as stores from "../stores";
import * as types from "../types";
import * as components from "../components";
import * as toolbox from "js/toolbox";
// eslint-disable-next-line @typescript-eslint/ban-ts-comment
// @ts-ignore
import { Notice } from "js/notice";
import { useLocation, NavLink, useParams } from "react-router-dom";

export const ProjectPage = () => {
  const config = useContext(stores.Config.Context);
  const spendings = useContext(stores.Spendings.Context);
  const { projectName } = useParams();
  const [project, setProject] = useState<types.Spendings.DetailedProject>(types.Spendings.DetailedProject.Empty);

  const [request, dispatchRequest] = useReducer(stores.Request.Reducer, {
    url: new URL(config.projectSpendings.projectUrl as string, location.origin),
    status: types.RequestStatus.Zero,
  });

  useLayoutEffect(() => {
    if (spendings.state.selectedSpendingId) {
      dispatchRequest({ type: `SET_PARAM`, name: `spending_id`, value: spendings.state.selectedSpendingId });
      dispatchRequest({ type: `SET_PARAM`, name: `project_name`, value: projectName });
      dispatchRequest({ type: `FETCH` });
    }
  }, [spendings.state.selectedSpendingId]);

  useLayoutEffect(() => {
    if (request.status == types.RequestStatus.Fetch) {
      dispatchRequest({ type: `SET_STATUS`, value: types.RequestStatus.Loading });
      fetch(request.url)
        .then((response) => response.json())
        .then((json) => {
          dispatchRequest({ type: `SET_STATUS`, value: types.RequestStatus.Success });
          const detailedProject = types.Spendings.DetailedProject.fromJSON(json);
          setProject(detailedProject);
        })
        .catch(() => {
          dispatchRequest({ type: `SET_STATUS`, value: types.RequestStatus.Error });
          Notice.error(`Loading projects failed`);
        });
    }
  }, [request.status]);

  const { search } = useLocation();
  return (
    <stores.Request.Context.Provider value={{ state: request, dispatch: dispatchRequest }}>
      <div className="flex items-center justify-between">
        <div>
          <div className="inline-flex items-center">
            <p className="mb0 b f3">
              <NavLink to={`/projects/${search}`}>Projects spending</NavLink>
              {` > `}
              {projectName}
            </p>
          </div>
          <div className="gray mb3 measure flex items-center">
            <div className="pr2 mr2">Review detailed project spending.</div>
          </div>
        </div>
        <components.SpendingSelect/>
      </div>
      <components.PlanFlags/>
      <components.Loader.Container
        loadingElement={<components.Loader.LoadingSpinner text={`Loading ${projectName} project...`}/>}
        loadingFailedElement={<components.Loader.LoadingFailed text={`Loading ${projectName} failed`} retry={true}/>}
      >
        <Chart project={project}/>
        <Fragment>
          {project.cost.groups.map((group, idx) => (
            <components.SpendingGroup
              showItemTotalPriceTrends={true}
              hideUsage={true}
              hideUnitPrice={true}
              group={group}
              key={idx}
            />
          ))}
        </Fragment>
      </components.Loader.Container>
    </stores.Request.Context.Provider>
  );
};

export const Chart = ({ project }: { project: types.Spendings.DetailedProject }) => {
  return (
    <div className="shadow-1 bg-white br3 mb3">
      <div className="flex items-center justify-between pa3 bb bw1 b--black-075 br3 br--top">
        <div>
          <div className="flex items-center">
            <span className="material-symbols-outlined pr2">stacked_bar_chart</span>
            <div className="b">Detailed summary</div>
          </div>
        </div>
      </div>

      <div className="flex bb b--black-075">
        <WorkflowGroup project={project}/>
        {project.cost.groups.map((group, idx) => (
          <SpendingGroup
            price={group.price}
            group={group}
            lastItem={idx == project.cost.groups.length - 1}
            key={idx}
          />
        ))}
      </div>

      <components.ProjectChart project={project}/>
    </div>
  );
};
interface SpendingGroupProps {
  group: types.Spendings.Group;
  price: string;
  lastItem?: boolean;
}

const SpendingGroup = ({ group, price, lastItem }: SpendingGroupProps) => {
  return (
    <div className={`w-100 b--black-075 pa3 ${lastItem ? `` : `br`}`}>
      <div className="inline-flex items-center f5">
        <div className="mr1">
          <span
            className="mr2 dib"
            style={`width:10px; height: 10px; background-color:${types.Spendings.Group.hexColor(group.type)}`}
          ></span>
          {group.name}
        </div>
        <components.GroupTooltip group={group}/>
      </div>

      <div className="f4 flex items-center pv1">
        <span className="b">{price}</span>
        <components.Trend.PriceTooltip item={group}/>
      </div>
    </div>
  );
};

interface WorkflowGroupProps {
  project: types.Spendings.DetailedProject;
}

const WorkflowGroup = (props: WorkflowGroupProps) => {
  return (
    <div className={`w-100 b--black-075 pa3 br`}>
      <div className="inline-flex items-center f5">
        <div className="mr1">
          <span
            className="mr2 dib"
            style={`width:10px; height: 10px; background-color:${toolbox.Formatter.colorFromName(`workflows`)}`}
          ></span>
          Workflows
        </div>
      </div>

      <div className="f4 flex items-center pv1">
        <span className="b">{toolbox.Formatter.decimalThousands(props.project.cost.workflowCount)}</span>
        <components.Trend.UsageTooltip item={props.project.cost}/>
      </div>
    </div>
  );
};
