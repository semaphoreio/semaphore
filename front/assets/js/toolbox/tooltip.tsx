import Popper, { createPopper } from "@popperjs/core";
import { VNode, Fragment } from "preact";
import { createPortal } from "preact/compat";
import { useEffect, useLayoutEffect, useRef, useState } from "preact/hooks";
import { define } from "preactement";
import { Placement } from "tippy.js";

interface TooltipProps extends h.JSX.HTMLAttributes {
  anchor: VNode<any>;
  content?: string | VNode<any>;
  stickable?: boolean;
  placement?: Placement;
  className?: string;
}

export const Tooltip = (props: TooltipProps) => {
  let container = document.getElementById(`sem-tooltips`);
  if (!container) {
    container = document.createElement(`div`);
    container.id = `sem-tooltips`;
    document.body.appendChild(container);
  }

  const tooltipEl = useRef(null);
  const anchorEl = useRef(null);
  const tooltipArrowEl = useRef(null);
  const [visible, setVisible] = useState(false);
  const [popper, setPopper] = useState<null | Popper.Instance>(null);
  const [sticky, setSticky] = useState(false);
  if (!props.placement) {
    props.placement = `bottom`;
  }

  useLayoutEffect(() => {
    if (visible || sticky) {
      tooltipEl.current.setAttribute(`data-show`, ``);
      popper.forceUpdate();
    } else {
      tooltipEl.current.removeAttribute(`data-show`);
    }

    window.addEventListener(`click`, shouldClosePopover);
    return () => window.removeEventListener(`click`, shouldClosePopover);
  }, [visible, sticky]);

  const shouldClosePopover = (ev: MouseEvent) => {
    if ((tooltipEl.current as HTMLElement).contains(ev.target as HTMLElement)) {
      return;
    }

    if (anchorEl.current == ev.target) {
      return;
    }

    if (sticky) {
      setSticky(false);
    }
  };

  useEffect(() => {
    if (!anchorEl.current || !tooltipEl.current) return;
    const instance = createPopper(
      anchorEl.current as Element,
      tooltipEl.current as HTMLElement,
      {
        placement: props.placement,
        strategy: `fixed`,
        modifiers: [
          {
            name: `arrow`,
            options: {
              element: tooltipArrowEl.current,
            },
          },
          {
            name: `offset`,
            options: {
              offset: [0, 12],
            },
          },
        ],
      }
    );

    setPopper(instance);

    return () => instance.destroy();
  }, [anchorEl.current, tooltipEl.current]);

  const onMouseOver = () => {
    setVisible(true);
  };

  const onMouseOut = () => {
    setVisible(false);
  };

  const onClick = () => {
    if (props.stickable) {
      setSticky(!sticky);
    }
  };

  const tooltipContent = createPortal(
    <div
      ref={tooltipEl}
      className="sem-tooltip bg-dark-gray white br2 pv1 ph2"
      style={{ maxWidth: 400 }}
    >
      <div
        className="sem-tooltip-arrow"
        data-popper-arrow
        ref={tooltipArrowEl}
      ></div>
      {props.content}
    </div>,
    container
  );

  return (
    <Fragment>
      <div
        ref={anchorEl}
        onMouseOver={onMouseOver}
        onMouseOut={onMouseOut}
        onClick={onClick}
        style={{ display: `flex` }}
      >
        {props.anchor}
      </div>
      {tooltipContent}
    </Fragment>
  );
};

define(`sem-tooltip`, () => Tooltip);
