interface Tip { props: { content: unknown, }, setContent: (content: string) => void, destroy: () => void, reference: Element, }
type Tipped = HTMLElement & { _tippy?: Tip, };
type TippyFactory = (target: HTMLElement, props: { duration: [number, number], }) => unknown;

export const bindTooltips = (root: HTMLElement, tippy: TippyFactory | undefined) => {
  if (!tippy) return;
  root.querySelectorAll<Tipped>(`[data-tippy-content]`).forEach((node) => {
    const content = node.dataset.tippyContent;
    if (!node._tippy) tippy(node, { duration: [150, 50] });
    else if (node._tippy.props.content !== content) node._tippy.setContent(content);
  });
  document.querySelectorAll<HTMLElement & { _tippy?: Tip, }>(`[data-tippy-root]`).forEach((popper) => {
    if (popper._tippy && !popper._tippy.reference.isConnected) popper._tippy.destroy();
  });
};
