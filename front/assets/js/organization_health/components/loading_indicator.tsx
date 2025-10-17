import { Fragment } from "preact";
import { Asset } from "../../toolbox";

export const LoadingIndicator = () => {
  return (
    <Fragment>
      <div className="flex items-center justify-center br3 ph3 pv4">
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
};
