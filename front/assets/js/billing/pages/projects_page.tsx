import { Fragment, VNode, h } from "preact";
import { useContext, useLayoutEffect, useMemo, useReducer, useState } from "preact/hooks";
import * as stores from "../stores";
import * as types from "../types";
import * as toolbox from "js/toolbox";
import * as components from "../components";
// eslint-disable-next-line @typescript-eslint/ban-ts-comment
// @ts-ignore
import { Notice } from "js/notice";
import _ from "lodash";
import { useLocation, NavLink } from "react-router-dom";

export const ProjectsPage = () => {
  return (
    <Fragment>
      <div className="flex items-center justify-between">
        <div>
          <div className="inline-flex items-center">
            <p className="mb0 b f3">Projects spending</p>
          </div>
          <div className="gray mb3 measure flex items-center">
            <div className="pr2 mr2">Review your per-project spendings in detail.</div>
          </div>
        </div>
        <components.SpendingSelect/>
      </div>
      <components.PlanFlags/>
      <ProjectsChart/>
      <ProjectList/>
    </Fragment>
  );
};

export const ProjectsChart = () => {
  return (
    <div className="shadow-1 bg-white br3 mb3">
      <div className="flex items-center justify-between pa3 bb bw1 b--black-075 br3 br--top">
        <div>
          <div className="flex items-center">
            <span className="material-symbols-outlined pr2">stacked_bar_chart</span>
            <div className="b">Top 5 active projects</div>
          </div>
        </div>
      </div>
      <components.ProjectsChart/>
    </div>
  );
};

export const ProjectList = () => {
  const config = useContext(stores.Config.Context);
  const spendings = useContext(stores.Spendings.Context);
  const [projects, setProjects] = useState<types.Spendings.Project[]>([]);
  const [request, dispatchRequest] = useReducer(stores.Request.Reducer, {
    url: new URL(config.projectSpendings.projectsUrl as string, location.origin),
    status: types.RequestStatus.Zero,
  });
  const [orderBy, setOrderBy] = useState(``);
  const [orderByDir, setOrderByDir] = useState<`desc` | `asc`>(`desc`);
  const [projectNameFilter, setProjectNameFilter] = useState(``);
  const [filteredProjects, setFilteredProjects] = useState<types.Spendings.Project[]>(projects);

  useLayoutEffect(() => {
    if(spendings.state.selectedSpendingId) {
      dispatchRequest({ type: `SET_PARAM`, name: `spending_id`, value: spendings.state.selectedSpendingId });
      dispatchRequest({ type: `FETCH` });
      setProjects([]);

    }
  }, [spendings.state.selectedSpendingId]);

  useLayoutEffect(() => {
    if(request.status == types.RequestStatus.Fetch) {
      dispatchRequest({ type: `SET_STATUS`, value: types.RequestStatus.Loading });
      fetch(request.url)
        .then((response) => response.json())
        .then((json) => {
          dispatchRequest({ type: `SET_STATUS`, value: types.RequestStatus.Success });
          let projects = json.map(types.Spendings.Project.fromJSON) as types.Spendings.Project[];

          projects = _.orderBy(projects, [`totalRaw`], [`desc`]);
          setProjects(projects);
        })
        .catch((e) => {
          // eslint-disable-next-line no-console
          console.error(e);
          dispatchRequest({ type: `SET_STATUS`, value: types.RequestStatus.Error });
          Notice.error(`Loading projects failed`);
        });
    }
  }, [request.status]);

  useLayoutEffect(() => {
    let p = projects;
    if(p) {
      if(projectNameFilter && projects.length > 0) {
        p = projects.filter((project) => {
          return project.name.toLowerCase().includes(projectNameFilter.toLowerCase());
        });
      }

      if(orderBy) {
        switch(orderBy) {
          case `name`:
            p = _.orderBy(p, [(project) => project.name.toLowerCase()], [orderByDir]);
            break;
          case `workflowCount`:
            p = _.orderBy(p, [(project) => project.cost.workflowCount], [orderByDir]);
            break;

          case `machineTimePriceRaw`:
            p = _.orderBy(p, [(project) => project.cost.machineTimeGroup.rawPrice], [orderByDir]);
            break;

          case `storagePriceRaw`:
            p = _.orderBy(p, [(project) => project.cost.storageGroup.rawPrice], [orderByDir]);
            break;

          case `priceRaw`:
            p = _.orderBy(p, [(project) => project.cost.rawTotal], [orderByDir]);
            break;

          default:
            break;
        }
        if(orderBy == `name`) {
          p = _.orderBy(p, [(project) => project.name.toLowerCase()], [orderByDir]);
        } else {
          p = _.orderBy(p, [orderBy], [orderByDir]);
        }

      }
      setFilteredProjects(p);
    }
  }, [projectNameFilter, orderBy, orderByDir, projects]);


  const RequestSorter = ({ name, label, className }: { name: string, label: string, className?: string, } ) => {
    const isAsc = orderBy == name && orderByDir == `asc`;
    const isDesc = orderBy == name && orderByDir == `desc`;
    const isNone = !isAsc && !isDesc;

    const setOrder = () => {
      if(isDesc) {
        setOrderByDir(`asc`);
        setOrderBy(name);
      }
      else if(isAsc) {
        setOrderByDir(`desc`);
        setOrderBy(``);
      }
      else {
        setOrderByDir(`desc`);
        setOrderBy(name);
      }
    };

    return (
      <div className={`${className} flex items-center pointer ${isNone ? `` : `b`}` } onClick={() => setOrder()}>
        <div>{label}</div>
        {isDesc && <i className="material-symbols-outlined">arrow_drop_down</i>}
        {isAsc && <i className="material-symbols-outlined">arrow_drop_up</i>}
        {isNone && <i className="material-symbols-outlined">unfold_more</i>}
      </div>
    );
  };

  const onProjectNameInput = () => {
    const debounceTimeout = 700; // miliseconds
    const queryChanged = (event: Event) => {
      const target = event.target as HTMLInputElement;
      setProjectNameFilter(target.value);
    };

    return useMemo(() => _.debounce(queryChanged, debounceTimeout), []);
  };

  const csvUrl = new URL(config.projectsCsvUrl, location.origin);
  csvUrl.searchParams.set(`spending_id`, spendings.state.selectedSpendingId);

  return (
    <stores.Request.Context.Provider value={{ state: request, dispatch: dispatchRequest }}>
      <div className="b--black-075 w-100-l mb4 br3 shadow-3 bg-white">
        <div className="flex items-center justify-between pa3 bb bw1 b--black-075 br3 br--top">
          <div>
            <div className="flex items-center">
              <toolbox.Asset path="images/icn-project-nav.svg" className="pa1 mr2" width="16" height="16"/>
              <div className="b">Projects spending</div>
            </div>
          </div>
          <div className="flex items-center">
            <input type="text" className="form-control mr2" value={projectNameFilter} onInput={onProjectNameInput()} placeholder="Search for a project..."/>
            <a className="btn btn-secondary" href={csvUrl.toString()}>Download .csv</a>
          </div>
        </div>

        <components.Loader.Container
          loadingElement={<components.Loader.LoadingSpinner text={`Loading projects...`}/>}
          loadingFailedElement={<components.Loader.LoadingFailed text={`Loading projects failed`} retry={true}/>}
        >
          <div>
            <div className="bb b--black-075">
              <div className="flex items-center">
                <div className="w-100 pv2 ph3">
                  <div className="flex items-center">
                    <div className="w-40 gray f5">
                      <RequestSorter name="name" label={`Name`} className={`justify-start`}/>
                    </div>
                    <div className="w-20 tr gray f5">
                      <RequestSorter name="workflowCount" label={`Workflows`} className={`justify-end`}/>
                    </div>
                    <div className="w-20 tr gray f5">
                      <RequestSorter name="machineTimePriceRaw" label={`Machines usage`} className={`justify-end`}/>
                    </div>
                    <div className="w-20 tr gray f5">
                      <RequestSorter name="storagePriceRaw" label={`Storage & Egress`} className={`justify-end`}/>
                    </div>
                    <div className="w-20 tr gray f5">
                      <RequestSorter name="priceRaw" label={`Total ($)`} className={`justify-end`}/>
                    </div>
                  </div>
                </div>
              </div>
            </div>
            {projects.length == 0 ? <div className="tc pv3">No projects found</div> : null}
            {projects.length != 0 && filteredProjects.length == 0 ? <div className="tc pv3">No projects match your criteria</div> : null}
            {filteredProjects.map((project, idx) => <ProjectRow key={project.id} idx={idx} project={project}/>)}
          </div>
        </components.Loader.Container>
      </div>
    </stores.Request.Context.Provider>
  );
};

