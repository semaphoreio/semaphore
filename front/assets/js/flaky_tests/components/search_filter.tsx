import { useContext, useEffect, useReducer, useState } from "preact/hooks";
import { Fragment } from "preact";
import * as stores from "../stores";
import * as types from "../types";
import * as components from "../components";
// eslint-disable-next-line @typescript-eslint/ban-ts-comment
// @ts-ignore
import { Notice } from "js/notice";
import * as toolbox from "js/toolbox";
import { Headers } from "../network/request";
import { useSearchParams } from "react-router-dom";
import { Notification } from "./notification";

export const SearchFilter = () => {
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  const [searchParams, setSearchParams] = useSearchParams();
  const { state, dispatch } = useContext(stores.Filter.Context);
  const [query, setQuery] = useState(``);

  const setSearchFilter = () => {
    dispatch({ type: `SET_QUERY`, value: query });
  };

  useEffect(() => {
    if (state.currentFilter) {
      setQuery(state.currentFilter.value);
      dispatch({ type: `SET_QUERY`, value: state.currentFilter.value });
    }
  }, [state.currentFilter]);

  useEffect(() => {
    if (state.query) {
      setQuery(state.query);
      setSearchParams({ query: state.query });
    }
  }, [state.query]);

  const discardChanges = () => {
    setQuery(state.currentFilter.value);
    dispatch({ type: `SET_QUERY`, value: state.currentFilter.value });
  };

  return (
    <Fragment>
      {state.currentFilter && <CurrentFilter query={query}/>}
      <div className="flex items-stretch items-center mv3 justify-between">
        <div className="w-100 flex z-1">
          <toolbox.Popover
            anchor={
              <div className="pointer flex items-center btn-secondary btn br3 br--left" aria-expanded="false">
                <div className="flex">
                  <span className="material-symbols-outlined mr1">filter_list</span>
                  <span>Filters</span>
                </div>
              </div>
            }
            content={({ setVisible }) => <FilterList whenDone={() => setVisible(false)}/>}
            className=""
            placement="bottom-start"
          />
          <components.ComposeBox query={query} onQueryChange={setQuery} onSubmit={setSearchFilter}/>

          <toolbox.Tooltip
            anchor={
              <toolbox.Popover
                anchor={
                  <div className={`btn btn-secondary ph2 flex items-center ${state.currentFilter ? `br0` : `br3 br--right`}`}>
                    <span className="material-symbols-outlined">bookmark_add</span>
                  </div>
                }
                content={({ setVisible }) => <NewFilter whenDone={() => setVisible(false)}/>}
                placement="bottom-end"
              />
            }
            content={<span>Create a new filter</span>}
            placement="top-start"
          />

          {state.currentFilter && (
            <toolbox.Tooltip
              anchor={
                <button
                  className={`btn btn-secondary flex items-center ph2 br3 br--right`}
                  disabled={state.currentFilter && state.currentFilter.value === query}
                  onClick={discardChanges}
                >
                  <span className="material-symbols-outlined">cancel</span>
                </button>
              }
              content={<span>Dismiss changes</span>}
              placement="top-start"
            />
          )}
        </div>
      </div>
    </Fragment>
  );
};

interface NewFilterProps {
  whenDone: () => void;
}

const NewFilter = (props: NewFilterProps) => {
  const config = useContext(stores.Config.Context);
  const [request, dispatchRequest] = useReducer(stores.Request.Reducer, {
    url: new URL(config.updateFilterURL, location.origin),
    status: types.RequestStatus.Zero,
  });

  const { state, dispatch } = useContext(stores.Filter.Context);
  const [filterName, setFilterName] = useState(``);

  const onCreateFilter = () => {
    dispatchRequest({ type: `SET_METHOD`, value: `POST` });
    dispatchRequest({ type: `SET_BODY`, value: JSON.stringify({ filter: { name: filterName, value: state.query } }) });
    dispatchRequest({ type: `FETCH` });
  };

  const createFilter = async () => {
    return await fetch(request.url, {
      method: request.method,
      credentials: `same-origin`,
      body: request.body,
      headers: Headers(`application/json`),
    })
      .then((response) => response.json())
      .then((json) => {
        const filter = types.Tests.Filter.fromJSON(json);
        dispatch({ type: `CREATE_FILTER`, value: filter });
        setFilterName(``);
        props.whenDone();
        Notice.notice(`Filter "${filterName}" created`);
      })
      .catch((e) => {
        // eslint-disable-next-line no-console
        console.error(e);
        dispatchRequest({ type: `SET_STATUS`, value: types.RequestStatus.Error });
      });
  };

  useEffect(() => {
    if (request.status == types.RequestStatus.Fetch) {
      dispatchRequest({ type: `SET_STATUS`, value: types.RequestStatus.Loading });
      switch (request.method) {
        case `POST`:
          createFilter().catch(() => {
            Notice.error(`Failed saving filter`);
          });
          break;
      }
    }
  }, [request.status]);

  const onNameInput = (e: Event) => {
    const { value } = e.target as HTMLInputElement;
    setFilterName(value);
  };

  return (
    <Fragment>
      <div className="b mb1">Filter name</div>
      <input type="text" className="form-control w-100 mb1" value={filterName} onInput={onNameInput}/>
      <div className="mt3 button-group">
        <button className="btn btn-primary btn-small" onClick={onCreateFilter}>
          Save
        </button>
        <button className="btn btn-secondary btn-small" onClick={() => props.whenDone()}>
          Cancel
        </button>
      </div>
    </Fragment>
  );
};

