import { Fragment, VNode } from "preact";
import * as stores from "../stores";
import * as toolbox from "js/toolbox";
import * as types from "../types";
import { useContext } from "preact/hooks";

interface Props {
  loadingElement: VNode<any>;
  loadingFailedElement: VNode<any>;
  children?: VNode<any>[] | VNode<any>;
}

export const Container = (props: Props) => {
  const { state: request } = useContext(stores.Request.Context);
  switch (request.status) {
    case types.RequestStatus.Error:
      return props.loadingFailedElement;
    case types.RequestStatus.Success:
      return <Fragment>{props.children}</Fragment>;
    default:
      return props.loadingElement;
  }
};

export const LoadingSpinner = ({ text }: { text: string }) => {
  return (
    <div className="pv2 flex items-center justify-center">
      <toolbox.Asset path="images/spinner-2.svg" width="20" height="20"/>
      <div className="ml1 gray">{text}</div>
    </div>
  );
};

export const LoadingFailed = ({ text, retry }: { text: string, retry?: boolean }) => {
  const { dispatch: dispatchRequest } = useContext(stores.Request.Context);
  if (retry) {
    return (
      <div className="pv2 flex flex-column items-center justify-center">
        <div className="mt1 red">{text}</div>
        <button className="mt2 btn btn-secondary btn-tiny" onClick={() => dispatchRequest({ type: `FETCH` })}>
          Retry
        </button>
      </div>
    );
  } else {
    return (
      <div className="pv2 flex items-center justify-center">
        <div className="mt1 red">{text}</div>
      </div>
    );
  }
};
