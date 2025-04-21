import { Handle, HandleType, Position } from '@xyflow/react';
import Tippy from '@tippyjs/react';
import 'tippy.js/dist/tippy.css';
import React, { useRef } from 'react';

const BAR_WIDTH = 48;
const BAR_HEIGHT = 6;

const actionsDemo = ['Development Environment: new_run'];
const conditionsDemo = ['run.state=pass', 'output.type=community'];

function TooltipContent() {
  return (
    <div className="p-2 min-w-[300px]">
      <div className="text-xs text-gray-600 font-semibold mb-1">Events this stage listens:</div>
      <div className="flex gap-1 mb-2 flex-wrap">
        {actionsDemo.map((action) => (
          <span
            key={action}
            className="bg-indigo-100 text-indigo-800 text-xs font-semibold px-2 py-0.5 rounded mr-1 mb-1 border border-indigo-200"
          >
            {action}
          </span>
        ))}
      </div>
      <div className="text-xs text-gray-600 font-semibold mb-1">Conditions:</div>
      <div className="flex gap-1 mb-2 flex-wrap">
        {conditionsDemo.map((cond) => (
          <span
            key={cond}
            className="bg-green-100 text-green-800 text-xs font-semibold px-2 py-0.5 rounded mr-1 mb-1 border border-green-200"
          >
            {cond}
          </span>
        ))}
      </div>
      <div className="bg-white border border-gray-200 rounded p-2 text-xs text-gray-700 shadow-sm">
        Lorem ipsum dolor sit amet, consectetur adipiscing elit. Suspendisse et urna fringilla, tincidunt nulla nec, dictum erat.
      </div>
    </div>
  );
}

export default function CustomBarHandle({ type, position, id }: { type: string; position: Position; id: string }) {
  // Positioning for left/right bars
  const isLeft = position === Position.Left;
  const isRight = position === Position.Right;
  const isVertical = isLeft || isRight;
  let placement: Position = Position.Top;
  if (isLeft) placement = Position.Left;
  if (isRight) placement = Position.Right;

  // --- Fix: Use getReferenceClientRect for zoom-stable positioning ---
  const handleRef = useRef(null);
  return (
    <Tippy
      content={<TooltipContent />}
      interactive={true}
      placement={placement}
      delay={[120, 50]}
      theme="light-border"
      maxWidth={320}
      arrow={true}
      offset={[0, 8]}
      // getReferenceClientRect={() => {
      //   if (handleRef.current) {
      //     return handleRef.current.getBoundingClientRect();
      //   }
      //   return undefined;
      // }}
    >
      <div style={{ display: 'inline-block' }} ref={handleRef}>
        <Handle
          type={type as HandleType}
          position={position}
          id={id}
          style={{
            background: 'var(--indigo)',
            borderRadius: 3,
            width: isVertical ? BAR_HEIGHT : BAR_WIDTH,
            height: isVertical ? BAR_WIDTH : BAR_HEIGHT,
            border: 'none',
            left: isLeft ? -BAR_HEIGHT / 2 : undefined,
            right: isRight ? -BAR_HEIGHT / 2 : undefined,
            top: '50%',
            transform: 'translateY(-50%)',
            zIndex: 2,
            boxShadow: '0 1px 6px 0 rgba(19,198,179,0.15)',
          }}
          className="custom-bar-handle"
        />
      </div>
    </Tippy>
  );
}
