
import { Fragment, VNode, createRef } from "preact";
import { useEffect, useLayoutEffect, useState } from "preact/hooks";
import styled, { css } from "styled-components";

interface Item {
  label: VNode<any>;
  value: string;
}

interface AutocompleteProps {
  items: Item[];
  onChange?: (value: string) => void;
}


const List = styled.ul<{ $height: number, $width: number }>`
  box-shadow: 0 0 0 1px rgba(0,0,0,0.2), 0 0px 1px 0 #e5e8ea;
  list-style: none;
  margin-top: 0;
  overflow-y: auto;
  padding-left: 0;
  position: absolute;
  width: ${props => props.$width}px;
  background: #fff;
  top: ${props => props.$height}px;
  border-radius: 0 0 3px 3px;
  z-index: 100;

  li {
    padding: 5px;
  }

  li:hover {
    background: #eee;
    cursor: pointer;
  }

  li:last-child {
    border-bottom-left-radius: 3px;
    border-bottom-right-radius: 3px;
  }

  li.no-results {
    cursor: default;
  }
`;

const SearchInput = styled.input<{ $active?: boolean }>`
  z-index: 99;
  ${(props) => {
    switch (props.$active) {
      case true:
        return css`
          border-bottom-left-radius: 0;
          border-bottom-right-radius: 0;
        `;
      default:
        return css`
        `;
    }
  }}
`;

export const Autocomplete = (props: AutocompleteProps) => {
  const ref = createRef();
  const inputRef = createRef();
  const [height, setHeight] = useState(0);
  const [width, setWidth] = useState(0);
  const [active, setActive] = useState(false);
  const [searchString, setSearchString] = useState(``);
  const [items, setItems] = useState(props.items);

  useLayoutEffect(() => {
    const inputEl = ref.current as HTMLElement;
    const inputHeight = inputEl.offsetHeight;
    const inputWidth = inputEl.offsetWidth;
    setHeight(inputHeight);
    setWidth(inputWidth);
    inputRef.current.focus();
  }, []);

  const onInput = (e: Event) => {
    const target = e.target as HTMLInputElement;
    setSearchString(target.value);
  };

  useEffect(() => {
    const filteredItems = props.items.filter((item) => {
      return item.value.toString().toLowerCase().includes(searchString.toLowerCase());
    });
    setItems(filteredItems);
  }, [searchString]);

  const onFocus = (e: Event) => {
    const target = e.target as HTMLInputElement;
    if(target == document.activeElement) {
      setActive(true);
    }
  };

  const shouldClosePopover = (ev: MouseEvent) => {
    if(ref.current) {
      if((ref.current as HTMLElement).contains(ev.target as HTMLElement)) {
        return;
      }
    }
    setActive(false);
  };

  useEffect(() => {
    window.addEventListener(`click`, shouldClosePopover);
    return () => window.removeEventListener(`click`, shouldClosePopover);
  }, [active]);

  return (
    <Fragment>
      <div
        ref={ref}
        className=""
        style="position: relative;"
      >
        <SearchInput
          ref={inputRef}
          value={searchString}
          onInput={onInput}
          $active={active}
          type="text"
          className="form-control form-control-tiny"
          placeholder="search"
          onFocusIn={onFocus}
          onFocusOut={onFocus}
        />
        {active && <List $height={height} $width={width}>
          {items.map((item, idx) =>
            <li
              className="f6"
              onClick={(e) => {e.preventDefault(); props.onChange(item.value); }}
              key={idx}
            >
              {item.label}
            </li>,
          )}
          {items.length == 0 && <li className="f6">No results</li>}
        </List>}
      </div>
    </Fragment>
  );
};
