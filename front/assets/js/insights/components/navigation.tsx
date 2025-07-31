import { VNode } from 'preact';
import { useContext, useState } from 'preact/hooks';
import { NavLink } from 'react-router-dom';
import * as stores from '../stores';
import { State } from '../stores/dashboards';
import Tippy from '@tippyjs/react';


interface Props {
  createDashboard: (e: any) => void;
  state: State;
}

export const Navigation = ({ createDashboard, state }: Props) => {
  const { projectSummary } = useContext(stores.Summary.Context);

  const formatPerformance = () => {
    return `${projectSummary.defaultBranch.pipelinePerformanceP50}`;
  };

  const formatFrequency = () => {
    return `${projectSummary.defaultBranch.pipelineFrequencyDailyCount}`;
  };

  const formatReliability = () => {
    return `${projectSummary.defaultBranch.pipelineReliabilityPassRate}`;
  };

  let name=``;
  const onInputNameChange = (e: any) => {
    name = e.target.value;
  };


  const [visible, setVisible] = useState(false);
  const show = () => setVisible(true);
  const hide = () => setVisible(false);

  const onSubmit = (e: any) => {
    e.preventDefault();
    if (name.length> 0) {
      hide();
      createDashboard(name);
    }
    name=``;
  };


  return (
    <div className="w6 flex-shrink-0 ph4">
      <div>

        <div className="mt4 nl3 nr3 ml2">
          <div className="flex items-center justify-between mb1 mt1">
            <div className="f7 gray pa2 ph3">
              <span className="ml2">KEY METRICS</span>
            </div>
            <NavLink to="/settings"
              className="link dark-gray flex items-center justify-between pa2 ph3 pointer br3 mt1 ">
              <div className="flex items-center">
                {Icons.settings}
              </div>

            </NavLink>
          </div>
          <NavigationItem to="/performance" title="Performance" value={formatPerformance()}/>
          <NavigationItem to="/frequency" title="Frequency" value={formatFrequency()}/>
          <NavigationItem to="/reliability" title="Reliability" value={formatReliability()}/>
          <div>
            <div className="flex items-center justify-between mb1 mt1">
              <div className="f7 gray pa2 ph3">
                <span className="ml2">CUSTOM DASHBOARDS</span>
              </div>
              <Tippy
                placement="right"
                allowHTML={true}
                interactive={true}
                theme="light"
                trigger="click"
                visible={visible}
                onClickOutside={hide}
                content={
                  <form onSubmit={onSubmit}>
                    <div className="f5 pa1">
                      <div className="b mb1">Name your new dashboard</div>
                      <input className="x-select-on-click form-control w-100" type="text"
                        value="" onInput={onInputNameChange} placeholder="Enter name&hellip;"></input>
                      <div className="mt3">
                        <button type="submit" className="btn btn-primary">Create</button>
                        <button type="reset" className="btn btn-secondary ml2" onClick={hide}>Cancel</button>
                      </div>
                    </div>
                  </form>
                }>
                <span className="link dark-gray pa2 ph3 pointer br3 mt1" onClick={visible ? hide : show}>
                  <img src="/projects/assets/images/icn-plus-nav.svg" alt="list" className="mr1" width="16" height="16"/>
                </span>
              </Tippy>

            </div>
            {state.dashboards.map((dashboard, index) => {
              return <NavigationItem key={index}
                to={`/custom-dashboards/${dashboard.id}`}
                state={dashboard}
                title={dashboard.name}
                value=""/>;
            })}

          </div>
        </div>
      </div>
    </div>
  );
};


export const NavigationItem = ({
  to,
  title,
  icon,
  value,
  state
}: { to: any, title: string, icon?: VNode, value: string, state?: object, }) => {
  const className = ({ isActive }: { isActive: boolean, }) => {
    return `link flex items-center justify-between pa1 mt1 ph3 pointer br3 ` + (isActive ? `bg-green hover-bg-green white b` : `dark-gray`);
  };
  return (
    <NavLink to={to} state={state} className={className}>
      <div className="flex items-center">
        {icon}
        <div className="ml2">{title}</div>
      </div>

      <div className="">{value}</div>
    </NavLink>
  );
};