const ProjectRow = ({ project, idx }: { project: types.Spendings.Project, idx: number, }) => {
  const { search } = useLocation();

  return (
    <div className={`b--black-075 ${idx != 0 ? `bt` : ``}`}>
      <div className={`flex items-center hover-bg-washed-gray`}>
        <div className="w-100 pv2 ph3">
          <div className="flex items-center">
            <div className="w-40 b link dark-gray underline-hover pointer">
              <div className="flex items-center">
                <NavLink to={`/projects/${project.name}${search}`}>{project.name}</NavLink>
              </div>
            </div>
            <div className="w-20 tr">
              <div className="flex items-center justify-end">
                {toolbox.Formatter.decimalThousands(project.cost.workflowCount)}
                <components.Trend.UsageTooltip item={project.cost}/>
              </div>
            </div>
            <div className="w-20 tr tnum">
              <div className="flex items-center justify-end">
                {project.cost.machineTimeGroup.price}
                <components.Trend.PriceTooltip item={project.cost.machineTimeGroup}/>
              </div>
            </div>
            <div className="w-20 tr tnum">
              <div className="flex items-center justify-end">
                {project.cost.storageGroup.price}
                <components.Trend.PriceTooltip item={project.cost.storageGroup}/>
              </div>
            </div>
            <div className="w-20 tr tnum">{project.cost.total}</div>
          </div>
        </div>
      </div>
    </div>
  );
};

export const Loader = ({ status, children }: { status: types.RequestStatus, children?: VNode<any>[] | VNode<any>, }) => {
  switch(status) {
    case types.RequestStatus.Loading:
      return <div className="pv2 flex items-center justify-center">
        <toolbox.Asset path="images/spinner-2.svg" width="20" height="20"/>
        <div className="ml1 gray">Loading projects&hellip;</div>
      </div>;
    case types.RequestStatus.Error:
      return <div className="pv2 flex items-center justify-center">
        <div className="ml1 red">Loading projects failed. Please refresh the page.</div>
      </div>;
    case types.RequestStatus.Success:
      return <Fragment>{children}</Fragment>;
  }
};
