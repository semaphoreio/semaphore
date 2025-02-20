import { h } from "preact";
import { useContext } from "preact/hooks";
import * as stores from "../stores";
import * as toolbox from "js/toolbox";
import { ActivityItem } from "./activity_item";

export const ActivityMonitor = () => {
  const {
    state: { waitingItems, runningItems, lobbyItems, invisibleJobsCount },
  } = useContext(stores.Activity.Context);

  const isEmpty =
    waitingItems.length === 0 &&
    runningItems.length === 0 &&
    lobbyItems.length === 0 &&
    invisibleJobsCount === 0;

  return (
    <div>
      <h3 className="b mb2 pt4 ">Activity</h3>
      <div className="mb3">
        <p className="mb0">
          Current runs across all projects, consuming machine resources.
        </p>
      </div>
      <InvisibleItems/>
      <LobbyItems/>
      {waitingItems.map((item, idx) => (
        <ActivityItem item={item} key={idx}/>
      ))}
      {runningItems.map((item, idx) => (
        <ActivityItem item={item} key={idx}/>
      ))}
      {isEmpty && <EmptyState/>}
    </div>
  );
};

const EmptyState = () => {
  return (
    <div className="tc mv5 mv6-ns">
      <toolbox.Asset path="images/ill-curious-girl.svg" class="mt1"/>
      <h4 className="f4 mt2 mb0">It&apos;s quiet your projects right now</h4>
      <p className="mb0 measure center">
        Push to repository to trigger a workflow
      </p>
    </div>
  );
};

const LobbyItems = () => {
  const {
    state: { lobbyItems },
  } = useContext(stores.Activity.Context);

  if (lobbyItems.length === 0) return;

  return (
    <details className="mt4 mb3">
      <summary className="pointer">
        Lobby ({lobbyItems.length}) · Pipelines waiting for previous pipelines
        in their branch, pull request and delivery queue
      </summary>
      {lobbyItems.map((item, idx) => (
        <ActivityItem item={item} key={idx} inLobby={true}/>
      ))}
    </details>
  );
};

const InvisibleItems = () => {
  const {
    state: { invisibleJobsCount },
  } = useContext(stores.Activity.Context);

  if (invisibleJobsCount === 0) return;

  return (
    <div className="bg-white shadow-1 mv3 ph3 pv2 br3">
      <div className="flex items-center">
        <div className="flex-shrink-0 mr2 dn db-l">
          <toolbox.Asset path="images/icn-lock.svg" class="mt1"/>
        </div>
        <div className="flex-auto f5">
          + {invisibleJobsCount}
          {` `}
          {toolbox.Pluralize(invisibleJobsCount, `job`, `jobs`)} running in
          other projects you can’t access
        </div>
      </div>
    </div>
  );
};