const Icons = {
  performance: (
    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
      <path fillRule="evenodd" clipRule="evenodd"
        d="M20 12C20 16.4183 16.4183 20 12 20C7.58172 20 4 16.4183 4 12C4 7.58172 7.58172 4 12 4C16.4183 4 20 7.58172 20 12ZM19 12C19 15.866 15.866 19 12 19C8.13401 19 5 15.866 5 12C5 8.13401 8.13401 5 12 5C15.866 5 19 8.13401 19 12Z"
        fill="black"/>
      <path
        d="M11.456 12.577L10.273 11.45C10.1779 11.3594 10.066 11.2884 9.94344 11.241C9.82092 11.1937 9.69028 11.171 9.55898 11.1741C9.29381 11.1805 9.04202 11.292 8.85902 11.484C8.67603 11.676 8.5768 11.9328 8.58318 12.198C8.58955 12.4632 8.70101 12.715 8.89302 12.898L10.81 14.724C10.9059 14.8153 11.019 14.8867 11.1427 14.934C11.2665 14.9813 11.3983 15.0036 11.5307 14.9995C11.6631 14.9954 11.7934 14.965 11.9139 14.9102C12.0345 14.8553 12.143 14.7771 12.233 14.68L15.619 11.028C15.7939 10.8327 15.8851 10.5765 15.873 10.3146C15.8608 10.0527 15.7463 9.80609 15.5541 9.62779C15.3619 9.44949 15.1074 9.3538 14.8454 9.36131C14.5833 9.36883 14.3347 9.47895 14.153 9.66797L11.456 12.577Z"
        fill="black"/>
    </svg>
  ),
  frequency: (
    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
      <path
        d="M14.3333 4H9.66667V5.52522H14.3333V4ZM11.2218 13.9094H12.777V9.336H11.2218V13.9094ZM17.467 8.8638L18.5718 7.78105C18.237 7.39231 17.8718 7.02644 17.4752 6.7063L16.3703 7.78905C15.1318 6.81231 13.5898 6.2798 12 6.27983C10.6155 6.27983 9.26215 6.68217 8.11101 7.43597C6.95987 8.18976 6.06266 9.26116 5.53285 10.5147C5.00303 11.7682 4.86441 13.1475 5.13451 14.4782C5.4046 15.809 6.07129 17.0313 7.05025 17.9907C8.02922 18.9501 9.2765 19.6035 10.6344 19.8682C11.9922 20.1329 13.3997 19.997 14.6788 19.4778C15.9579 18.9586 17.0511 18.0793 17.8203 16.9512C18.5895 15.823 19 14.4967 19 13.1399C18.9978 11.5855 18.4573 10.0779 17.467 8.8638V8.8638ZM12 18.4828C11.2848 18.4834 10.5765 18.3458 9.91563 18.0778C9.25475 17.8099 8.65428 17.4169 8.14856 16.9212C7.64283 16.4256 7.24179 15.8372 6.96838 15.1895C6.69497 14.5418 6.55456 13.8477 6.55517 13.1468C6.55471 12.446 6.69524 11.7519 6.96872 11.1044C7.2422 10.4569 7.64326 9.86854 8.14897 9.37305C8.65467 8.87756 9.2551 8.48464 9.9159 8.21676C10.5767 7.94889 11.2849 7.81132 12 7.81192C12.715 7.81147 13.4231 7.94915 14.0837 8.21709C14.7444 8.48503 15.3447 8.87798 15.8503 9.37346C16.3559 9.86893 16.7568 10.4572 17.0302 11.1047C17.3036 11.7521 17.4441 12.4461 17.4437 13.1468C17.4443 13.8476 17.3039 14.5416 17.0306 15.1892C16.7572 15.8368 16.3563 16.4252 15.8507 16.9208C15.3451 17.4164 14.7448 17.8095 14.084 18.0775C13.4233 18.3455 12.7151 18.4832 12 18.4828V18.4828Z"
        fill="#28323C"/>
    </svg>
  ),
  reliability: (
    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
      <path
        d="M14.3333 4H9.66667V5.52522H14.3333V4ZM11.2218 13.9094H12.777V9.336H11.2218V13.9094ZM17.467 8.8638L18.5718 7.78105C18.237 7.39231 17.8718 7.02644 17.4752 6.7063L16.3703 7.78905C15.1318 6.81231 13.5898 6.2798 12 6.27983C10.6155 6.27983 9.26215 6.68217 8.11101 7.43597C6.95987 8.18976 6.06266 9.26116 5.53285 10.5147C5.00303 11.7682 4.86441 13.1475 5.13451 14.4782C5.4046 15.809 6.07129 17.0313 7.05025 17.9907C8.02922 18.9501 9.2765 19.6035 10.6344 19.8682C11.9922 20.1329 13.3997 19.997 14.6788 19.4778C15.9579 18.9586 17.0511 18.0793 17.8203 16.9512C18.5895 15.823 19 14.4967 19 13.1399C18.9978 11.5855 18.4573 10.0779 17.467 8.8638V8.8638ZM12 18.4828C11.2848 18.4834 10.5765 18.3458 9.91563 18.0778C9.25475 17.8099 8.65428 17.4169 8.14856 16.9212C7.64283 16.4256 7.24179 15.8372 6.96838 15.1895C6.69497 14.5418 6.55456 13.8477 6.55517 13.1468C6.55471 12.446 6.69524 11.7519 6.96872 11.1044C7.2422 10.4569 7.64326 9.86854 8.14897 9.37305C8.65467 8.87756 9.2551 8.48464 9.9159 8.21676C10.5767 7.94889 11.2849 7.81132 12 7.81192C12.715 7.81147 13.4231 7.94915 14.0837 8.21709C14.7444 8.48503 15.3447 8.87798 15.8503 9.37346C16.3559 9.86893 16.7568 10.4572 17.0302 11.1047C17.3036 11.7521 17.4441 12.4461 17.4437 13.1468C17.4443 13.8476 17.3039 14.5416 17.0306 15.1892C16.7572 15.8368 16.3563 16.4252 15.8507 16.9208C15.3451 17.4164 14.7448 17.8095 14.084 18.0775C13.4233 18.3455 12.7151 18.4832 12 18.4828V18.4828Z"
        fill="#28323C"/>
    </svg>
  ),
  settings: (
    <svg width="24" height="24" viewBox="-3 -3 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
      <path
        d="M7.5 1.996a.1.1 0 00-.099.086l-.25 1.784L6.733 4a4.193 4.193 0 00-1.554.9l-.327.299-1.68-.69a.1.1 0 00-.124.043l-.502.87a.1.1 0 00.026.128L4 6.667l-.093.43a4.216 4.216 0 00-.005 1.788l.093.43-1.438 1.112a.1.1 0 00-.026.129l.502.869a.1.1 0 00.124.043l1.68-.68.326.3c.445.41.979.726 1.568.913l.42.134.25 1.783a.1.1 0 00.099.086h1.003a.1.1 0 00.099-.087l.24-1.777.424-.133a4.192 4.192 0 001.575-.91l.326-.298 1.652.669a.1.1 0 00.124-.043l.502-.869a.1.1 0 00-.026-.13L12.013 9.34l.095-.433a4.217 4.217 0 00-.004-1.831l-.097-.433 1.4-1.093a.1.1 0 00.026-.129l-.502-.869a.1.1 0 00-.125-.042l-1.65.677-.328-.297a4.192 4.192 0 00-1.56-.896l-.425-.133-.24-1.778a.1.1 0 00-.1-.087H7.502zm-1.485-.108A1.5 1.5 0 017.501.596h1.003a1.5 1.5 0 011.486 1.3l.124.916c.472.192.912.446 1.309.752l.852-.35a1.5 1.5 0 011.868.638l.502.87a1.5 1.5 0 01-.376 1.932l-.718.56a5.63 5.63 0 01.004 1.548l.721.557a1.5 1.5 0 01.382 1.937l-.502.869a1.5 1.5 0 01-1.861.64l-.852-.344a5.59 5.59 0 01-1.329.768l-.124.915a1.5 1.5 0 01-1.486 1.3H7.5a1.5 1.5 0 01-1.486-1.292l-.13-.93a5.597 5.597 0 01-1.325-.771l-.877.354a1.5 1.5 0 01-1.861-.64l-.502-.869a1.5 1.5 0 01.382-1.937l.756-.584a5.645 5.645 0 01.003-1.494l-.752-.587a1.5 1.5 0 01-.376-1.933l.502-.869a1.5 1.5 0 011.868-.637l.877.36a5.593 5.593 0 011.305-.755l.13-.932zM7.989 6.7a1.3 1.3 0 100 2.6 1.3 1.3 0 000-2.6zM5.29 8a2.7 2.7 0 115.4 0 2.7 2.7 0 01-5.4 0z"
        fill="#28323C"/>
    </svg>
  )
};
