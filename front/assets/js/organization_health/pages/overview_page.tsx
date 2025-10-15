import { Fragment } from "preact";
import { useContext, useEffect, useLayoutEffect, useReducer, useState } from "preact/hooks";
import * as stores from "../stores";
import * as types from "../types";
import * as toolbox from "js/toolbox";
import * as components from "../components";
import _ from "lodash";
// eslint-disable-next-line @typescript-eslint/ban-ts-comment
// @ts-ignore
import { Notice } from "js/notice";
import { BranchType } from "../types";


export const OverviewPage = () => {
  const config = useContext(stores.Config.Context);
  const [state, dispatch] = useReducer(stores.OrganizationHealth.Reducer, {
    ...stores.OrganizationHealth.EmptyState,
    url: config.organizationHealthUrl,
  });

  const [items, setItems] = useState<types.ProjectHealth[]>([]);

  useLayoutEffect(() => {
    const url = new URL(config.organizationHealthUrl, location.origin);
    // add search params here
    if (state.selectedDateIndex) {
      //this restricts which to range that are available, so the client cant request custom date ranges
      url.searchParams.append(`date_index`, state.selectedDateIndex.toString(10));
    }

    dispatch({ type: `SET_STATUS`, status: types.Status.Loading });
    dispatch({ type: `SET_ORG_HEALTH`, orgHealth: [] });
    fetch(url, { credentials: `same-origin` })
      .then((response) => response.json())
      .then((json) => {
        const healths = json.healths.map(types.ProjectHealth.fromJSON) as types.ProjectHealth[];
        dispatch({ type: `SET_ORG_HEALTH`, orgHealth: healths });
        dispatch({ type: `SET_STATUS`, status: types.Status.Loaded });
      }).catch(() => {
        dispatch({ type: `SET_STATUS`, status: types.Status.Error });
        Notice.error(`Failed to load organization health data.`);
      });

  }, [state.selectedDateIndex]);

  useEffect(() => {
    if(!state.orgHealth) return;

    const filteredItems = _.chain(state.orgHealth)
      .filter((health) => health.name.toLowerCase().includes(state.filters.projectName.toLowerCase()))
      .map((health) => {

        if (state.filters.branchType === BranchType.Default) {
          health.displayDefaultBranch();
        } else {
          health.displayAllBranches();
        }

        if (state.filters.buildStatus === types.BuildStatus.Success) {
          health.displayGreenBuilds();
        } else {
          health.displayAllBuilds();
        }
        return health;
      })
      .value();

    setItems(filteredItems);

  }, [state.orgHealth, state.filters]);


  return (
    <stores.OrganizationHealth.Context.Provider value={{ state, dispatch }}>
      <div className="bg-washed-gray ba b--black-075 pa3 mt3 br3">
        <div className="flex items-start justify-between mb3">
          <div className="mb0">
            <p className="measure mb1">Examine the performance, spot potential problems and find optimization
                        opportunities across your organization.</p>
          </div>
        </div>
        <Header/>

        <ProjectHealthList items={items}/>
      </div>
    </stores.OrganizationHealth.Context.Provider>
  );
};

