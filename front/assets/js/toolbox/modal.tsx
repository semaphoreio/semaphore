import { h } from "preact";
import React, { createPortal, useEffect, useRef } from "preact/compat";

interface ModalProps extends React.HTMLAttributes<HTMLDivElement> {
  isOpen: boolean;
  close: () => void;
  title: string;
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
      className="fixed overlay flex items-center justify-center vh-100 w-100"
      style="display: block; z-index: 1000; left: 0; top: 0;"
      onClick={close}
    >
      {props.children}
    </div>,
    modalRoot
  );
};
