
import { Asset } from "js/toolbox";
export const Loader = (props: { content?: string, } ) => {
  return (
    <div className="tc pv5">
      <Asset path="images/spinner-2.svg" className="spinner"/>
      {props.content && <p className="mt3 gray">{props.content}</p>}
    </div>
  );
};
