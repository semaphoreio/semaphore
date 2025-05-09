import { Handle, Position, useReactFlow } from '@xyflow/react';
import Tippy from '@tippyjs/react';
import 'tippy.js/dist/tippy.css';
import 'tippy.js/themes/light.css';
import React, { useRef, useEffect, useState, CSSProperties } from 'react';
import { HandleProps, Connection, Condition } from '@/canvas/types/flow';

const BAR_WIDTH = 48;
const BAR_HEIGHT = 6;



export default function CustomBarHandle({ type, conditions, connections }: HandleProps) {
  
  // Positioning for left/right bars
  const isLeft = type === 'target';
  const isRight = type === 'source';
  const isVertical = isLeft || isRight;
  
  // Create handle style
  const handleStyle = {
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
  };
  
  switch(type) {
    case 'source':
      return <BarHandleRight handleStyle={handleStyle} />;
    case 'target':
      return <BarHandleLeft handleStyle={handleStyle} connections={connections} conditions={conditions} />;
  }
}


function BarHandleRight({handleStyle}: {handleStyle: CSSProperties}) {
  return <Handle type="source" position={Position.Right} id="source" style={handleStyle} className="custom-bar-handle !bg-blue-500"/>
}

function BarHandleLeft({handleStyle, connections = [], conditions = []}: {handleStyle: CSSProperties, connections?: Connection[], conditions?: Condition[]}) {
  const handleRef = useRef<HTMLDivElement>(null);
  // Access ReactFlow instance to get zoom level
  const { getZoom } = useReactFlow();
  const [zoomLevel, setZoomLevel] = useState(1);
  
  // Update zoom level when it changes
  useEffect(() => {
    const updateZoom = () => {
      setZoomLevel(getZoom());
    };
    
    // Initial update
    updateZoom();
    
    // Listen for viewport changes
    document.addEventListener('reactflow:viewport', updateZoom);
    
    return () => {
      document.removeEventListener('reactflow:viewport', updateZoom);
    };
  }, [getZoom]);

    // Create style for scaling the tooltip content
    const tooltipStyle = {
      transform: `scale(${1 / zoomLevel})`,
      transformOrigin: 'center bottom'
    };

return (
  <div className="custom-handle-container" ref={handleRef}>
    {/* Use Tippy directly on the Handle component */}
    <Tippy
      content={<div style={tooltipStyle}><TooltipContent connections={connections} conditions={conditions} /></div>}
      interactive={true}
      placement="left"
      appendTo={document.body} // This is critical - render to body
      theme="light"
      maxWidth={320 * (1 / zoomLevel)} // Scale max width with zoom
      arrow={true}
      offset={[0, 10 * (1 / zoomLevel)]} // Scale offset with zoom
      zIndex={1000}
      popperOptions={{
        strategy: 'fixed', // This is crucial for React Flow
        modifiers: [
          {
            name: 'preventOverflow',
            options: {
              boundary: document.body
            }
          }
        ]
      }}
    >
      {/* Use a simple div as the reference */}
      <div style={{ display: 'flex' }}>
        <Handle
          type="target"
          position={Position.Left}
          id="target"
          style={handleStyle}
          className="custom-bar-handle !bg-blue-500"
        />
      </div>
    </Tippy>
  </div>
);
}


function TooltipContent({ connections = [], conditions = [] }: { connections?: Connection[], conditions?: Condition[] }) {
  return (
    <div className="p-2 min-w-[300px] bg-white">
      <div className="text-xs text-gray-600 font-semibold mb-1">Connections:</div>
      <div className="flex gap-1 mb-2 flex-wrap">
        {connections.map((connection) => (
          <span
            key={connection.name}
            className="bg-indigo-100 text-indigo-800 text-xs font-semibold px-2 py-0.5 rounded mr-1 mb-1 border border-indigo-200"
          >
            {connection.name}: {connection.type}
          </span>
        ))}
      </div>
      <div className="text-xs text-gray-600 font-semibold mb-1">Conditions:</div>
      <div className="flex gap-1 mb-2 flex-wrap">
        {conditions.map((condition, index) => (
          <span
            key={index}
            className="bg-green-100 text-green-800 text-xs font-semibold px-2 py-0.5 rounded mr-1 mb-1 border border-green-200"
          >
            {condition.type}: {condition.approval && condition.approval.count > 0 ? `Requires ${condition.approval.count} approval(s)` : 'Auto'}
          </span>
        ))}
      </div>
      <div className="bg-white border border-gray-200 rounded p-2 text-xs text-gray-700 shadow-sm">
        Lorem ipsum dolor sit amet, consectetur adipiscing elit. Suspendisse et urna fringilla, tincidunt nulla nec, dictum erat.
      </div>
    </div>
  );
}