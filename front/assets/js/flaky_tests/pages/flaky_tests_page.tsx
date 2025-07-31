import { Fragment } from "preact";
import { useContext, useEffect, useLayoutEffect, useReducer } from "preact/hooks";
import * as stores from "../stores";
import * as types from "../types";
// eslint-disable-next-line @typescript-eslint/ban-ts-comment
// @ts-ignore
import { Notice } from "js/notice";
import * as components from "../components";
import { RequestStatus, Status } from "../types";
import { FetchData } from "../network/request";
import { FlakyTestItem, HistoryItem } from "../types/flaky_test_item";
import tippy from "tippy.js";
import { useSearchParams } from "react-router-dom";


export const FlakyTestsPage = () => {
  const config = useContext(stores.Config.Context);
  const [state, dispatch] = useReducer(stores.FlakyTest.Reducer, {
    ...stores.FlakyTest.EmptyState,
    flakyUrl: config.flakyURL,
  });

  const [request, dispatchRequest] = useReducer(stores.Request.Reducer, {
    url: new URL(config.filtersURL, location.origin),
    status: types.RequestStatus.Zero,
  });

  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  const [searchParams, setSearchParams] = useSearchParams();

  const [filterState, filterDispatch] = useReducer(stores.Filter.Reducer, {
    ...stores.Filter.EmptyState,
    query: searchParams.get(`query`),
  });

  const selectDefaultFilter = () => {
    const filters = filterState.filters;
    const searchQuery = searchParams.get(`query`);
    if(!searchQuery && filters.length > 0) {
      filterDispatch({ type: `SET_CURRENT_FILTER`, value: filters[0] });
      return;
    }

    const filterToSelect = filters.find((filter) => filter.value == searchQuery);
    if(filterToSelect) {
      filterDispatch({ type: `SET_CURRENT_FILTER`, value: filterToSelect });
    } else {
      filterDispatch({ type: `SET_QUERY`, value: searchQuery });
    }
  };

  useLayoutEffect(() => {
    if(request.status == types.RequestStatus.Fetch) {
      dispatchRequest({ type: `SET_STATUS`, value: types.RequestStatus.Loading });
      fetch(request.url)
        .then((response) => response.json())
        .then((json) => {
          const filters = json.map(types.Tests.Filter.fromJSON) as types.Tests.Filter[];
          dispatchRequest({ type: `SET_STATUS`, value: types.RequestStatus.Success });
          filterDispatch({ type: `SET_FILTERS`, value: filters });
          selectDefaultFilter();
        })
        .catch((e) => {
          // eslint-disable-next-line no-console
          console.error(e);
          dispatchRequest({ type: `SET_STATUS`, value: types.RequestStatus.Error });
          Notice.error(`Loading filters failed`);
        });
    }
  }, [request.status]);

  useLayoutEffect(() => {
    dispatchRequest({ type: `FETCH` });
  }, []);


  const setFiltersFor = (url: URL) => {
    const filter = filterState.query?.replace(`*`, `%`);
    if (filter && filter.length > 0) {
      const esc = encodeURIComponent;
      url.searchParams.append(`query`, esc(filter));
    }
  };

  const buildFlakyTestsURL = () => {
    const url = new URL(state.flakyUrl, location.origin);
    setFiltersFor(url);

    if (state.sortOrder.length > 1 && state.sortOrder[0].length > 0) {
      url.searchParams.set(`sort_field`, state.sortOrder[0]);
    }
    if (state.sortOrder.length > 1 && state.sortOrder[1].length > 0) {
      url.searchParams.set(`sort_dir`, state.sortOrder[1]);
    }

    return url;
  };

  const setTotalResults = (count: string | null) => {
    if (count && count.length > 0) {
      dispatch({ type: `SET_FLAKY_COUNT`, value: parseInt(count) });
    }
  };

  const setTotalPages = (count: string | null) => {
    if (count && count.length > 0) {
      dispatch({ type: `SET_TOTAL_PAGES`, value: parseInt(count) });
    }
  };

  useEffect(() => {
    if(request.status != types.RequestStatus.Success)
      return;
    dispatch({ type: `SET_STATUS`, status: Status.Loading });
    dispatch({ type: `SET_FLAKY`, value: [] });

    const fetchFlaky = async () => {
      const url = buildFlakyTestsURL();
      url.searchParams.set(`page`, state.page.toString());

      const flakyRes = await FetchData<FlakyTestItem[]>(url);

      if (flakyRes.status == RequestStatus.Success) {
        setTotalResults(flakyRes.headers.get(`X-TOTAL-RESULTS`));
        setTotalPages(flakyRes.headers.get(`X-TOTAL-PAGES`));

        if (flakyRes.body == null) {
          return dispatch({ type: `SET_STATUS`, status: Status.Error });
        }

        const tests = flakyRes.body.map(f => FlakyTestItem.fromJSON(f));

        dispatch({ type: `SET_FLAKY`, value: tests });
        dispatch({ type: `SET_STATUS`, status: Status.Loaded });
      } else {
        dispatch({ type: `SET_STATUS`, status: Status.Error });
      }
    };

    fetchFlaky().catch(() => Notice.error(`Failed to load flaky tests.`));
  }, [state.flakyUrl, state.sortOrder, filterState.query, request.status]);


  //load more
  useEffect(() => {
    if (state.page === 1) {
      return;
    }

    const fetchFlakyTests = async () => {
      const url = buildFlakyTestsURL();
      url.searchParams.set(`page`, state.page.toString());
      const flakyRes = await FetchData<FlakyTestItem[]>(url);

      if (flakyRes.status == RequestStatus.Success) {
        const flakyTests = flakyRes.body.map(f => FlakyTestItem.fromJSON(f));
        const currentFlakyTests = state.flakyTests;
        const newFlakyTests = [...currentFlakyTests, ...flakyTests];
        dispatch({ type: `SET_FLAKY`, value:  newFlakyTests });
      } else {
        dispatch({ type: `SET_STATUS`, status: Status.Error });
      }
    };

    fetchFlakyTests().catch(() => Notice.error(`Failed to load more flaky tests.`));
  }, [state.page]);


  //fetch top charts
  useEffect( () => {
    if(request.status != types.RequestStatus.Success)
      return;

    dispatch( { type: `SET_FLAKY_HISTORY`, value: [] });
    dispatch( { type: `SET_DISRUPTION_HISTORY`, value: [] });

    dispatch({ type: `SET_FLAKY_CHART_STATUS`, status: Status.Loading });
    dispatch({ type: `SET_DISRUPTION_CHART_STATUS`, status: Status.Loading });


    const fetchAllData = async () => {
      const disruptionHistoryURL = new URL(config.disruptionHistoryURL, location.origin);
      const flakyHistoryURL = new URL(config.flakyHistoryURL, location.origin);
      dispatch({ type: `LOAD_PAGE`, page: 1 });

      setFiltersFor(disruptionHistoryURL);
      setFiltersFor(flakyHistoryURL);

      const fetchDisruptionHistory = FetchData<HistoryItem[]>(disruptionHistoryURL);
      const fetchFlakyHistory = FetchData<HistoryItem[]>(flakyHistoryURL);

      const [ flakyHistoryRes, disruptionHistoryRes] = await Promise.all([ fetchFlakyHistory, fetchDisruptionHistory]);


      if (flakyHistoryRes.status == RequestStatus.Success) {
        dispatch({ type: `SET_FLAKY_HISTORY`, value: flakyHistoryRes.body });
        dispatch({ type: `SET_FLAKY_CHART_STATUS`, status: Status.Loaded });
      } else {
        dispatch({ type: `SET_FLAKY_CHART_STATUS`, status: Status.Error });
        Notice.error(`Failed to load flaky history chart.`);
      }

      if (disruptionHistoryRes.status == RequestStatus.Success) {
        dispatch({ type: `SET_DISRUPTION_HISTORY`, value: disruptionHistoryRes.body });
        dispatch({ type: `SET_DISRUPTION_CHART_STATUS`, status: Status.Loaded });
      } else {
        dispatch({ type: `SET_DISRUPTION_CHART_STATUS`, status: Status.Error });
        Notice.error(`Failed to load disruption history chart.`);
      }

    };
    fetchAllData().catch(() => Notice.error(`Failed to load.`));
  }, [state.flakyUrl, filterState.query, request.status]);

  setTimeout(() => {
    tippy(`[data-tippy-content]`);
  }, 200);


  return (
    <Fragment>
      <stores.Filter.Context.Provider value={{ state: filterState, dispatch: filterDispatch }}>
        <stores.FlakyTest.Context.Provider value={{ state, dispatch, query: filterState.query, setQuery: () => null }}>
          <stores.Request.Context.Provider value={{ state: request, dispatch: dispatchRequest }}>
            <div className="bg-washed-gray mt4 pa3 pa4-l br3 ba b--black-075">
              <HeaderText/>
              <components.SearchFilter/>
              <components.TopFlakyCharts/>
              <components.FlakyTestTable/>
              <components.Pagination/>
            </div>
          </stores.Request.Context.Provider>
        </stores.FlakyTest.Context.Provider>
      </stores.Filter.Context.Provider>
    </Fragment>
  );
};

export const HeaderText = () => {
  return (
    <div className="mb4 flex items-center justify-between">
      <p className="measure mb0">
        Examine the performance, and spot potential problems and optimization opportunities across your test suite
      </p>
    </div>
  );
};
