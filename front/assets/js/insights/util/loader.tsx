import { Fragment, VNode } from "preact";
import * as Loading from "../stores/loading";
import { Asset } from "js/toolbox";

export const Loader = ({ loadingState, children }: { loadingState: Loading.State, children?: VNode<any>[] | VNode<any> }) => {
  const {
    loading,
    errors,
  } = loadingState;

  const containerStyle = { };

  if (errors.length > 0) {
    return (
      <Fragment>
        <div className="flex items-center justify-center br3" style={containerStyle}>
          <div className="flex items-center">
            <p className="ml1 tc gray">
              <span className="red">Loading data failed.</span>
              <br/>
              <span>Please refresh the page to try again.</span>
            </p>
          </div>
        </div>
      </Fragment>
    );
  }

  if (loading) {
    return (
      <Fragment>
        <div className="flex items-center justify-center br3 mt4" style={containerStyle}>
          <div className="flex items-center">
            <Asset
              path="images/spinner-2.svg"
              width="20"
              height="20"
            />
            <span className="ml1 gray">Loading data, please wait&hellip;</span>
          </div>
        </div>
      </Fragment>
    );
  }

  return (
    <Fragment>
      {children}
    </Fragment>
  );
};
