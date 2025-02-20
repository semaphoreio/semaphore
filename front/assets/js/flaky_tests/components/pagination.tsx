import { useContext } from "preact/hooks";
import * as stores from "../stores";
import { Fragment, h } from "preact";

export const Pagination = () => {
  const { state, dispatch } = useContext(stores.FlakyTest.Context);

  const newPage = state.page + 1;
  const noMorePages = newPage>= state.totalPages;

  return (
    <Fragment>
      {!noMorePages && <div className="flex justify-center pt3">
        <div className="">
          <button className="btn btn-secondary" onClick={() => {
            dispatch({ type: `LOAD_PAGE`, page: newPage });
          }}>Load more</button>
        </div>
      </div>}
    </Fragment>
  );
};
