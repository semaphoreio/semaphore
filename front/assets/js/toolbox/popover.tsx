import Popper, { createPopper } from "@popperjs/core";
import { isFunction } from "lodash";
import { VNode, Fragment } from "preact";
import { useEffect, useLayoutEffect, useRef, useState } from "preact/hooks";
import { define } from "preactement";
import { Placement } from "tippy.js";

interface PopoverProps {
  anchor: VNode<any>;
  content?: VNode<any> | (({ setVisible }: { setVisible: (visible: boolean) => void }) => VNode<any>);
  className?: string;
  placement?: Placement;
  maxWidth?: number;
}
export const Popover = ({ anchor, content, className = `pa3`, placement = `bottom`, maxWidth = 400 }: PopoverProps) => {
  const popoverEl = useRef(null);
  const anchorEl = useRef(null);
  const popoverArrowEl = useRef(null);
  const [visible, setVisible] = useState(false);
  const [popper, setPopper] = useState<null | Popper.Instance>(null);

  useLayoutEffect(() => {
    const instance = createPopper(anchorEl.current as Element, popoverEl.current as HTMLElement, {
      placement: placement,
      modifiers: [
        {
          name: `arrow`,
          options: {
            element: popoverArrowEl.current,
          },
        },
        {
          name: `offset`,
          options: {
            offset: [0, 16],
          },
        },
      ],
    });

    setPopper(instance);
  }, [anchorEl, popoverEl]);

  const shouldClosePopover = (ev: MouseEvent) => {
    if ((popoverEl.current as HTMLElement).contains(ev.target as HTMLElement)) {
      return;
    }

    if (anchorEl.current == ev.target) {
      return;
    }

    if (visible) {
      setVisible(false);
    }
  };

  useEffect(() => {
    if (!visible) {
      popoverEl.current.removeAttribute(`data-show`);
    } else {
      popoverEl.current.setAttribute(`data-show`, ``);
      popper.forceUpdate();
    }

    window.addEventListener(`click`, shouldClosePopover);
    return () => window.removeEventListener(`click`, shouldClosePopover);
  }, [visible]);

  const renderContent = () => {
    if (isFunction(content)) {
      return content({ setVisible });
    } else {
      return content;
    }
  };

  return (
    <Fragment>
      <div
        className="sem-popover-anchor"
        ref={anchorEl}
        onClick={() => setVisible(!visible)}
      >
        {anchor}
      </div>
      <div
        ref={popoverEl}
        className={`sem-popover bg-white br2 ${className}`}
        style={{ maxWidth: maxWidth }}
      >
        <div
          className="sem-popover-arrow"
          data-popper-arrow
          ref={popoverArrowEl}
        ></div>
        {renderContent()}
      </div>
    </Fragment>
  );
};

define(`sem-popover`, () => Popover);
