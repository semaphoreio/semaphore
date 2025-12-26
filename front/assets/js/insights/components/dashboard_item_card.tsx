import { DashboardItem } from "../types/dashboard";
import { InsightsType, typeByMetric } from "../types/insights_type";
import * as customCharts from "./custom_charts";
import Tippy from "@tippyjs/react";
import { useState } from "preact/hooks";
import { metricFromNumber } from "../util/metric";

interface Props {
  item: DashboardItem;
  metrics: any;
  deleteHandler: (id: string) => void;
  updateHandler: (id: string, name: string, notes: string) => void;
}

export const DashboardItemCard = ({
  item,
  metrics,
  updateHandler,
  deleteHandler,
}: Props) => {
  const insightType = typeByMetric(item.settings.metric);
  const [name, setName] = useState(item.name);
  const [notes, setNotes] = useState(item.notes);

  if (metrics == null) {
    metrics = [];
  }

  const onInputNameChange = (e: any) => {
    setName(e.target.value as string);
  };

  const onInputDescriptionChange = (e: any) => {
    setNotes(e.target.value as string);
  };

  const onSubmit = (e: any) => {
    e.preventDefault();
    updateHandler(item.id, name, notes);
  };

  const [visible, setVisible] = useState(false);
  const showTippy = () => setVisible(true);
  const hideTippy = () => setVisible(false);

  const decideChart = (insightType: InsightsType, metrics: any) => {
    switch (insightType) {
      case InsightsType.Performance:
        return customCharts.Performance({ metrics, item });
      case InsightsType.Frequency:
        return customCharts.Frequency({
          metrics,
          branchName: item.branchName,
          pipelineFileName: item.pipelineFileName,
        });
      case InsightsType.Reliability:
        return customCharts.Reliability({
          metrics,
          branchName: item.branchName,
          pipelineFileName: item.pipelineFileName,
        });
    }
  };

  return (
    <div className="w-100 mt4">
      <div className="">
        <div className="flex">
          <h2 className="f4 mr2 mb0">
            {item.name} &mdash; {metricFromNumber(item.settings.metric)}
          </h2>

          <Tippy
            trigger="click"
            interactive={true}
            theme="light"
            placement="bottom"
            allowHTML={true}
            visible={visible}
            onClickOutside={hideTippy}
            content={
              <form onSubmit={onSubmit} style="width: 300px;">
                <div className="f5 pa1">
                  <div className="b mb1">Metric name</div>
                  <input
                    value={name}
                    onInput={onInputNameChange}
                    className="x-select-on-click form-control w-90 mb1"
                  />

                  <div className="b mb1">Description</div>
                  <textarea
                    id="notes"
                    style="max-width: 282px;"
                    className="x-select-on-click form-control mb1 w-100"
                    rows={5}
                    placeholder="This metric is used to measure..."
                    value={notes}
                    onInput={onInputDescriptionChange}
                  />
                  <div className="mt3">
                    <button
                      className="btn btn-primary btn-small"
                      onClick={hideTippy}
                      type="submit"
                    >
                      Save
                    </button>
                    <button
                      type="reset"
                      className="btn btn-secondary ml2 btn-small"
                      onClick={hideTippy}
                    >
                      Cancel
                    </button>
                  </div>
                  <div className="mt2 bt b--lighter-gray pt2">
                    <button
                      className="link"
                      onClick={() => {
                        confirmDeletion(deleteHandler, item.id);
                        hideTippy();
                      }}
                      type="reset"
                    >
                      Delete
                    </button>
                  </div>
                </div>
              </form>
            }
          >
            <button
              className="btn btn-secondary btn-tiny"
              style="height: 21px; margin-top: 2px;"
              onClick={visible ? hideTippy : showTippy}
            >
              Edit
            </button>
          </Tippy>
        </div>
      </div>

      <p className="f6 gray mb3 measure-wide">{item.notes}</p>

      <div className="tc bg-white shadow-1 br3 mb2">
        <div className="">{decideChart(insightType, metrics)}</div>
      </div>
    </div>
  );
};

function confirmDeletion(deleteHandler: (id: string) => void, id: string) {
  const result = confirm(`Are you sure you want to delete?`);
  if (result) {
    deleteHandler(id);
  }
}