interface FilterListProps {
  whenDone: () => void;
}

const FilterList = ({ whenDone }: FilterListProps) => {
  const { state, dispatch } = useContext(stores.Filter.Context);

  const selectFilter = (filter: types.Tests.Filter) => {
    dispatch({ type: `SET_CURRENT_FILTER`, value: filter });
    whenDone();
  };

  const SearchFilterItem = ({ filter }: { filter: types.Tests.Filter }) => {
    const isSelected = state.currentFilter && filter.id == state.currentFilter.id;
    const normalClassNames = `bg-white hover-bg-washed-gray pointer pv2 ph3 bb b--black-075`;
    const selectedClassNames = `bg-dark-gray white pointer pv2 ph3 bb b--black-075`;

    const valueNormalClassNames = `f6 gray mb0 truncate measure tl`;
    const valueSelectedClassNames = `f6 light-gray mb0 truncate measure tl`;

    const rootClassNames = isSelected ? selectedClassNames : normalClassNames;
    const valueClassNames = isSelected ? valueSelectedClassNames : valueNormalClassNames;

    return (
      <div className={rootClassNames} onClick={() => selectFilter(filter)} style="height: 57px;">
        <p className="b f5 mb0 tl">{filter.name}</p>
        <p className={valueClassNames}>{filter.value}</p>
      </div>
    );
  };

  return (
    <Fragment>
      {state.filters.length > 0 && state.filters.map((f) => <SearchFilterItem filter={f} key={f.id}/>)}
      {state.filters.length == 0 && (
        <div className={`bg-white hover-bg-washed-gray pv2 ph3 bb b--black-075`}>
          <p className="f6 gray mb0 truncate measure tl">No filters present</p>
        </div>
      )}
    </Fragment>
  );
};