export const Header = () => {
  const config = useContext(stores.Config.Context);
  const store = useContext(stores.OrganizationHealth.Context);
  const state = store.state;

  const setBranchSelectFromEvent = (event: Event) => {
    const target = event.target as HTMLSelectElement;
    const type = target.value as types.BranchType;
    store.dispatch({ type: `SET_BRANCH_TYPE`, branchType: type });
  };

  const setBuildSelectFromEvent = (event: Event) => {
    const target = event.target as HTMLSelectElement;
    const status = target.value as types.BuildStatus;
    store.dispatch({ type: `SET_BUILD_STATUS`, buildStatus: status });
  };

  const handleProjectFilterFromEvent = (event: Event) => {
    const target = event.target as HTMLSelectElement;
    const projectName = target.value;
    store.dispatch({ type: `SET_PROJECT_NAME`, value: projectName });
  };

  const debouncedProjectNameFromEvent = _.debounce(handleProjectFilterFromEvent, 300);


  const handleExportToCsv = () => {
    const csvContent = [
      [`Project`, `Performance`, `Reliability`, `Frequency`, `Last Successful Run`], // header row
      ...state.orgHealth.map((health) => {
        const frequencyDays = config.dateRange[state.selectedDateIndex].days;
        return [health.name, health.performance, health.reliability, health.frequency(frequencyDays), health.lastRun];
      }),
    ].map((row) => row.join(`,`))
      .join(`\n`);

    const blob = new Blob([csvContent], { type: `text/csv;charset=utf-8;` });
    const downloadLink = document.createElement(`a`);
    downloadLink.href = URL.createObjectURL(blob);
    downloadLink.download = `organization_health.csv`;
    downloadLink.click();
  };


  return (
    <div>
      <div className="flex items-center mv1 w-100 justify-between">
        <div className="flex items-center mv1">
          <components.DateSelect items={config.dateRange}/>
          <select
            className="db form-control mr2"
            value={state.filters.branchType}
            onChange={setBranchSelectFromEvent}
          >
            <option value="all">All branches</option>
            <option value="default">Default branch only</option>
          </select>
          <select
            className="db form-control mr2"
            value={state.filters.buildStatus}
            onChange={setBuildSelectFromEvent}
          >
            <option value="all">All builds</option>
            <option value="success">Green builds only</option>
          </select>
          <div className="branch-jumpto">
            <input
              type="text"
              className="form-control mr2"
              placeholder="Find by project name…"
              value={state.filters.projectName}
              onInput={debouncedProjectNameFromEvent}
              aria-expanded="false"
            ></input>
          </div>

        </div>
        <button
          className="btn btn-secondary"
          onClick={handleExportToCsv}
          disabled={state.orgHealth.length === 0}
        >Download .csv</button>
      </div>

    </div>
  );
};


export const ProjectHealthList = ({ items }: { items: types.ProjectHealth[] }) => {
  const store = useContext(stores.OrganizationHealth.Context);
  const state = store.state;

  const isLoading = state.status == types.Status.Loading;
  const displayNoData = items.length === 0 && state.filters.projectName.length === 0;
  const displayNoResults = items.length === 0 && state.filters.projectName.length > 0;
  return (
    <div className="bb b--black-075 w-100-l mb4 br3 shadow-1 bg-white">
      <Items items={items}/>
      {isLoading && <components.LoadingIndicator/>}
      {!isLoading && displayNoData && <NoDataAvailable/>}
      {displayNoResults && <NoResults/>}
    </div>
  );
};

