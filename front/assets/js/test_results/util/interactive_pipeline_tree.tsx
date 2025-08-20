import { Component } from "preact";
import Popper, { createPopper } from "@popperjs/core";
import { useContext, useEffect, useLayoutEffect, useRef, useState } from "preact/hooks";
import { UrlStore } from "../stores";
import Icon from "./icon";

interface Props {
  loader: { init: (any: any) => void, };
  pollUrl: string;
  pipelineId: string;
  pipelineName: string;
  pipelineStatus: string;
  workflowSummaryURL: string;
}

export const InteractivePipelineTree = (props: Props) => {
  const api = useContext(UrlStore.Context);
  const [expanded, setExpanded] = useState(false);
  const anchorEl = useRef(null);
  const tooltipEl = useRef(null);
  const tooltipArrowEl = useRef(null);
  const [tooltip, setTooltip] = useState<Popper.Instance>(undefined);
  const [pipelineName, setPipelineName] = useState(props.pipelineName);
  const [pipelineStatus, setPipelineStatus] = useState(props.pipelineStatus);
  const [selectedPipelineId, setSelectedPipelineId] = useState(props.pipelineId);

  useLayoutEffect(() => {
    props.loader.init({
      onWorkflowTreeItemClick: function(event: MouseEvent) {
        const target = event.currentTarget as HTMLElement;
        const pipelineId = target.getAttribute(`data-pipeline-id`);
        this.selectPipeline(pipelineId);
        setSelectedPipelineId(pipelineId);
        fetchPipelineDetails(pipelineId);
      }
    });

    const instance = createPopper(anchorEl.current as HTMLElement, tooltipEl.current as HTMLElement, {
      placement: `bottom-start`,
      modifiers: [
        { name: `arrow`,
          options: {
            element: tooltipArrowEl.current,
          },
          data:{
            y: 12,
          }
        },
        {
          name: `offset`,
          options: {
            offset: [0, 20],
          },
        },
      ]
    });
    setTooltip(instance);
  }, []);

  useEffect(() => {
    const check = (ev: MouseEvent) => {
      if((tooltipEl.current as HTMLElement).contains(ev.target as HTMLElement)) {
        return;
      } else {
        if(expanded) {
          setExpanded(false);
        }
      }
    };

    window.addEventListener(`click`, check);
    return () => window.removeEventListener(`click`, check);
  }, [tooltipEl.current, expanded]);

  useEffect(() => {
    if(tooltip) {
      tooltip.forceUpdate();
    }
  }, [expanded]);

  const fetchPipelineDetails = (pipelineId: string) => {
    const pipelineDetailsUrl = `${props.workflowSummaryURL}/${pipelineId}`;
    fetch(pipelineDetailsUrl, { credentials: `same-origin` })
      .then((response) => response.json())
      .then((data) => {
        api.dispatch({ type: `SET_URL`, url: data.artifact_url });
        setPipelineName(data.name as string);
        setPipelineStatus(data.icon as string);
        setExpanded(false);
      })
      .catch(() => {
        return;
      });
  };

  return (
    <div className="bb b--lighter-gray pb3 ph2">
      <div className="dib pointer ba b--transparent hover-bg-washed-gray hover-b--black-15 pa2 na2 br3 bg-animate" ref={anchorEl} onClick={() => setExpanded(!expanded)}>
        <div className="inline-flex items-center">
          <div className="flex-auto" dangerouslySetInnerHTML={{ __html: pipelineStatus }}>
          </div>
          <span className="b">{pipelineName}</span>
        </div>
        <img className="ml1" src="/projects/assets/images/icn-arrow-down.svg"/>
      </div>

      <div className="pv2 ph3 f5 bg-white br2 pa2 tooltip" ref={tooltipEl} style={{ "zIndex": 200, boxShadow: ``, display: expanded ? `` : `none` }}>
        <div className="tooltip-arrow" data-popper-arrow ref={tooltipArrowEl}></div>
        <div className="b mt1 mb2">Choose pipeline</div>
        <Pipelines url={props.pollUrl} pipelineId={selectedPipelineId}/>
      </div>
    </div>
  );
};

interface PplProps {
  url: string;
  pipelineId: string;
}

class Pipelines extends Component<PplProps> {
  // updates are comming from external source(Pollman)
  shouldComponentUpdate() {
    return false;
  }

  render (props: PplProps) {
    return (
      <div className="lh-solid">
        <div data-poll-background data-poll-state="poll" data-poll-href={props.url} data-poll-param-pipeline_id={props.pipelineId} className="flex items-center gray">
          <Icon class="mr2" width="22" height="22" path="images/spinner-2.svg"/>
          Fetching pipelines&hellip;
        </div>
      </div>
    );
  }
}