const CurrentFilter = ({ query }: { query: string }) => {
  const { state, dispatch } = useContext(stores.Filter.Context);
  const [editMode, setEditMode] = useState(false);
  const [filterName, setFilterName] = useState(``);

  const config = useContext(stores.Config.Context);
  const [request, dispatchRequest] = useReducer(stores.Request.Reducer, {
    url: new URL(config.updateFilterURL, location.origin),
    status: types.RequestStatus.Zero,
  });

  const [notificationSignal, setNotificationSignal] = useState(false);

  useEffect(() => {
    if (state.currentFilter?.name) {
      setFilterName(state.currentFilter.name);
    }
  }, [state.currentFilter]);

  const abortChanges = () => {
    setFilterName(state.currentFilter.name);
    setEditMode(false);
  };

  const onNameInput = (e: Event) => {
    const { value } = e.target as HTMLInputElement;
    setFilterName(value);
  };

  const onSaveFilterName = () => {
    dispatchRequest({ type: `SET_METHOD`, value: `PUT` });
    dispatchRequest({ type: `SET_PARAM`, name: `filter_id`, value: state.currentFilter.id });
    dispatchRequest({
      type: `SET_BODY`,
      value: JSON.stringify({ filter: { name: filterName, value: state.currentFilter.value } }),
    });
    dispatchRequest({ type: `FETCH` });
  };

  const onSaveFilterQuery = () => {
    dispatchRequest({ type: `SET_METHOD`, value: `PUT` });
    dispatchRequest({ type: `SET_PARAM`, name: `filter_id`, value: state.currentFilter.id });
    dispatchRequest({ type: `SET_BODY`, value: JSON.stringify({ filter: { name: filterName, value: state.query } }) });
    dispatchRequest({ type: `FETCH` });
  };

  const onDeleteFilter = () => {
    dispatchRequest({ type: `SET_METHOD`, value: `DELETE` });
    dispatchRequest({ type: `SET_PARAM`, name: `filter_id`, value: state.currentFilter.id });
    dispatchRequest({ type: `FETCH` });
  };

  const canUpdateQuery = query !== state.currentFilter.value;

  const updateFilter = async () => {
    return await fetch(request.url, {
      method: request.method,
      credentials: `same-origin`,
      body: request.body,
      headers: Headers(`application/json`),
    })
      .then((response) => response.json())
      .then((json) => {
        const filter = types.Tests.Filter.fromJSON(json.filter);
        dispatch({ type: `UPDATE_FILTER`, value: filter });
        Notice.notice(`Filter saved`);
        setEditMode(false);
      })
      .catch((e) => {
        // eslint-disable-next-line no-console
        console.error(e);
        dispatchRequest({ type: `SET_STATUS`, value: types.RequestStatus.Error });
      });
  };

  const deleteFilter = async () => {
    return await fetch(request.url, {
      method: request.method,
      credentials: `same-origin`,
      body: request.body,
      headers: Headers(`application/json`),
    })
      .then(() => {
        dispatch({ type: `DELETE_FILTER`, value: state.currentFilter.id });
        Notice.notice(`Filter deleted`);
        setEditMode(false);
      })
      .catch((e) => {
        // eslint-disable-next-line no-console
        console.error(e);
        dispatchRequest({ type: `SET_STATUS`, value: types.RequestStatus.Error });
      });
  };

  useEffect(() => {
    if (request.status == types.RequestStatus.Fetch) {
      dispatchRequest({ type: `SET_STATUS`, value: types.RequestStatus.Loading });
      switch (request.method) {
        case `PUT`:
          updateFilter().catch(() => {
            Notice.error(`Failed saving filter`);
          });
          break;
        case `DELETE`:
          deleteFilter().catch(() => {
            Notice.error(`Failed deleting filter`);
          });
          break;
      }
    }
  }, [request.status]);

  const filterReadOnly = state.currentFilter.readOnly;

  return (
    <div className="flex items-center items-stretch">
      {editMode && (
        <Fragment>
          <input
            type="text"
            className="mb0 form-control form-control-small br--left"
            value={filterName}
            onInput={onNameInput}
            style="width: 400px;"
          ></input>

          <div className="flex">
            <toolbox.Tooltip
              content={<span className="f6">Save filter name</span>}
              anchor={
                <button className="material-symbols-outlined f5 b btn pointer pa1 btn-secondary br0" onClick={onSaveFilterName}>
                  check_circle
                </button>
              }
              placement="top"
            />
            <toolbox.Tooltip
              content={<span className="f6">Dismiss changes</span>}
              anchor={
                <button className="material-symbols-outlined f5 b btn pointer pa1 btn-secondary br3 br--right" onClick={abortChanges}>
                  cancel
                </button>
              }
              placement="top"
            />
          </div>
        </Fragment>
      )}
      {!editMode && (
        <Fragment>
          <p className="truncate mr2 mb0 b f3">{filterName}</p>
          <div className="flex">
            <toolbox.Tooltip
              content={
                <Fragment>
                  {!filterReadOnly && <span className="f6">Change filter name</span>}
                  {filterReadOnly && <span className="f6">This is a default filter and it cannot be modified.</span>}
                </Fragment>
              }
              anchor={
                <button
                  disabled={filterReadOnly}
                  className="material-symbols-outlined f5 b btn pointer pa1 btn-secondary br3 br--left"
                  onClick={() => setEditMode(true)}
                >
                  edit
                </button>
              }
              placement="top"
            />
            <toolbox.Tooltip
              content={
                <Fragment>
                  {!filterReadOnly && <span className="f6">Save current search</span>}
                  {filterReadOnly && <span className="f6">This is a default filter and it cannot be modified.</span>}
                </Fragment>
              }
              anchor={
                <button
                  className="material-symbols-outlined f5 b btn pointer pa1 btn-secondary br0"
                  disabled={!canUpdateQuery || filterReadOnly}
                  onClick={onSaveFilterQuery}
                >
                  save
                </button>
              }
              placement="top"
            />
            <toolbox.Tooltip
              content={
                <Fragment>
                  {!filterReadOnly && <span className="f6">Delete this filter</span>}
                  {filterReadOnly && <span className="f6">This is a default filter and it cannot be modified.</span>}
                </Fragment>
              }
              anchor={
                <button
                  disabled={filterReadOnly}
                  className="material-symbols-outlined f5 b btn pointer pa1 btn-secondary br3 br--right"
                  onClick={onDeleteFilter}
                >
                  delete
                </button>
              }
              placement="top"
            />
          </div>
          <div className="pl1" style="z-index: 5;">
            <toolbox.Tooltip
              anchor={
                <toolbox.Popover
                  anchor={
                    notificationSignal ? (
                      <button className="material-symbols-outlined f5 b btn pointer pa1 btn-primary ml2">notifications_active</button>
                    ) : (
                      <button className="material-symbols-outlined f5 b btn pointer pa1 btn-secondary ml2">notifications</button>
                    )
                  }
                  content={({ setVisible }) => (
                    <Notification whenDone={() => setVisible(false)} signal={notificationSignal} setSignal={setNotificationSignal}/>
                  )}
                  placement="bottom"
                />
              }
              content={<span className="f6 z-999">Notification settings</span>}
              placement="right"
            />
          </div>
        </Fragment>
      )}
    </div>
  );
};
