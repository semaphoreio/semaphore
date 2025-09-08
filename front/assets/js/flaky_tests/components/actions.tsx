import { FlakyTestItem } from "../types/flaky_test_item";
import { Dispatch, StateUpdater, useContext, useEffect, useLayoutEffect, useReducer, useState } from "preact/hooks";
import * as stores from "../stores";

// eslint-disable-next-line @typescript-eslint/ban-ts-comment
// @ts-ignore
import { Notice } from "js/notice";
import * as toolbox from "js/toolbox";
import * as types from "../types";
import { auto } from "@popperjs/core";
import { Headers } from "../network/request";
import * as marked from "marked";
import DOMPurify from "dompurify";

export const Actions = ({ item }: { item: FlakyTestItem, }) => {
  const config = useContext(stores.Config.Context);
  const [resolved, setResolved] = useState(item.resolved);

  useEffect(() => {
    if (item.resolved === resolved) {
      return;
    }

    //make request
    const action = resolved ? `resolve` : `undo_resolve`;
    const url = new URL(`${config.baseURL}/${item.testId}/${action}`, location.origin);
    fetch(url, {
      credentials: `same-origin`,
      method: `POST`,
      headers: Headers(`application/json`)
    }).then((response) => {
      if (response.status === 200) {
        return response;
      } else {
        throw new Error(`Failed to take action.`);
      }
    })
      .catch(() => {
        Notice.error(`Failed to ${action} test.`);
      });

  }, [resolved]);
  //  dark-brown
  return (
    <div className="flex items-center justify-between">
      <ResolveAction resolved={resolved} setResolved={setResolved}/>
      <TicketAction item={item}/>
    </div>
  );
};


const TicketAction = ({ item }: { item: FlakyTestItem, }) => {
  const hasTicketUrl = item.ticketUrl?.length > 0;
  const tippyContent = hasTicketUrl ? `Ticket has been created for this test` :
    `Create a ticket for this test`;
  const className = `material-symbols-outlined mr1 pointer b`;
  return (
    <toolbox.Popover
      maxWidth={500}
      anchor={
        <span className={`${className} ${hasTicketUrl ? `dark-brown` : `gray hover-black`}`}
          data-tippy-content={tippyContent}>assignment_turned_in</span>
      }
      content={
        ({ setVisible }) =>
          <TicketDetail item={item} whenDone={() => setVisible(false)}/>
      }
      className=""
      placement="bottom-start"
    />
  );
};


interface TicketDetailProps {
  whenDone: () => void;
  item: FlakyTestItem;
}

