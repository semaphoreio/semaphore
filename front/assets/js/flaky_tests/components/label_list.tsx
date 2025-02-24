import { Fragment } from "preact";
import Tippy from "@tippyjs/react";
import { useContext, useRef, useState } from "preact/hooks";
import * as stores from "../stores";
import $ from "jquery";
// eslint-disable-next-line @typescript-eslint/ban-ts-comment
// @ts-ignore
import { Notice } from "js/notice";
import * as toolbox from "js/toolbox";
import styled from "styled-components";


export const LabelList = ({ testId, labels, setLabels, labelClass = `flex items-center mt1` }: { testId: string, labels: string[], setLabels: any, labelClass?: string, }) => {
  const config = useContext(stores.Config.Context);
  const { state: filterState, dispatch: dispatchFilter } = useContext(stores.Filter.Context);

  labels = labels.filter((l) => l.length > 0);

  const onCreate = (label: string) => {
    if(labels.includes(label))
      return;
    // call api to create label
    const endpoint = config.baseURL + `/${testId}/labels`;

    const url = new URL(endpoint, location.origin);
    const body = {
      label: label,
    };

    fetch(url, {
      credentials: `same-origin`,
      method: `POST`,
      body: JSON.stringify(body),
      headers: {
        "Content-Type": `application/json`,
        "X-CSRF-Token": $(`meta[name='csrf-token']`).attr(`content`),
      },
    })
      .then((response) => response.json())
      .then(() => {
        setLabels([...labels, label]);
      })
      .catch(() => {
        Notice.error(`Failed to create label.`);
      });
  };

  const onDelete = (label: string) => {
    const endpoint = config.baseURL + `/${testId}/labels/${label}`;
    const url = new URL(endpoint, location.origin);
    fetch(url, {
      credentials: `same-origin`,
      method: `DELETE`,
      headers: {
        "Content-Type": `application/json`,
        "X-CSRF-Token": $(`meta[name='csrf-token']`).attr(`content`),
      }
    }).then((response) => {
      if (response.status === 204) {
        return response;
      } else {
        throw new Error(`Failed to delete label.`);
      }
    })
      .then(() => {
        setLabels(labels.filter((l) => l !== label));
      })
      .catch(() => Notice.error(`Failed to delete label.`));
  };

  const filterByLabel = (label: string) => {
    const query = filterState.query;
    const setQuery = (q: string) => dispatchFilter({ type: `SET_QUERY`, value: q });
    // If label is already in search filter - skip adding the same one
    if(query.includes(`@label:"${label}"`))
      return;
    const newQuery =`${query} @label:"${label}"`;
    setQuery(newQuery);
  };

  const LabelLink = styled.a<{ $label: string, }>`
    background-color: ${({ $label }: { $label: string, }) => toolbox.Formatter.stringToHexColor($label, 30) };
    border-color: ${({ $label }: { $label: string, }) => toolbox.Formatter.stringToHexColor($label, 60) };

    &:hover {
      background-color: ${({ $label }: { $label: string, }) => toolbox.Formatter.stringToHexColor($label, 60) };
    }
  `;

  const TagLink = ({ label }: { label: string, }) => {
    return (
      <div className={labelClass}>
        <LabelLink $label={label} className="link black ba ph2 pointer br3 br--left" onClick={() => { filterByLabel(label); }}>{label}</LabelLink>
        <span className="self-stretch pointer material-symbols-outlined bg-washed-gray b--lightest-gray hover-bg-washed-red bt bb br b--gray br3 br--right" onClick={() => onDelete(label)}>
          close
        </span>
      </div>
    );
  };

  return (
    <Fragment>
      {labels.map((label, idx) => (
        <TagLink key={idx} label={label}/>
      ))}
      {labels.length < 3 && <CreateLabel onCreate={onCreate}/>}
    </Fragment>
  );
};

const CreateLabel = ({ onCreate }: { onCreate: any, } ) => {
  const inputRef = useRef<HTMLInputElement>();

  const [label, setLabel] = useState(``);
  const [visible, setVisible] = useState(false);
  const hide = () => setVisible(false);
  const show = () => {
    setVisible(true);
    setTimeout(() => {
      inputRef.current.focus();
    }, 100);
  };

  const onKeyPress = (e: any) => {
    if (e.key === `Enter`) {
      onClick();
    }
  };

  const onInput = (e: any) => {
    const value = e.target.value as string;
    setLabel(value);
  };

  const onClick = () => {
    if (label.length > 0) {
      onCreate(label);
      setLabel(``);
    }
    hide();
  };

  return <Tippy placement="right"
    allowHTML={true}
    interactive={true}
    theme="light"
    trigger="click"
    visible={visible}
    onClickOutside={hide}
    content={
      <div className="flex items-center justify-between pa2">
        <input ref={inputRef}
          className="mr1 form-control-sm"
          type="text"
          value={label}
          onInput={onInput}
          onKeyPress={onKeyPress}
        />
        <button className="btn btn-tiny btn-primary" onClick={onClick}>OK</button>
      </div>
    }>
    <a className="pointer" data-tippy-content="Label this test for easier filtering" onClick={show}>+ add Label</a>
  </Tippy>;
};
