import { createPortal, useEffect, useRef } from "preact/compat";
import { h } from "preact";

interface ModalProps extends h.JSX.HTMLAttributes<HTMLDivElement> {
  isOpen: boolean;
  close: () => void;
  title: string;
  width?: string;
}

export const Modal = (props: ModalProps) => {
  const modalRef = useRef();
  if (!props.isOpen) {
    return;
  }

  useEffect(() => {
    const closeOnEscape = (e: KeyboardEvent) => {
      if (e.key === `Escape`) {
        props.close();
      }
    };

    document.addEventListener(`keydown`, closeOnEscape);

    return () => {
      document.removeEventListener(`keydown`, closeOnEscape);
    };
  });

  const close = (e: MouseEvent) => {
    // Close the modal only if the click was outside the modal
    if (e.target !== modalRef.current) {
      return;
    }

    props.close();
  };

  const modalRoot = document.getElementById(`main-content`);

  return createPortal(
    <div
      ref={modalRef}
      className="fixed flex items-start justify-center vh-100 w-100"
      style={{
        zIndex: 1000,
        backgroundColor: `rgba(0, 0, 0, 0.5)`,
        left: 0,
        top: 0
      }}
      onClick={close}
    >
      <div className={`bg-white br3 shadow-1 w-90 ${props.width || `w-50-m`} mw6 relative`}
        style={{
          top: `20vh`
        }}>
        {props.title && (
          <div className="pa3 bb b--black-10">
            <h2 className="f3 mb0">{props.title}</h2>
          </div>
        )}
        {props.children}
      </div>
    </div>,
    modalRoot
  );
};