const TicketDetail = (props: TicketDetailProps) => {
  const { dispatch } = useContext(stores.Request.Context);
  const config = useContext(stores.Config.Context);
  const [request, dispatchRequest] = useReducer(stores.Request.Reducer, {
    url: new URL(`${config.baseURL}/${props.item.testId}/ticket`, location.origin),
    status: types.RequestStatus.Zero,
  });

  const [ticketUrl, setTicketUrl] = useState(props.item.ticketUrl);

  const onSaveTicketUrl = () => {
    dispatchRequest({ type: `SET_METHOD`, value: `POST` });
    dispatchRequest({ type: `SET_BODY`, value: JSON.stringify({ ticket_url: ticketUrl }) });
    dispatchRequest({ type: `FETCH` });
  };

  const unlinkTicketUrl = () => {
    dispatchRequest({ type: `SET_METHOD`, value: `POST` });
    dispatchRequest({ type: `SET_BODY`, value: JSON.stringify({ ticket_url: `` }) });
    dispatchRequest({ type: `FETCH` });
  };

  const onTicketUrlInput = (e: Event) => {
    const { value } = e.target as HTMLInputElement;
    setTicketUrl(value);
  };

  const post = async () => {
    return await fetch(request.url, {
      method: request.method,
      credentials: `same-origin`,
      body: request.body,
      headers: Headers(`application/json`)
    })
      .then((response) => response.json())
      .then(() => {
        dispatch({ type: `FETCH` });
        props.item.ticketUrl = ticketUrl;
        props.whenDone();
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
          post()
            .catch(() => {
              Notice.error(`Failed save changes.`);
            });
          break;
      }
    }
  }, [request.status]);

  const copyToClipboard = (element: HTMLElement) => {
    const copyText = element.innerText;
    navigator.clipboard.writeText(copyText).catch(() => {
      Notice.error(`Failed to copy to clipboard`);
    });
  };

  const createMarkdown = () => {
    const markdown = `## Flaky Test

    **Test**: ${props.item.testName}

    **Last flake**: ${props.item.latestDisruptionTimestamp.toString()}

    **Service**: ${props.item.testGroup}

    **Commit**: ${props.item.latestDisruptionSha()}

    **File**: ${props.item.testFile}`;

    const rawHtml = marked.parse(markdown);
    return DOMPurify.sanitize(rawHtml, {
      ALLOWED_TAGS: [
        `h1`, `h2`, `h3`, `h4`, `h5`, `h6`,
        `p`, `br`, `strong`, `em`, `u`, `strike`,
        `ul`, `ol`, `li`,
        `blockquote`, `code`, `pre`,
        `a`
      ],
      ALLOWED_ATTR: [
        `href`, `title`
      ],
      ALLOWED_SCHEMES: [`http`, `https`, `mailto`],
      FORBID_TAGS: [`script`, `object`, `embed`, `iframe`, `form`, `input`],
      FORBID_ATTR: [`onclick`, `onload`, `onerror`, `onmouseover`, `style`]
    });
  };


  useLayoutEffect(() => {
    document.getElementById(markdownContentId).innerHTML = createMarkdown();
  }, []);

  const markdownContentId = `markdown-content-${props.item.testId}`;
  const copyId = `copy-${props.item.testId}`;

  return (
    <div className="ma2">
      <div className="bg-white br3 tl pa3">
        <div className="flex justify-between">
          <h3 className="mb0">Create a ticket</h3>
          <toolbox.Tooltip
            content={<span id={copyId} className="f6">Copy</span>}
            anchor={<button className="material-symbols-outlined f5 b pointer mr2"
              onClick={() => copyToClipboard(document.getElementById(markdownContentId))}>content_copy</button>}
            placement="top"
          />
        </div>
        <div id={markdownContentId} className="code-block bg-washed-gray ma2" style={{ overflow: auto }}>
        </div>
        <small className="f6 db black-60 mb2">Use provided markdown data to create a ticket in the tool of your
                    choice.</small>
        <div className="measure">
          <label htmlFor="ticket-url" className="f6 b db mb2">Ticket URL</label>
          <input id="ticket-url" className="input-reset ba b--black-20 pa2 mb2 db w-100 br3" type="text"
            value={ticketUrl}
            onInput={onTicketUrlInput}/>
          <small id="ticket-url-desc" className="f6 black-60 db mb2">Please provide ticket URL.</small>
        </div>
        <div className="mt3 button-group">
          <button className="btn btn-danger btn-small" onClick={unlinkTicketUrl}>Unlink</button>
          <button className="btn btn-primary btn-small" onClick={onSaveTicketUrl}>Save</button>
          <button className="btn btn-secondary btn-small" onClick={() => props.whenDone()}>Close</button>
        </div>
      </div>

    </div>
  );
};


const ResolveAction = ({ resolved, setResolved }: { resolved: boolean, setResolved: Dispatch<StateUpdater<boolean>>, }) => {
  const onClick = () => {
    if (resolved) {
      setResolved(!resolved);
      return;
    }

    if (confirm(`Marking this test as resolved will hide it from future results. Are you sure?`)) {
      setResolved(!resolved);
    }
  };

  const className = `material-symbols-outlined mr1 pointer`;
  const tippyContent = resolved ? `This test was marked as resolved` : `Mark this test as resolved`;

  return (
    <span className={`${className} ${resolved ? `green` : `gray hover-black`}`}
      data-tippy-content={tippyContent} onClick={onClick}>done_all</span>
  );
};