export const Items = ({ items }: { items: types.ProjectHealth[] }) => {
  const [sortedItems, setSortedItems] = useState([...items]);
  const [sortOrder, setSortOrder] = useState([`performance`, `desc`]);

  useLayoutEffect(() => {
    const [sortColumn, sortDirection] = sortOrder;
    const sortedItems = [...items].sort((a, b) => {
      switch (sortColumn) {
        case `last_run`:
          return sortDirection === `asc` ? a.rawLastRunAt.getTime() - b.rawLastRunAt.getTime() :
            b.rawLastRunAt.getTime() - a.rawLastRunAt.getTime();
        case `frequency`:
          return sortDirection === `asc` ? a.rawFrequency - b.rawFrequency :
            b.rawFrequency - a.rawFrequency;
        case `reliability`:
          return sortDirection === `asc` ? a.rawReliability - b.rawReliability :
            b.rawReliability - a.rawReliability;
        case `performance`:
          return sortDirection === `asc` ? a.rawPerformance - b.rawPerformance :
            b.rawPerformance - a.rawPerformance;
        default:
          return 0;
      }
    });

    setSortedItems(sortedItems);
  }, [sortOrder, items]);

  const lastItemIndex = sortedItems.length - 1;

  const columnFilter = (displayName: string, name: string, className: string) => {
    const isAsc = sortOrder && sortOrder[0] == name && sortOrder[1] == `asc`;
    const isDesc = sortOrder && sortOrder[0] == name && sortOrder[1] == `desc`;
    const isNone = !isAsc && !isDesc;
    let order = [``, ``];

    // rotate sorting order
    if (isDesc) {
      order = [``, ``];
    } else if(isAsc) {
      order = [name, `desc`];
    } else {
      order = [name, `asc`];
    }

    return (
      <div
        onClick={() => setSortOrder(order)}
        className="pointer"
        style="user-select: none;"
      >
        <div className={`flex ${className}`}>
          <span className="b">{displayName}</span>
          {isAsc && <i className="material-symbols-outlined">expand_more</i>}
          {isDesc && <i className="material-symbols-outlined">expand_less</i>}
          {isNone && <i className="material-symbols-outlined">unfold_more</i>}
        </div>
      </div>
    );
  };

  return (
    <Fragment>
      <div className="bb b--black-075">
        <div className="ph3 pv2">
          <div className="flex items-center-ns">
            <div className="w-100">
              <div className="flex-ns items-center">
                <div className="w-40-ns b">
                  <div>
                    <div className="flex items-center">
                      <toolbox.Asset
                        path="images/icn-project-nav.svg"
                        className="pa1 mr2"
                        width="16"
                        height="16"
                      />
                      <div className="b">Project</div>
                    </div>
                  </div>

                </div>
                <div className="w-20-ns tr-ns tnum">
                  {columnFilter(`Performance`, `performance`, `justify-end`)}
                </div>
                <div className="w-20-ns tr-ns tnum">
                  {columnFilter(`Reliability`, `reliability`, `justify-end`)}
                </div>
                <div className="w-20-ns tr-ns tnum">
                  {columnFilter(`Frequency`, `frequency`, `justify-end`)}
                </div>
                <div className="w-20-ns tr-ns tnum">
                  {columnFilter(`Last Run`, `last_run`, `justify-end`)}
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
      {sortedItems.map((item, index) =>
        <ProjectHealthItem
          key={item.projectId}
          item={item}
          isLast={index === lastItemIndex}
        />,
      )}
    </Fragment>
  );
};


export const ProjectHealthItem = ({ item, isLast }: { item: types.ProjectHealth, isLast: boolean }) => {
  const config = useContext(stores.Config.Context);
  const store = useContext(stores.OrganizationHealth.Context);
  const state = store.state;
  const frequencyDays = config.dateRange[state.selectedDateIndex].days;

  const bottomLine = !isLast;
  return (
    <Fragment>
      <div className={`b--black-075 ` + (bottomLine ? `bb` : ``)}>
        <div className="ph3 pv2">
          <div className="flex items-center-ns">
            <div className="w-100">
              <div className="flex-ns items-center">
                <div className="w-40-ns">
                  <a href={item.url} className="pointer underline-hover link db dark-gray ml1">{item.name}</a>
                </div>
                <div className="w-20-ns tr-ns tnum pr2">{item.performance}</div>
                <div className="w-20-ns tr-ns tnum pr2">{item.reliability}</div>
                <div className="w-20-ns tr-ns tnum pr2">{item.frequency(frequencyDays)}</div>
                <div className="w-20-ns tr-ns tnum pr2">{item.lastRun}</div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Fragment>
  );
};

export const NoResults = () => {
  return Warning(`Oops! It seems there are no projects matching your search criteria. Please consider broadening your search parameters.`);
};

export const NoDataAvailable = () => {
  return Warning(`No data available.`);
};

export const Warning = (text: string) => {
  return (
    <div className="flex flex-column items-center justify-center pv4 br3 ph3">
      <div><span className="material-symbols-outlined mr2 v-top">warning</span>
        <span>{text}</span>
      </div>
    </div>
  );
};
