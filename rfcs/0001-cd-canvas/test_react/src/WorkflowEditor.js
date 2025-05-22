import React, { useState, useCallback, useRef } from 'react';
import * as htmlToImage from 'html-to-image';

import ReactFlow, {
  Controls,
  Background,
  useNodesState,
  useEdgesState,
  addEdge,
  MarkerType,
  ConnectionLineType,
  Handle,
  Position,
} from 'reactflow';
import 'reactflow/dist/style.css';
import icnCommit from './images/icn-commit.svg';
import profileImg from './images/profile.jpg';
import faviconPinned from './images/favicon-pinned.svg';
import Tippy from '@tippyjs/react';
import 'tippy.js/dist/tippy.css';
import CustomBarHandle from './CustomBarHandle';

// Custom stage component for the deployment card
const DeploymentCardStage = React.memo(({ data, selected, onIconAction, id, onDelete }) => {
  const [showOverlay, setShowOverlay] = React.useState(false);
  const handleAction = React.useCallback((action) => {
    if (action === 'code') setShowOverlay(true);
    if (onIconAction) onIconAction(action);
  }, [onIconAction]);
  
  const handleDelete = React.useCallback(() => {
    if (onDelete) onDelete(id);
  }, [onDelete, id]);
  
  // Use a fixed width to prevent resize observer loops and add white shadow
  const nodeStyle = React.useMemo(() => ({
    width: data.style?.width || 320,
    boxShadow: '0 4px 12px rgba(128,128,128,0.20)', // White shadow
  }), [data.style?.width]);
  
  return (
    <div className={`bg-white roundedg border ${selected ? 'ring-2 ring-blue-500' : 'border-gray-200'} relative`} style={nodeStyle}>
    {/* Icon block above node when selected */}
    {selected && (
      <div className="absolute -top-10 left-1/2 -translate-x-1/2 flex gap-2 bg-white shadow-gray-lg br4 px-3 py-2 border z-10">
      <Tippy content="Delete this stage" placement="top">
      <button className="hover:bg-red-100 text-red-600 p-2 br4" title="Delete Stage" onClick={handleDelete}>
      <span className="material-icons" style={{fontSize:20}}>delete</span>
      </button>
      </Tippy>
      <Tippy content="View code for this stage" placement="top">
      <button className="hover:bg-gray-100 p-2 br4" title="View Code" onClick={() => handleAction('code')}>
      <span className="material-icons" style={{fontSize:20}}>code</span>
      </button>
      </Tippy>
      <Tippy content="Edit triggers for this stage" placement="top">
      <button className="hover:bg-gray-100 p-2 br4" title="Edit Triggers" onClick={() => handleAction('edit')}>
      <span className="material-icons" style={{fontSize:20}}>bolt</span>
      </button>
      </Tippy>
      <Tippy content="Start a run for this stage" placement="top">
      <button className="hover:bg-gray-100 p-2 br4" title="Start Run" onClick={() => handleAction('run')}>
      <span className="material-icons" style={{fontSize:20}}>play_arrow</span>
      </button>
      </Tippy>

      </div>
    )}
    {/* Modal overlay for View Code */}
    <OverlayModal open={showOverlay} onClose={() => setShowOverlay(false)}>
    <h2 style={{ fontSize: 22, fontWeight: 700, marginBottom: 16 }}>Stage Code</h2>
    <div style={{ color: '#444', fontSize: 16, lineHeight: 1.7 }}>
    Lorem ipsum dolor sit amet, consectetur adipiscing elit. Suspendisse et urna fringilla, tincidunt nulla nec, dictum erat. Etiam euismod, justo id facilisis dictum, urna massa dictum erat, eget dictum urna massa id justo. Praesent nec facilisis urna. Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas.
    </div>
    </OverlayModal>
    {/* Custom Node Header */}
    <div className="flex items-center px-3 py-2 border-b bg-gray-50 rounded-tg">
    <span className="flex items-center justify-center w-8 h-8 bg-gray-100 rounded-full mr-2">
    <span className="material-symbols-outlined text-lg">{data.icon}</span>
    </span>
    <span className="font-bold text-gray-900 flex-1">{data.label}</span>
    {/* Example action button (menu) */}
    <button className="ml-2 p-1 rounded hover:bg-gray-200 transition" title="More actions">
    <span className="material-symbols-outlined text-gray-500">more_vert</span>
    </button>
    </div>
    <div className="p-4">
    <div className="flex justify-between items-center mb-3">
    <span className={`status-badge ${data.status ? data.status.toLowerCase() : ''}`}>{data.status}</span>
    <span className="text-xs text-gray-500">{data.timestamp}</span>
    </div>
    <div className="flex flex-wrap gap-1 mb-3">
    <span className="pipeline-badge bg-gray-100 text-gray-700 text-xs px-2 py-1 rounded-full mr2">
    code: {data.labels && data.labels[0] ? data.labels[0] : '—'}
    </span>
    <span className="pipeline-badge bg-gray-100 text-gray-700 text-xs px-2 py-1 rounded-full mr2">
    image: {data.labels && data.labels[1] ? data.labels[1] : '—'}
    </span>
    <span className="pipeline-badge bg-gray-100 text-gray-700 text-xs px-2 py-1 rounded-full mr2">
    terraform: {data.labels && data.labels[2] ? data.labels[2] : '—'}
    </span>
    <span className="pipeline-badge bg-gray-100 text-gray-700 text-xs px-2 py-1 rounded-full mr2">
    type: {data.labels && data.labels[3] ? data.labels[3] : '—'}
    </span>
    </div>
    </div>
    <div className="border-t border-gray-200 p-4">
    <h4 className="text-sm font-medium text-gray-700 mb-2">Run Queue</h4>
    {data.queue.length > 0 ? (
      <>
      {data.queue.map((item, idx) => (
        <div key={idx} className="flex items-center p-2 bg-gray-50 rounded mb-1">
        <div className={`material-symbols-outlined v-mid ${data.queueIconClass || 'purple'} b`}>
        {data.queueIcon || 'flaky'}
        </div>
        <span className="text-sm ml2">{item}</span>
        </div>
      ))}
      </>
    ) : (
      <div className="text-sm text-gray-500 italic">No items in queue</div>
    )}
    </div>
    <CustomBarHandle type="target" position={Position.Left} />
    <CustomBarHandle type="source" position={Position.Right} />
    </div>
  );
});

// Custom integration component for GitHub repository
const GitHubIntegration = ({ data, selected }) => {
  // Select header color and icon based on integrationType
  const isKubernetes = data.integrationType === 'kubernetes';
  const isS3 = data.repoName === 'buckets/my-app-data';
  // Add white shadow style
  const nodeStyle = {
    boxShadow: '0 4px 12px rgba(128,128,128,0.20)' // White shadow
  };
  
  return (
    <div className={`bg-white roundedg border ${selected ? 'ring-2 ring-blue-500' : 'border-gray-200'}`} style={nodeStyle}>
    <Handle 
    type="target" 
    position={Position.Left} 
    style={{ background: isKubernetes ? '#2563eb' : '#000', width: 10, height: 10 }} 
    />
    <div className={`flex items-center p-3 ${isKubernetes ? 'bg-blue-600' : isS3 ? 'bg-gray-200' : 'bg-[#24292e]'} ${isKubernetes || isS3 ? 'white' : 'black'} rounded-tg`}>
    <span className="mr-2">
    {isKubernetes ? (
      // Kubernetes SVG icon
      <svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMidYMid" viewBox="0 0 256 249" width="24" height="24"><path fill="#ffffff" d="M82.085 244.934c-5.946 0-11.561-2.642-15.36-7.432L8.92 165.657c-3.799-4.79-5.285-10.9-3.799-16.847l20.645-89.682c1.321-5.946 5.285-10.736 10.736-13.378l83.571-39.97c2.643-1.32 5.616-1.981 8.589-1.981 2.973 0 5.945.66 8.588 1.982l83.572 39.804c5.45 2.642 9.414 7.432 10.735 13.378l20.645 89.682c1.322 5.946 0 12.057-3.798 16.847l-57.807 71.845c-3.799 4.624-9.414 7.432-15.36 7.432l-93.15.165z" class="color326DE6 svgShape"/><path fill="#000000" d="M128.495 7.928c2.313 0 4.625.495 6.772 1.486l83.572 39.804c4.294 2.147 7.597 6.111 8.588 10.736l20.645 89.682c1.156 4.79 0 9.745-3.138 13.543l-57.806 71.846c-2.973 3.798-7.598 5.945-12.387 5.945H82.085c-4.79 0-9.414-2.147-12.387-5.945l-57.806-71.846c-2.973-3.798-4.13-8.753-3.138-13.543l20.645-89.682c1.156-4.79 4.294-8.754 8.588-10.736L121.56 9.25c2.147-.826 4.624-1.321 6.936-1.321zm0-7.763c-3.468 0-6.936.826-10.24 2.312l-83.571 39.97c-6.607 3.138-11.231 8.918-12.883 16.02L1.156 148.15c-1.651 7.102 0 14.369 4.625 20.15l57.806 71.845c4.46 5.615 11.231 8.753 18.333 8.753h92.655c7.102 0 13.874-3.138 18.333-8.753l57.807-71.846c4.624-5.615 6.276-13.047 4.624-20.15l-20.645-89.682c-1.651-7.102-6.276-12.882-12.882-16.02L138.57 2.476C135.432.991 131.964.165 128.495.165z" class="colorFFF svgShape"/><path fill="#000000" d="M212.232 142.534c-.165 0-.165 0 0 0h-.165c-.165 0-.33 0-.33-.165-.33 0-.66-.165-.991-.165-1.156-.165-2.147-.33-3.138-.33-.496 0-.991 0-1.652-.166h-.165c-3.468-.33-6.276-.66-8.919-1.486-1.156-.496-1.486-1.156-1.817-1.817 0-.165-.165-.165-.165-.33l-2.147-.66a65.33 65.33 0 0 0-1.156-23.289 68.054 68.054 0 0 0-9.249-21.636l1.652-1.486v-.33c0-.826.165-1.652.825-2.478 1.982-1.817 4.46-3.303 7.433-5.12.495-.33.99-.495 1.486-.826.991-.495 1.817-.99 2.808-1.651.165-.165.495-.33.826-.66.165-.166.33-.166.33-.331 2.312-1.982 2.808-5.285 1.156-7.433-.826-1.156-2.312-1.816-3.799-1.816-1.32 0-2.477.495-3.633 1.321l-.33.33c-.33.165-.496.496-.826.661-.826.826-1.487 1.486-2.147 2.312-.33.33-.66.826-1.156 1.156-2.313 2.478-4.46 4.46-6.607 5.946-.495.33-.99.496-1.486.496-.33 0-.661 0-.991-.166h-.33l-1.983 1.322c-2.147-2.312-4.459-4.294-6.771-6.276a65.958 65.958 0 0 0-34.519-13.709l-.165-2.147-.33-.33c-.496-.496-1.156-.991-1.322-2.147-.165-2.643.166-5.616.496-8.919v-.165c0-.496.165-1.156.33-1.652.165-.99.33-1.982.496-3.138v-1.486c0-2.973-2.313-5.45-5.12-5.45-1.322 0-2.643.66-3.634 1.651-.99.991-1.486 2.312-1.486 3.799v1.321c0 1.156.165 2.147.495 3.138.165.496.165.991.33 1.652v.165c.33 3.303.826 6.276.496 8.919-.165 1.156-.826 1.651-1.321 2.147l-.33.33-.166 2.147c-2.973.33-5.946.66-8.919 1.321-12.717 2.808-23.948 9.25-32.701 18.498l-1.652-1.156h-.33c-.33 0-.661.165-.991.165-.496 0-.991-.165-1.487-.495-2.147-1.486-4.294-3.634-6.606-6.111-.33-.33-.66-.826-1.156-1.156-.661-.826-1.322-1.487-2.148-2.312-.165-.166-.495-.33-.825-.661-.165-.165-.33-.165-.33-.33a5.772 5.772 0 0 0-3.634-1.322c-1.487 0-2.973.661-3.799 1.817-1.652 2.147-1.156 5.45 1.156 7.432.165 0 .165.166.33.166.33.165.496.495.826.66.991.66 1.817 1.156 2.808 1.652.496.165.991.495 1.487.826 2.972 1.816 5.45 3.303 7.432 5.12.826.825.826 1.651.826 2.477v.33l1.651 1.487c-.33.495-.66.826-.826 1.321-8.258 13.048-11.396 28.408-9.249 43.603l-2.147.66c0 .166-.165.166-.165.33-.33.661-.826 1.322-1.817 1.817-2.477.826-5.45 1.157-8.918 1.487h-.166c-.495 0-1.156 0-1.651.165-.991 0-1.982.165-3.138.33-.33 0-.66.166-.991.166-.165 0-.33 0-.496.165-2.973.66-4.79 3.468-4.294 6.11.496 2.313 2.643 3.8 5.285 3.8.496 0 .826 0 1.322-.166.165 0 .33 0 .33-.165.33 0 .66-.165.99-.165 1.157-.33 1.983-.66 2.974-1.156.495-.165.99-.496 1.486-.66h.165c3.138-1.157 5.946-2.148 8.589-2.478h.33c.991 0 1.652.495 2.147.826.165 0 .165.165.33.165l2.313-.33c3.964 12.221 11.561 23.122 21.636 31.05 2.312 1.816 4.624 3.303 7.102 4.79l-.991 2.146c0 .166.165.166.165.33.33.661.66 1.487.33 2.643-.99 2.478-2.477 4.955-4.294 7.763v.165c-.33.496-.66.826-.99 1.321-.661.826-1.157 1.652-1.818 2.643-.165.165-.33.495-.495.826 0 .165-.165.33-.165.33-1.321 2.808-.33 5.946 2.147 7.102.66.33 1.321.496 1.982.496 1.982 0 3.964-1.322 4.955-3.139 0-.165.165-.33.165-.33.165-.33.33-.66.495-.826.496-1.156.661-1.982.991-2.973l.496-1.486c1.156-3.303 1.982-5.946 3.468-8.258.66-.991 1.487-1.156 2.147-1.487.165 0 .165 0 .33-.165l1.157-2.147c7.267 2.808 15.195 4.294 23.122 4.294 4.79 0 9.745-.495 14.37-1.651a73.402 73.402 0 0 0 8.588-2.478l.99 1.817c.166 0 .166 0 .331.165.826.165 1.486.496 2.147 1.487 1.321 2.312 2.312 5.12 3.468 8.258v.165l.496 1.486c.33.991.495 1.982.99 2.973.166.33.331.496.496.826 0 .165.166.33.166.33.99 1.982 2.972 3.139 4.954 3.139.661 0 1.322-.166 1.982-.496 1.156-.66 2.147-1.652 2.478-2.973.33-1.321.33-2.808-.33-4.129 0-.165-.166-.165-.166-.33-.165-.33-.33-.66-.495-.826-.496-.991-1.156-1.817-1.817-2.643-.33-.495-.66-.825-.99-1.32v-.166c-1.818-2.808-3.47-5.285-4.295-7.763-.33-1.156 0-1.816.165-2.642 0-.165.165-.165.165-.33l-.826-1.982c8.754-5.12 16.186-12.388 21.802-21.306 2.973-4.625 5.285-9.745 6.936-14.865l1.982.33c.166 0 .166-.165.33-.165.661-.33 1.157-.825 2.148-.825h.33c2.643.33 5.45 1.32 8.589 2.477h.165c.495.165.99.495 1.486.66.991.496 1.817.826 2.973 1.157.33 0 .66.165.991.165.165 0 .33 0 .495.165.496.165.826.165 1.322.165 2.477 0 4.624-1.651 5.285-3.798 0-1.982-1.817-4.625-4.79-5.45zm-76.47-8.093l-7.267 3.469-7.267-3.469-1.816-7.762 4.954-6.276h8.093l4.955 6.276-1.651 7.762zm43.108-17.176a52.078 52.078 0 0 1 1.156 16.68l-25.27-7.266c-2.312-.66-3.633-2.973-3.138-5.285.165-.661.496-1.322.991-1.817l19.985-18.003c2.807 4.625 4.954 9.91 6.276 15.69zm-14.204-25.6l-21.636 15.36c-1.817 1.156-4.295.825-5.781-.991-.495-.496-.66-1.157-.826-1.817l-1.486-26.922a50.13 50.13 0 0 1 29.729 14.37zM116.769 78.12c1.817-.33 3.468-.66 5.285-.99l-1.486 26.425c-.165 2.312-1.982 4.294-4.46 4.294-.66 0-1.486-.165-1.982-.495L92.16 91.665c6.772-6.772 15.195-11.397 24.609-13.544zm-32.537 23.453l19.654 17.507c1.817 1.487 1.982 4.294.496 6.111-.496.66-1.156 1.156-1.982 1.322l-25.6 7.432c-.991-11.231 1.486-22.627 7.432-32.372zm-4.46 44.759l26.262-4.46c2.147-.165 4.129 1.322 4.624 3.469.165.99.165 1.817-.165 2.643l-10.075 24.278c-9.249-5.946-16.681-15.03-20.645-25.93zm60.285 32.867c-3.799.826-7.598 1.321-11.562 1.321-5.78 0-11.396-.99-16.68-2.642l13.047-23.618c1.321-1.487 3.468-2.147 5.285-1.156a7.04 7.04 0 0 1 1.982 1.816l12.717 22.958c-1.486.495-3.138.826-4.79 1.321zm32.206-22.957c-4.129 6.606-9.58 11.891-15.855 16.02l-10.405-24.94c-.496-1.981.33-4.128 2.312-5.12.66-.33 1.486-.495 2.312-.495l26.426 4.46c-.991 3.633-2.643 6.937-4.79 10.075z" class="colorFFF svgShape"/></svg>
    ) : isS3 ? (
      // Placeholder SVG for S3 icon
      <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" id="bucket">
      <path d="M17 22H3c-.5 0-.9-.4-1-.9l-2-18c0-.3.1-.6.2-.8.2-.2.5-.3.8-.3h18c.3 0 .6.1.7.3.2.2.3.5.3.8l-2 18c-.1.5-.5.9-1 .9zM3.9 20h12.2l1.8-16H2.1l1.8 16z"></path>
      <path d="M22.3 15.6c-.9 0-2.3-.4-4.9-1.8-1.7-.9-3.8-2.2-6.3-3.8-1-.7-1.7-1.1-1.7-1.1-.4-.4-.5-1-.2-1.5s.9-.6 1.4-.3c0 0 .6.4 1.6 1.1.9.6 3.7 2.4 6.2 3.7 2 1.1 3 1.4 3.5 1.5-.3-.9-1.5-2.4-4.1-4.4-.4-.3-.5-1-.2-1.4.3-.4 1-.5 1.4-.2 3.4 2.6 5 4.7 5 6.4 0 .6-.3 1.1-.7 1.4-.3.3-.6.4-1 .4z"></path>
      <circle cx="10" cy="8" r="2"></circle>
      <path d="M10 10.5c-1.4 0-2.5-1.1-2.5-2.5S8.6 5.5 10 5.5s2.5 1.1 2.5 2.5-1.1 2.5-2.5 2.5zm0-4c-.8 0-1.5.7-1.5 1.5s.7 1.5 1.5 1.5 1.5-.7 1.5-1.5-.7-1.5-1.5-1.5z"></path>
      </svg>
    ) : (
      // GitHub SVG icon
      <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 48 48" width="24" height="24"><rect width="48" height="48" fill="#ffffff" rx="24" class="color000 svgShape"/><path fill="#000000" fill-rule="evenodd" d="M31.4225 46.8287C29.0849 47.589 26.5901 48 24 48C21.4081 48 18.9118 47.5884 16.5728 46.8272C17.6533 46.9567 18.0525 46.2532 18.0525 45.6458C18.0525 45.3814 18.048 44.915 18.0419 44.2911C18.035 43.5692 18.0259 42.6364 18.0195 41.5615C11.343 43.0129 9.9345 38.3418 9.9345 38.3418C8.844 35.568 7.2705 34.8294 7.2705 34.8294C5.091 33.3388 7.4355 33.369 7.4355 33.369C9.843 33.5387 11.1105 35.8442 11.1105 35.8442C13.2525 39.5144 16.728 38.4547 18.096 37.8391C18.3135 36.2871 18.9345 35.2286 19.62 34.6283C14.2905 34.022 8.688 31.9625 8.688 22.7597C8.688 20.1373 9.6225 17.994 11.1585 16.3142C10.911 15.7065 10.0875 13.2657 11.3925 9.95888C11.3925 9.95888 13.4085 9.31336 17.9925 12.4206C19.908 11.8876 21.96 11.6222 24.0015 11.6114C26.04 11.6218 28.0935 11.8876 30.0105 12.4206C34.5915 9.31336 36.603 9.95888 36.603 9.95888C37.9125 13.2657 37.089 15.7065 36.8415 16.3142C38.3805 17.994 39.309 20.1373 39.309 22.7597C39.309 31.9849 33.6975 34.0161 28.3515 34.6104C29.2125 35.3519 29.9805 36.8168 29.9805 39.058C29.9805 41.2049 29.9671 43.0739 29.9582 44.3125C29.9538 44.9261 29.9505 45.385 29.9505 45.6462C29.9505 46.2564 30.3401 46.9613 31.4225 46.8287Z" clip-rule="evenodd" class="colorfff svgShape"/></svg>
    )}
    </span>
    <span className={`font-semibold text-base ${isKubernetes ? 'white' : isS3 ? 'black' : 'white'}`}>
    {isKubernetes ? 'prod-cluster' : data.repoName}
    </span>
    </div>
    <div className="repo-info">
    <div className="mb-2">
    <a href={data.repoUrl} target="_blank" rel="noopener noreferrer" className="repo-link text-blue-600 underline">
    {data.repoUrl}
    </a>
    </div>
    <div className="event-details">
    <div className="event-type">
    <span className="text-sm text-gray-600">{isKubernetes ? 'Service:' : isS3 ? 'Event:' : 'Event:'}</span>
    <span className="text-sm font-medium">{isKubernetes ? data.lastEvent.type : isS3 ? 'Tags Added' : data.lastEvent.type}</span>
    </div>
    <div className="event-release">
    <span className="text-sm text-gray-600">{isKubernetes ? 'Event:' : isS3 ? 'Object:' : 'Release:'}</span>
    <span className="text-sm font-medium">{isKubernetes ? data.lastEvent.release : isS3 ? 'my-app.tgz' : data.lastEvent.release}</span>
    </div>
    <div className="event-timestamp">
    <span className="text-sm text-gray-600">Timestamp:</span>
    <span className="text-sm font-medium">{data.lastEvent.timestamp}</span>
    </div>
    </div>
    </div>
    <Handle 
    type="source" 
    position={Position.Right} 
    style={{ background: isKubernetes ? '#2563eb' : '#000', width: 10, height: 10 }} 
    />
    </div>
  );
};

// Sidebar component to display selected stage details
const Sidebar = React.memo(({ selectedStage, onClose }) => {
  const [activeTab, setActiveTab] = useState('general');
  const [width, setWidth] = useState(600);
  const isDragging = useRef(false);
  const sidebarRef = useRef(null);
  const animationFrameRef = useRef(null);
  
  // Sidebar tab definitions - memoized to prevent unnecessary re-renders
  const tabs = React.useMemo(() => [
    { key: 'general', label: 'General' },
    { key: 'history', label: 'History' },
    { key: 'queue', label: 'Queue' },
    { key: 'settings', label: 'Settings' },
  ], []);
  
  // Cleanup function for animation frame and event listeners
  React.useEffect(() => {
    return () => {
      if (animationFrameRef.current) {
        cancelAnimationFrame(animationFrameRef.current);
      }
      document.removeEventListener('mousemove', handleMouseMove);
      document.removeEventListener('mouseup', handleMouseUp);
    };
  }, []);
  
  // Handle mouse down on resize handle - memoized to prevent recreation on each render
  const handleMouseDown = React.useCallback((e) => {
    isDragging.current = true;
    document.body.style.cursor = 'ew-resize';
    document.addEventListener('mousemove', handleMouseMove);
    document.addEventListener('mouseup', handleMouseUp);
  }, []);
  
  // Handle mouse move during resize - memoized with dependencies
  const handleMouseMove = React.useCallback((e) => {
    if (!isDragging.current) return;
    // Cancel any pending animation frame to prevent queuing multiple updates
    if (animationFrameRef.current) {
      cancelAnimationFrame(animationFrameRef.current);
    }
    
    // Schedule width update in next animation frame to prevent layout thrashing
    animationFrameRef.current = requestAnimationFrame(() => {
      const newWidth = Math.max(300, Math.min(800, window.innerWidth - e.clientX));
      setWidth(newWidth);
      animationFrameRef.current = null;
    });
  }, []);
  
  // Handle mouse up to stop resizing - memoized to prevent recreation
  const handleMouseUp = React.useCallback(() => {
    isDragging.current = false;
    document.body.style.cursor = '';
    document.removeEventListener('mousemove', handleMouseMove);
    document.removeEventListener('mouseup', handleMouseUp);
  }, []);
  
  // Render the appropriate content based on the active tab
  const renderTabContent = () => {
    switch (activeTab) {
      case 'general':
      return (
        <div className="pv3 ph4">
        
        <h2 className="f4 mb0">Run History</h2>
        <p className="mb3">A record of recent executions for this stage.</p>
        
        {/* Latest Run */}
        <div className="bg-white shadow-1 mv3 ph3 pv2 br3 wf-insights-selected">
        <div className="flex pv1">
        <div className="w-60 mb2 mb1">
        <div className="flex">
        <div className="flex-auto">
        <div className="flex">
        <img src={icnCommit} className="mt1 mr2" />
        <a href="workflow.html" className="word-wrap">FEAT-381: Edit email form on profile</a>
        </div>
        <div className="f5 overflow-auto nowrap mt1">
        <div className="flex items-center">
        <img src={faviconPinned} alt="Favicon" className="h1 w1 mr2" />
        <a href="workflow.html" className="link db flex-shrink-0 f6 w3 tc white mr2 ba br2 bg-indigo">Running</a>
        <a href="workflow.html" className="link dark-gray underline-hover">Stage Deployment ⋮ <code className="f5 gray">06:23</code></a>
        </div>
        </div>
        </div>
        </div>
        </div>
        <div className="w-40">
        <div className="flex flex-row-reverse items-center">
        <img src={require("./images/profile-3.jpg")} width="32" height="32" className="db br-100 ba b--black-50" />
        <div className="f5 gray ml2 ml3-m ml0 mr3 tr">8 minutes ago <br /> by shiroyasha</div>
        </div>
        </div>
        </div>
        
        <div className="flex">
        <span className="bg-gray-100 text-gray-700 text-xs px-2 py-1 rounded-full mr2 pipeline-badge"> code: 1045a77</span>
        <span className="bg-gray-100 text-gray-700 text-xs px-2 py-1 rounded-full mr2 pipeline-badge">image: v.4.1.3</span>
        <span className="bg-gray-100 text-gray-700 text-xs px-2 py-1 rounded-full mr2 pipeline-badge ba b--black-50 bw1">terraform: v.2.3.1</span>
        <span className="bg-gray-100 text-gray-700 text-xs px-2 py-1 rounded-full mr2 pipeline-badge">type: community</span>
        </div>
        </div>
        
        
        
        <div className="bg-white shadow-1 mv3 ph3 pv2 br3">
        <div className="flex pv1">
        <div className="w-60 mb2 mb1">
        <div className="flex">
        <div className="flex-auto">
        <div className="flex">
        <img src={icnCommit} className="mt1 mr2" />
        <a href="workflow.html" className="measure truncate">BUG-633: Routing error on workflow edit when users are</a>
        </div>
        <div className="f5 overflow-auto nowrap mt1">
        <div className="flex items-center">
        <img src={faviconPinned} alt="Favicon" className="h1 w1 mr2" />
        <a href="workflow.html" className="link db flex-shrink-0 f6 w3 tc white mr2 ba br2 bg-green">Passed</a>
        <a href="workflow.html" className="link dark-gray underline-hover">Stage Deployment ⋮ <code className="f5 gray">06:23</code></a>
        </div>
        </div>
        </div>
        </div>
        </div>
        <div className="w-40">
        <div className="flex flex-row-reverse items-center">
        <img src={require("./images/profile-2.jpg")} width="32" height="32" className="db br-100 ba b--black-50" />
        <div className="f5 gray ml2 ml3-m ml0 mr3 tr">11:03 - Mar 13<br /> by Hats Poler</div>
        </div>
        </div>
        </div>
        <div className="flex">
        <span className="bg-gray-100 text-gray-700 text-xs px-2 py-1 rounded-full mr2 pipeline-badge"> code: 1045a77</span>
        <span className="bg-gray-100 text-gray-700 text-xs px-2 py-1 rounded-full mr2 pipeline-badge ba b--black-50 bw1">image: v.4.1.3</span>
        <span className="bg-gray-100 text-gray-700 text-xs px-2 py-1 rounded-full mr2 pipeline-badge">terraform: v.2.1.1</span>
        <span className="bg-gray-100 text-gray-700 text-xs px-2 py-1 rounded-full mr2 pipeline-badge">type: enterprise</span>
        </div>
        </div>
        
        {/* Queue Section*/}
        <div className="pv3 bt b-ighter-gray">
        <h2 className="f4 mb0">Queue</h2>
        <p className="mb3">Runs that are waiting to be approved or triggered.</p>
        
        <div className="flex-m mv3">
        <div className="w4">
        <div className="f5 gray pt1">May 5, 2020</div>
        </div>
        <div className="flex items-center w-full">
        {/* Section 1: Status icon (example: done_all) */}
        <div className="flex items-center justify-center">
        <div className="mr3 br-100 ba b--orange bw1 tc" style={{ width: '32px', height: '32px' }}>
        <div className="material-symbols-outlined v-mid orange b">more_horiz</div>
        </div>
        </div>
        {/* Section 2: Commit info and badges */}
        <div className="w-70">
        <div className="flex items-center">
        <span className="material-symbols-outlined b f4 v-mid">commit</span>
        <a href="#" className="truncate ml2">BUG-634: Add Cucumber Tests</a>
        </div>
        <div className="flex">
        <span className="bg-gray-100 text-gray-700 text-xs px-2 py-1 rounded-full mr2 pipeline-badge">code: 1045a77</span>
        <span className="bg-gray-100 text-gray-700 text-xs px-2 py-1 rounded-full mr2 pipeline-badge ba b--black-50 bw1">image: v.4.2.0</span>
        <span className="text-xs px-2 py-1 rounded-full mr2 pipeline-badge cursor-pointer bg-gray-100 text-gray-700 hover:bg-gray-200 transition">+2 more</span>
        </div>
        </div>
        {/* Section 3: Action icons right-aligned */}
        <div className="w-1/4 flex items-center justify-end">
        <Tippy content="This run is waiting for the currently running one to finish.">
        <span className="text-xs px-2 py-1 rounded-full mr2 pipeline-badge cursor-pointer bg-gray-100 text-gray-700 hover:bg-gray-200 transition">queued</span>
        </Tippy>
        <Tippy content="Cancel and skip this run.">
        <span className="material-symbols-outlined mr1 pointer gray hover-black">cancel</span>
        </Tippy>
        </div>
        </div>
        </div>
        
        
        <div className="flex-m mv3">
        <div className="w4">
        <div className="f5 gray pt1">June 23, 2023</div>
        </div>
        <div className="flex items-center w-full">
        {/* Section 1: Flaky icon */}
        <div className="flex items-center justify-center">
        <div className="mr3 br-100 ba b--orange bw1 tc" style={{ width: '32px', height: '32px' }}>
        <div className="material-symbols-outlined v-mid orange b">timer</div>
        </div>
        </div>
        {/* Section 2: Commit info and badges */}
        <div className="w-70">
        <div className="flex items-center">
        <span className="material-symbols-outlined b f4 v-mid">commit</span>
        <a href="#" className="truncate ml2">BUG-633: Routing error on workflow edit when users are</a>
        </div>
        <div className="flex">
        <span className="bg-gray-100 text-gray-700 text-xs px-2 py-1 rounded-full mr2 pipeline-badge ba b--black-50 bw1">code: 1045a77</span>
        <span className="bg-gray-100 text-gray-700 text-xs px-2 py-1 rounded-full mr2 pipeline-badge">image: v.4.1.6</span>
        <span className="text-xs px-2 py-1 rounded-full mr2 pipeline-badge cursor-pointer bg-gray-100 text-gray-700 hover:bg-gray-200 transition">+2 more</span>
        </div>
        </div>
        {/* Section 3: Action icons right-aligned */}
        <div className="w-1/4 flex items-center justify-end">
        <Tippy content="This run will start in 23 hours and 12 minutes.">
        <span className="text-xs px-2 py-1 rounded-full mr2 pipeline-badge cursor-pointer bg-gray-100 text-gray-700 hover:bg-gray-200 transition">23h left</span>
        </Tippy>
        <Tippy content="Cancel and skip this run.">
        <span className="material-symbols-outlined mr1 pointer gray hover-black">cancel</span>
        </Tippy>
        </div>
        </div>
        </div>
        
        
        <div className="flex-m mv3">
        <div className="w4">
        <div className="f5 gray pt1">May 5, 2020</div>
        </div>
        <div className="flex items-center w-full">
        {/* Section 1: Status icon (example: done_all) */}
        <div className="flex items-center justify-center">
        <div className="mr3 br-100 ba b--purple bw1 tc" style={{ width: '32px', height: '32px' }}>
        <div className="material-symbols-outlined v-mid purple b">flaky</div>
        </div>
        </div>
        {/* Section 2: Commit info and badges */}
        <div className="w-70">
        <div className="flex items-center">
        <span className="material-symbols-outlined b f4 v-mid">commit</span>
        <a href="#" className="truncate ml2">FEAT-211: Partially rebuild pipeline</a>
        </div>
        <div className="flex">
        <span className="bg-gray-100 text-gray-700 text-xs px-2 py-1 rounded-full mr2 pipeline-badge ba b--black-50 bw1">code: 1a2b3c4</span>
        <span className="bg-gray-100 text-gray-700 text-xs px-2 py-1 rounded-full mr2 pipeline-badge">image: v.4.1.6</span>
        <span className="text-xs px-2 py-1 rounded-full mr2 pipeline-badge cursor-pointer bg-gray-100 text-gray-700 hover:bg-gray-200 transition">+2 more</span>
        </div>
        </div>
        {/* Section 3: Action icons right-aligned */}
        <div className="w-1/4 flex items-center justify-end">
        <Tippy content="Approve and start this run.">
        <span className="material-symbols-outlined mr1 pointer gray hover-black">check_circle</span>
        </Tippy>
        <Tippy content="Cancel and skip this run.">
        <span className="material-symbols-outlined mr1 pointer gray hover-black">cancel</span>
        </Tippy>
        </div>
        </div>
        </div>
        </div>
        
        {/* Inputs Section */}
        <div className="pv3 bt b-ighter-gray">
        <h2 className="f4 mb0">Inputs</h2>
        <p className="mb3">Runs that are waiting to be approved or triggered.</p>
        </div>
        </div>
      );
      
      case 'history':
      return (
        <div className="pv3 ph4">
        
        <h2 className="f4 mb0">Run History</h2>
        <p className="mb3">A record of recent executions for this stage.</p>
        
        {/* Randomized history runs for visual variety */}
        <div className="bg-white shadow-1 mv3 ph3 pv2 br3">
        <div className="flex pv1">
        <div className="w-60 mb2 mb1">
        <div className="flex">
        <div className="flex-auto">
        <div className="flex">
        <img src={icnCommit} className="mt1 mr2" />
        <a href="workflow.html" className="measure truncate">FEAT-202: Add logging to API</a>
        </div>
        <div className="f5 overflow-auto nowrap mt1">
        <div className="flex items-center">
        <img src={faviconPinned} alt="Favicon" className="h1 w1 mr2" />
        <a href="workflow.html" className="link db flex-shrink-0 f6 w3 tc white mr2 ba br2 bg-green">Passed</a>
        <a href="workflow.html" className="link dark-gray underline-hover">Stage Deployment ⋮ <code className="f5 gray">09:12</code></a>
        </div>
        </div>
        </div>
        </div>
        </div>
        <div className="w-40">
        <div className="flex flex-row-reverse items-center">
        <img src={require("./images/profile-3.jpg")} width="32" height="32" className="db br-100 ba b--black-50" />
        <div className="f5 gray ml2 ml3-m ml0 mr3 tr">Today, 09:12<br /> by Alex Green</div>
        </div>
        </div>
        </div>
        <div className="flex">
        <span className="bg-gray-100 text-gray-700 text-xs px-2 py-1 rounded-full mr2 pipeline-badge"> code: 2d4e6f8</span>
        <span className="bg-gray-100 text-gray-700 text-xs px-2 py-1 rounded-full mr2 pipeline-badge">image: v.4.1.4</span>
        <span className="bg-gray-100 text-gray-700 text-xs px-2 py-1 rounded-full mr2 pipeline-badge ba b--black-50 bw1">terraform: v.2.3.0</span>
        <span className="bg-gray-100 text-gray-700 text-xs px-2 py-1 rounded-full mr2 pipeline-badge">type: enterprise</span>
        </div>
        </div>
        <div className="bg-white shadow-1 mv3 ph3 pv2 br3">
        <div className="flex pv1">
        <div className="w-60 mb2 mb1">
        <div className="flex">
        <div className="flex-auto">
        <div className="flex">
        <img src={icnCommit} className="mt1 mr2" />
        <a href="workflow.html" className="measure truncate">FIX-555: Resolve memory leak</a>
        </div>
        <div className="f5 overflow-auto nowrap mt1">
        <div className="flex items-center">
        <img src={faviconPinned} alt="Favicon" className="h1 w1 mr2" />
        <a href="workflow.html" className="link db flex-shrink-0 f6 w3 tc white mr2 ba br2 bg-red">Failed</a>
        <a href="workflow.html" className="link dark-gray underline-hover">Stage Deployment ⋮ <code className="f5 gray">08:45</code></a>
        </div>
        </div>
        </div>
        </div>
        </div>
        <div className="w-40">
        <div className="flex flex-row-reverse items-center">
        <img src={require("./images/profile-2.jpg")} width="32" height="32" className="db br-100 ba b--black-50" />
        <div className="f5 gray ml2 ml3-m ml0 mr3 tr">Today, 08:45<br /> by Nina Petrova</div>
        </div>
        </div>
        </div>
        <div className="flex">
        <span className="bg-gray-100 text-gray-700 text-xs px-2 py-1 rounded-full mr2 pipeline-badge"> code: 3e5f7h9</span>
        <span className="bg-gray-100 text-gray-700 text-xs px-2 py-1 rounded-full mr2 pipeline-badge">image: v.4.1.5</span>
        <span className="bg-gray-100 text-gray-700 text-xs px-2 py-1 rounded-full mr2 pipeline-badge ba b--black-50 bw1">terraform: v.2.2.1</span>
        <span className="bg-gray-100 text-gray-700 text-xs px-2 py-1 rounded-full mr2 pipeline-badge">type: community</span>
        </div>
        </div>
        <div className="bg-white shadow-1 mv3 ph3 pv2 br3">
        <div className="flex pv1">
        <div className="w-60 mb2 mb1">
        <div className="flex">
        <div className="flex-auto">
        <div className="flex">
        <img src={icnCommit} className="mt1 mr2" />
        <a href="workflow.html" className="measure truncate">DOCS-777: Update README.md</a>
        </div>
        <div className="f5 overflow-auto nowrap mt1">
        <div className="flex items-center">
        <img src={faviconPinned} alt="Favicon" className="h1 w1 mr2" />
        <a href="workflow.html" className="link db flex-shrink-0 f6 w3 tc white mr2 ba br2 bg-green">Passed</a>
        <a href="workflow.html" className="link dark-gray underline-hover">Stage Deployment ⋮ <code className="f5 gray">07:30</code></a>
        </div>
        </div>
        </div>
        </div>
        </div>
        <div className="w-40">
        <div className="flex flex-row-reverse items-center">
        <img src={require("./images/profile-3.jpg")} width="32" height="32" className="db br-100 ba b--black-50" />
        <div className="f5 gray ml2 ml3-m ml0 mr3 tr">Yesterday, 17:20<br /> by Marko Jovanovic</div>
        </div>
        </div>
        </div>
        <div className="flex">
        <span className="bg-gray-100 text-gray-700 text-xs px-2 py-1 rounded-full mr2 pipeline-badge"> code: 4f6g8h0</span>
        <span className="bg-gray-100 text-gray-700 text-xs px-2 py-1 rounded-full mr2 pipeline-badge">image: v.4.1.1</span>
        <span className="bg-gray-100 text-gray-700 text-xs px-2 py-1 rounded-full mr2 pipeline-badge ba b--black-50 bw1">terraform: v.2.1.0</span>
        <span className="bg-gray-100 text-gray-700 text-xs px-2 py-1 rounded-full mr2 pipeline-badge">type: docs</span>
        </div>
        </div>
        <div className="bg-white shadow-1 mv3 ph3 pv2 br3">
        <div className="flex pv1">
        <div className="w-60 mb2 mb1">
        <div className="flex">
        <div className="flex-auto">
        <div className="flex">
        <img src={icnCommit} className="mt1 mr2" />
        <a href="workflow.html" className="measure truncate">PERF-23: Load test improvements</a>
        </div>
        <div className="f5 overflow-auto nowrap mt1">
        <div className="flex items-center">
        <img src={faviconPinned} alt="Favicon" className="h1 w1 mr2" />
        <a href="workflow.html" className="link db flex-shrink-0 f6 w3 tc white mr2 ba br2 bg-green">Passed</a>
        <a href="workflow.html" className="link dark-gray underline-hover">Stage Deployment ⋮ <code className="f5 gray">06:55</code></a>
        </div>
        </div>
        </div>
        </div>
        </div>
        <div className="w-40">
        <div className="flex flex-row-reverse items-center">
        <img src={require("./images/profile-3.jpg")} width="32" height="32" className="db br-100 ba b--black-50" />
        <div className="f5 gray ml2 ml3-m ml0 mr3 tr">Yesterday, 12:10<br /> by Ana Milic</div>
        </div>
        </div>
        </div>
        <div className="flex">
        <span className="bg-gray-100 text-gray-700 text-xs px-2 py-1 rounded-full mr2 pipeline-badge"> code: 5j7k9l2</span>
        <span className="bg-gray-100 text-gray-700 text-xs px-2 py-1 rounded-full mr2 pipeline-badge">image: v.4.0.9</span>
        <span className="bg-gray-100 text-gray-700 text-xs px-2 py-1 rounded-full mr2 pipeline-badge ba b--black-50 bw1">terraform: v.2.0.9</span>
        <span className="bg-gray-100 text-gray-700 text-xs px-2 py-1 rounded-full mr2 pipeline-badge">type: perf</span>
        </div>
        </div>
        <div className="bg-white shadow-1 mv3 ph3 pv2 br3">
        <div className="flex pv1">
        <div className="w-60 mb2 mb1">
        <div className="flex">
        <div className="flex-auto">
        <div className="flex">
        <img src={icnCommit} className="mt1 mr2" />
        <a href="workflow.html" className="measure truncate">QA-72: Regression test suite</a>
        </div>
        <div className="f5 overflow-auto nowrap mt1">
        <div className="flex items-center">
        <img src={faviconPinned} alt="Favicon" className="h1 w1 mr2" />
        <a href="workflow.html" className="link db flex-shrink-0 f6 w3 tc white mr2 ba br2 bg-red">Failed</a>
        <a href="workflow.html" className="link dark-gray underline-hover">Stage Deployment ⋮ <code className="f5 gray">06:02</code></a>
        </div>
        </div>
        </div>
        </div>
        </div>
        <div className="w-40">
        <div className="flex flex-row-reverse items-center">
        <img src={require("./images/profile-4.jpg")} width="32" height="32" className="db br-100 ba b--black-50" />
        <div className="f5 gray ml2 ml3-m ml0 mr3 tr">Yesterday, 08:54<br /> by Jovana Simic</div>
        </div>
        </div>
        </div>
        <div className="flex">
        <span className="bg-gray-100 text-gray-700 text-xs px-2 py-1 rounded-full mr2 pipeline-badge"> code: 6m8n0p3</span>
        <span className="bg-gray-100 text-gray-700 text-xs px-2 py-1 rounded-full mr2 pipeline-badge">image: v.4.0.8</span>
        <span className="bg-gray-100 text-gray-700 text-xs px-2 py-1 rounded-full mr2 pipeline-badge ba b--black-50 bw1">terraform: v.2.0.8</span>
        <span className="bg-gray-100 text-gray-700 text-xs px-2 py-1 rounded-full mr2 pipeline-badge">type: qa</span>
        </div>
        </div>
        <div className="bg-white shadow-1 mv3 ph3 pv2 br3">
        <div className="flex pv1">
        <div className="w-60 mb2 mb1">
        <div className="flex">
        <div className="flex-auto">
        <div className="flex">
        <img src={icnCommit} className="mt1 mr2" />
        <a href="workflow.html" className="measure truncate">DB-44: Migrate to Postgres 15</a>
        </div>
        <div className="f5 overflow-auto nowrap mt1">
        <div className="flex items-center">
        <img src={faviconPinned} alt="Favicon" className="h1 w1 mr2" />
        <a href="workflow.html" className="link db flex-shrink-0 f6 w3 tc white mr2 ba br2 bg-green">Passed</a>
        <a href="workflow.html" className="link dark-gray underline-hover">Stage Deployment ⋮ <code className="f5 gray">05:43</code></a>
        </div>
        </div>
        </div>
        </div>
        </div>
        <div className="w-40">
        <div className="flex flex-row-reverse items-center">
        <img src={require("./images/profile-3.jpg")} width="32" height="32" className="db br-100 ba b--black-50" />
        <div className="f5 gray ml2 ml3-m ml0 mr3 tr">Yesterday, 07:30<br /> by Luka Stojanovic</div>
        </div>
        </div>
        </div>
        <div className="flex">
        <span className="bg-gray-100 text-gray-700 text-xs px-2 py-1 rounded-full mr2 pipeline-badge"> code: 7q9r1s4</span>
        <span className="bg-gray-100 text-gray-700 text-xs px-2 py-1 rounded-full mr2 pipeline-badge">image: v.4.0.7</span>
        <span className="bg-gray-100 text-gray-700 text-xs px-2 py-1 rounded-full mr2 pipeline-badge ba b--black-50 bw1">terraform: v.2.0.7</span>
        <span className="bg-gray-100 text-gray-700 text-xs px-2 py-1 rounded-full mr2 pipeline-badge">type: db</span>
        </div>
        </div>
        
        </div>
      );
      
      case 'queue':
      return (
        <div className="pv3 ph4">
        <h3 className="textg font-semibold mb-3">Queue</h3>
        <div className="deployment-queue">
        <div className="queue-item">
        <span className="queue-icon">⏳</span>
        <span>Feature: Add user authentication</span>
        </div>
        <div className="queue-item">
        <span className="queue-icon">⏳</span>
        <span>Bugfix: Fix login redirect</span>
        </div>
        <div className="queue-more">
        <a href="#">View all queue</a>
        </div>
        </div>
        </div>
      );
      
      case 'settings':
      return (
        <div className="pv3 ph4">
        <h3 className="textg font-semibold mb-3">Settings</h3>
        <div className="settings-item">
        <span className="settingsabel">Stage Name</span>
        <span className="settings-value">{selectedStage.data.label}</span>
        </div>
        <div className="settings-item">
        <span className="settingsabel">Type</span>
        <span className="settings-value">{selectedStage.type === 'deploymentCard' ? 'Deployment Stage' : 'GitHub Integration'}</span>
        </div>
        <div className="settings-item">
        <span className="settingsabel">Status</span>
        <span className="settings-value">{selectedStage.data.status}</span>
        </div>
        </div>
      );
      
      default:
      return null;
    }
  };
  
  return (
    <aside
    ref={sidebarRef}
    className="sidebar"
    style={{
      width: width,
      minWidth: 300,
      maxWidth: 800,
      position: 'fixed',
      top: 0,
      right: 0,
      height: '100vh',
      zIndex: 10,
      boxShadow: 'rgba(0,0,0,0.07) -2px 0 12px',
      background: '#fff',
      transition: isDragging.current ? 'none' : 'width 0.2s',
      display: 'flex',
      flexDirection: 'column',
    }}
    >
    {/* Sidebar Header with Stage Name */}
    <div className="sidebar-header">
    <div className="sidebar-header-title flex items-center">
    {selectedStage.type === 'deploymentCard' ? (
      <span className="material-symbols-outlined mr1 pointer black b">{selectedStage.data.icon}</span>
    ) : (
      <svg viewBox="0 0 16 16" width="20" height="20" fill="currentColor">
      <path fillRule="evenodd" d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.01.08-2.11 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.11.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.19 0 .21.15.46.55.38A8.013 8.013 0 0016 8c0-4.42-3.58-8-8-8z"/>
      </svg>
    )}
    <span className="f4 b">{selectedStage.data.label}</span>
    </div>
    <button className="sidebar-close-button" onClick={onClose} title="Close sidebar">×</button>
    </div>
    
    {/* Sidebar Tabs */}
    <div className="sidebar-tabs">
    {tabs.map(tab => (
      <button
      key={tab.key}
      className={`tab-button${activeTab === tab.key ? ' active' : ''}`}
      onClick={() => setActiveTab(tab.key)}
      >
      {tab.label}
      </button>
    ))}
    </div>
    <div className="sidebar-content">
    {renderTabContent()}
    </div>
    
    
    {/* Resize Handle */}
    <div
    className="resize-handle"
    style={{
      width: 8,
      cursor: 'ew-resize',
      background: isDragging.current ? '#e0e0e0' : '#f0f0f0',
      position: 'absolute',
      left: 0,
      top: 0,
      bottom: 0,
      zIndex: 100,
      borderRadius: '4px',
      transition: 'background 0.2s',
    }}
    onMouseDown={handleMouseDown}
    onMouseEnter={() => { if (!isDragging.current) sidebarRef.current.style.cursor = 'ew-resize'; }}
    onMouseLeave={() => { if (!isDragging.current) sidebarRef.current.style.cursor = 'default'; }}
    />
    </aside>
  );
});

// Initial stages configuration
const chainLength = 5;
// Allow x/y for each stage in the new chain
const newChainStagePositions = [
  { x: -400, y: -730 }, // prod-cluster (Kubernetes Integration)
  { x: 100, y: -800 },  // Stage 1 (straight right)
  { x: 600, y: -1000 },  // Stage 2 (up and right, parallel)
  { x: 600, y: -600 },  // Stage 3 (down and right, parallel)
  { x: 1150, y: -800 }, // Stage 4 (centered between 2 and 3, further right)
];
const newChainStages = [
  {
    id: String(1000),
    type: 'githubIntegration',
    data: {
      repoName: 'prod-cluster',
      repoUrl: 'europe-west3-a/prod-cluster',
      lastEvent: {
        type: 'zebra',
        release: 'Updated, Endpoints Changed',
        timestamp: '2025-04-09 09:30 AM',
      },
      status: 'Idle',
      timestamp: 'Never run',
      labels: ['new123', 'v.0.1.0', 'integration'],
      queue: [],
      integrationType: 'kubernetes',
    },
    position: newChainStagePositions[0],
    style: { width: 320 },
  },
  {
    id: String(1001),
    type: 'deploymentCard',
    data: {
      icon: 'storage',
      label: 'Sync Cluster',
      status: 'Running',
      timestamp: 'Built 15 min ago',
      labels: ['docker', 'build', 'v.1.0.0'],
      queue: ['Build: Dockerfile', 'Push: Container Registry'],
      queueIcon: 'pending',
      queueIconClass: 'indigo',
    },
    position: newChainStagePositions[1],
    style: { width: 320 },
  },
  {
    id: String(1002),
    type: 'deploymentCard',
    data: {
      icon: 'cloud',
      label: 'Deploy to US cluster',
      status: 'Running',
      timestamp: 'Deploying now',
      labels: ['staging', 'v.1.0.0'],
      queue: ['Deploy: Helm Chart', 'Scale: Increase replicas'],
      queueIcon: 'pending',
      queueIconClass: 'indigo',
    },
    position: newChainStagePositions[2],
    style: { width: 320 },
  },
  {
    id: String(1003),
    type: 'deploymentCard',
    data: {
      icon: 'cloud_done',
      label: 'Deploy to Asia cluster',
      status: 'Passed',
      timestamp: 'Completed 10 min ago',
      labels: ['tests', 'integration', 'v.1.0.0'],
      queue: [],
      queueIcon: 'pending',
      queueIconClass: 'indigo',
    },
    position: newChainStagePositions[3],
    style: { width: 320 },
  },
  {
    id: String(1004),
    type: 'deploymentCard',
    data: {
      icon: 'cloud_done',
      label: 'Health Check & Cleanup',
      status: 'Failed',
      timestamp: 'Ready for deployment',
      labels: ['production', 'v.1.0.0'],
      queue: ['Deploy: Helm Chart'],
      queueIcon: 'flaky',
      queueIconClass: 'purple',
    },
    position: newChainStagePositions[4],
    style: { width: 320 },
  },
];
const newChainListeners = [];
// prod-cluster → Sync Cluster (1000 → 1001)
newChainListeners.push({
  id: 'e1000-1001',
  source: '1000',
  target: '1001',
  type: 'bezier',
  animated: true,
  style: { stroke: '#888', strokeDasharray: '6 4', strokeWidth: 2 },
  label: 'Promote to Sync Cluster',
  labelStyle: { fill: '#000', fontWeight: 500 },
  labelBgStyle: { fill: 'rgba(255, 255, 255, 0.9)', fillOpacity: 0.9 },
  markerEnd: { type: MarkerType.ArrowClosed },
});
// Sync Cluster → Deploy to US cluster (1001 → 1002)
newChainListeners.push({
  id: 'e1001-1002',
  source: '1001',
  target: '1002',
  type: 'bezier',
  animated: true,
  style: { stroke: '#888', strokeDasharray: '6 4', strokeWidth: 2 },
  label: 'Sync → US Cluster',
  labelStyle: { fill: '#000', fontWeight: 500 },
  labelBgStyle: { fill: 'rgba(255, 255, 255, 0.9)', fillOpacity: 0.9 },
  markerEnd: { type: MarkerType.ArrowClosed },
});
// Sync Cluster → Deploy to Asia cluster (1001 → 1003)
newChainListeners.push({
  id: 'e1001-1003',
  source: '1001',
  target: '1003',
  type: 'bezier',
  animated: false,
  style: { stroke: '#888', strokeWidth: 2 },
  label: 'Sync → Asia Cluster',
  labelStyle: { fill: '#000', fontWeight: 500 },
  labelBgStyle: { fill: 'rgba(255, 255, 255, 0.9)', fillOpacity: 0.9 },
  markerEnd: { type: MarkerType.ArrowClosed },
});
// US cluster → Health Check & Cleanup (1002 → 1004)
newChainListeners.push({
  id: 'e1002-1004',
  source: '1002',
  target: '1004',
  type: 'bezier',
  animated: false,
  style: { stroke: '#888', strokeWidth: 2 },
  label: 'US → Cleanup',
  labelStyle: { fill: '#000', fontWeight: 500 },
  labelBgStyle: { fill: 'rgba(255, 255, 255, 0.9)', fillOpacity: 0.9 },
  markerEnd: { type: MarkerType.ArrowClosed },
});
// Asia cluster → Health Check & Cleanup (1003 → 1004)
newChainListeners.push({
  id: 'e1003-1004',
  source: '1003',
  target: '1004',
  type: 'bezier',
  animated: false,
  style: { stroke: '#888', strokeWidth: 2 },
  label: 'Asia → Cleanup',
  labelStyle: { fill: '#000', fontWeight: 500 },
  labelBgStyle: { fill: 'rgba(255, 255, 255, 0.9)', fillOpacity: 0.9 },
  markerEnd: { type: MarkerType.ArrowClosed },
});

const initialStages = [
  // First workflow - Semaphore
  {
    id: '0',
    type: 'githubIntegration',
    data: { 
      repoName: 'semaphoreio/semaphore',
      repoUrl: 'https://github.com/semaphoreio/semaphore',
      lastEvent: {
        type: 'push',
        release: 'main',
        timestamp: '2025-04-09 09:30 AM'
      },
      status: 'Passed',
      timestamp: 'Deployed 2 hours ago',
      labels: ['1045a77', 'v.4.1.3', 'v.2.3.1', 'community'],
      queue: ['Feature: Add user authentication', 'Bugfix: Fix login redirect', 'Feature: Add dark mode'],
      queueIcon: 'flaky', // default icon
      queueIconClass: 'purple', // default color class
    },
    position: { x: -400, y: 159 },
    style: {
      width: 320,
    },
  },
  {
    id: '1',
    type: 'deploymentCard',
    data: { 
      icon: 'storage',
      label: 'Development Environment',
      status: 'Passed',
      timestamp: 'Deployed 2 hours ago',
      labels: ['1045a77', 'v.4.1.3', 'v.2.3.1', 'community'],
      queue: ['Feature: Add user authentication', 'Bugfix: Fix layout on mobile', 'Feature: Add dark mode'],
      queueIcon: 'flaky', // default icon
      queueIconClass: 'purple', // default color class
    },
    position: { x: 100, y: 77 },
    style: {
      width: 320,
    },
  },
  {
    id: '2',
    type: 'deploymentCard',
    data: { 
      icon: 'storage',
      label: 'Staging Environment',
      status: 'Passed',
      timestamp: 'Deployed just now',
      labels: ['7a9b23c', 'v.4.1.3', 'v.2.3.1', 'community'],
      queue: ['FEAT-312: Investigate flaky test'],
      queueIcon: 'flaky', // default icon
      queueIconClass: 'purple', // default color class
    },
    position: { x: 600, y: 122 },
    style: {
      width: 320,
    },
  },
  {
    id: '3',
    type: 'deploymentCard',
    data: { 
      icon: 'cloud',
      label: 'Production - US',
      status: 'Failed',
      timestamp: 'Failed just now',
      labels: ['5e3d12b', 'v.4.1.3', 'v.2.3.1', 'community'],
      queue: [
        'FEAT-400: Flaky test detected',
        'BUG-512: Flaky network error'
      ],
      queueIcon: 'flaky', // default icon
      queueIconClass: 'purple', // default color class
    },
    position: { x: 1150, y: -150 },
    style: {
      width: 320,
    },
  },
  {
    id: '5',
    type: 'deploymentCard',
    data: { 
      icon: 'cloud',
      label: 'Production - JP',
      status: 'Passed',
      timestamp: 'Deployed just now',
      labels: ['5e3d12b', 'v.4.1.3', 'v.2.3.1', 'community'],
      queue: ['FEAT-211: Partially rebuild pipeline'],
      queueIcon: 'timer', // orange timer icon
      queueIconClass: 'orange', // orange color class
    },
    position: { x: 1750, y: -128 },
    style: {
      width: 320,
    },
  },
  {
    id: '4',
    type: 'deploymentCard',
    data: { 
      icon: 'cloud',
      label: 'Production - EU',
      status: 'Running',
      timestamp: 'Deploying now',
      labels: ['5e3d12b', 'v.4.1.3', 'v.2.3.1', 'community'],
      queue: [],
      queueIcon: 'flaky', // default icon
      queueIconClass: 'purple', // default color class
    },
    position: { x: 1150, y: 450 },
    style: {
      width: 320,
    },
  },
  
  // Second workflow - Toolbox
  {
    id: '6',
    type: 'githubIntegration',
    data: { 
      repoName: 'buckets/my-app-data',
      repoUrl: 'https://s3.console.aws.amazon.com/s3/buckets/my-app-data',
      lastEvent: {
        type: 'push',
        release: 'main',
        timestamp: '2025-04-09 09:30 AM'
      },
      status: 'Passed',
      timestamp: 'Deployed 2 hours ago',
      labels: ['3e7a91d', 'v.4.1.3', 'v.2.3.1', 'community'],
      queue: ['Test: Integration tests', 'Test: Performance benchmarks'],
      queueIcon: 'flaky', // default icon
      queueIconClass: 'purple', // default color class
    },
    position: { x: -400, y: 888 },
    style: {
      width: 320,
    },
  },
  {
    id: '7',
    type: 'deploymentCard',
    data: { 
      icon: 'storage',
      label: 'Platform Test',
      status: 'Passed',
      timestamp: 'Completed 1 hour ago',
      labels: ['3e7a91d', 'v.4.1.3', 'v.2.3.1', 'community'],
      queue: ['Test: Integration tests', 'Test: Performance benchmarks'],
      queueIcon: 'flaky', // default icon
      queueIconClass: 'purple', // default color class
    },
    position: { x: 100, y: 827 },
    style: {
      width: 320,
    },
  },
  {
    id: '8',
    type: 'deploymentCard',
    data: { 
      icon: 'lan',
      label: 'Infra - Publish',
      status: 'Running',
      timestamp: 'Deploying now',
      labels: ['3e7a91d', 'v.4.1.3', 'v.2.3.1', 'community'],
      queue: [],
      queueIcon: 'flaky', // default icon
      queueIconClass: 'purple', // default color class
    },
    position: { x: 600, y: 860 },
    style: {
      width: 320,
    },
  },
  // New chain stages
  ...newChainStages,
];

// Initial listeners configuration - connecting the stages
const initialListeners = [
  // First workflow connections
  {
    id: 'e0-1',
    source: '0',
    target: '1',
    type: 'bezier',
    animated: false,
    label: 'Trigger Build',
    style: { stroke: '#888', strokeWidth: 2 },
    labelStyle: { fill: '#000', fontWeight: 500 },
    labelBgStyle: { fill: 'rgba(255, 255, 255, 0.9)', fillOpacity: 0.9 },
  },
  {
    id: 'e1-2',
    source: '1',
    target: '2',
    type: 'bezier',
    animated: false,
    label: 'Promote to Staging',
    style: { stroke: '#888', strokeWidth: 2 },
    labelStyle: { fill: '#000', fontWeight: 500 },
    labelBgStyle: { fill: 'rgba(255, 255, 255, 0.9)', fillOpacity: 0.9 },
  },
  {
    id: 'e2-3',
    source: '2',
    target: '3',
    type: 'bezier',
    animated: false,
    label: 'Promote to US',
    style: { stroke: '#888', strokeWidth: 2 },
    labelStyle: { fill: '#000', fontWeight: 500 },
    labelBgStyle: { fill: 'rgba(255, 255, 255, 0.9)', fillOpacity: 0.9 },
  },
  {
    id: 'e2-4',
    source: '2',
    target: '4',
    type: 'bezier',
    animated: true,
    label: 'Promote to EU',
    style: { stroke: '#888', strokeDasharray: '6 4', strokeWidth: 2 },
    labelStyle: { fill: '#000', fontWeight: 500 },
    labelBgStyle: { fill: 'rgba(255, 255, 255, 0.9)', fillOpacity: 0.9 },
  },
  {
    id: 'e3-5',
    source: '3',
    target: '5',
    type: 'bezier',
    animated: false,
    label: 'Promote to JP',
    style: { stroke: '#888', strokeWidth: 2 },
    labelStyle: { fill: '#000', fontWeight: 500 },
    labelBgStyle: { fill: 'rgba(255, 255, 255, 0.9)', fillOpacity: 0.9 },
  },
  
  // Second workflow connections
  {
    id: 'e6-7',
    source: '6',
    target: '7',
    type: 'bezier',
    animated: false,
    label: 'Run Tests',
    style: { stroke: '#888', strokeWidth: 2 },
    labelStyle: { fill: '#000', fontWeight: 500 },
    labelBgStyle: { fill: 'rgba(255, 255, 255, 0.9)', fillOpacity: 0.9 },
  },
  {
    id: 'e7-8',
    source: '7',
    target: '8',
    type: 'bezier',
    animated: true,
    label: 'Deploy to Production',
    style: { stroke: '#888', strokeDasharray: '6 4', strokeWidth: 2 },
    labelStyle: { fill: '#000', fontWeight: 500 },
    labelBgStyle: { fill: 'rgba(255, 255, 255, 0.9)', fillOpacity: 0.9 },
  },
  // New chain listeners
  ...newChainListeners,
];

function WorkflowEditor() {
  const [stages, setStages, onStagesChange] = useNodesState(initialStages);
  const [listeners, setListeners, onListenersChange] = useEdgesState(initialListeners);
  const [selectedStage, setSelectedStage] = useState(null);
  const [selectedEdge, setSelectedEdge] = useState(null);
  const [iconAction, setIconAction] = useState(null); 
  const [reactFlowInstance, setReactFlowInstance] = useState(null);
  
  const SIDEBAR_WIDTH = 400;
  
  // Handle stage deletion
  const handleDeleteStage = (stageId) => {
    // Remove the stage
    setStages((currentStages) => currentStages.filter(stage => stage.id !== stageId));
    
    // Remove any connections to/from this stage
    setListeners((currentListeners) => 
      currentListeners.filter(listener => 
        listener.source !== stageId && listener.target !== stageId
      )
    );
    
    // Close sidebar if the deleted stage was selected
    if (selectedStage && selectedStage.id === stageId) {
      setSelectedStage(null);
    }
  };
  
  // Handle edge deletion
  const handleDeleteEdge = (edgeId) => {
    // Remove the edge
    setListeners((currentListeners) => 
      currentListeners.filter(listener => listener.id !== edgeId)
    );
    
    // Clear selected edge
    setSelectedEdge(null);
  };
  
  // Define stage types using memoization to prevent unnecessary re-renders
  const stageTypes = React.useMemo(() => ({
    deploymentCard: (props) => <DeploymentCardStage {...props} onDelete={handleDeleteStage} id={props.id}/>,
    githubIntegration: GitHubIntegration,
  }), []); 
  
  // Helper to generate a unique Stage ID
  const generateStageId = (existingStages) => {
    let maxId = 0;
    existingStages.forEach(s => {
      const idNum = parseInt(s.id, 10);
      if (!isNaN(idNum) && idNum >= maxId) maxId = idNum + 1;
    });
    return String(maxId);
  };
  
  // Handle new connections between stages
  const onConnect = useCallback(
    (params) => setListeners((eds) => {
      // Animate/dash if connecting from staging (2 or 7) to production (4, 5, or 8) but NOT 3
      const stagingIds = ['2', '7'];
      const dashedProductionIds = ['4', '5', '8'];
      if ((stagingIds.includes(params.source) && dashedProductionIds.includes(params.target)) ||
      (dashedProductionIds.includes(params.source) && stagingIds.includes(params.target))) {
        return addEdge({ ...params, type: ConnectionLineType.Bezier, animated: true, style: { stroke: '#888', strokeDasharray: '6 4', strokeWidth: 2 } }, eds);
      }
      return addEdge({ ...params, type: ConnectionLineType.Bezier, animated: false, style: { stroke: '#888', strokeWidth: 2 } }, eds);
    }),
    [setListeners]
  );
  
  // Handle stage click to show sidebar and zoom
  const onStageClick = useCallback((event, stage) => {
    setSelectedStage(stage);
    // Zoom into the selected stage if instance is available
    if (reactFlowInstance && stage && stage.position) {
      reactFlowInstance.setCenter(
        stage.position.x + (stage.style?.width || 320) / 2 + SIDEBAR_WIDTH / 2,
        stage.position.y + 80, 
        { zoom: 1.2, duration: 800 }
      );
    }
    setIconAction(null); 
  }, [reactFlowInstance]);
  
  // Close sidebar
  const closeSidebar = () => {
    setSelectedStage(null);
  };
  
  // Handle pane click to close sidebar when clicking on empty canvas
  const onPaneClick = useCallback(() => {
    setSelectedStage(null);
    setSelectedEdge(null);
  }, []);
  
  // Handle edge click to select/deselect edge
  const onEdgeClick = useCallback((event, edge) => {
    event.stopPropagation(); // Prevent triggering pane click
    setSelectedEdge(prev => prev?.id === edge.id ? null : edge);
    setSelectedStage(null); // Deselect any selected stage
  }, []);
  
  // Handle icon block actions
  const handleIconAction = (action) => {
    setIconAction(action);
    // You can perform additional logic here, e.g., open modals, show info, etc.
  };
  

  
  // Ref for the ReactFlow wrapper div
  const reactFlowWrapper = useRef(null);

  // Export handler
  const handleExport = () => {
    if (!reactFlowWrapper.current) return;
    htmlToImage.toPng(reactFlowWrapper.current.querySelector('.react-flow'))
      .then((dataUrl) => {
        const link = document.createElement('a');
        link.download = 'workflow-chain.png';
        link.href = dataUrl;
        link.click();
      })
      .catch((err) => {
        alert('Failed to export image: ' + err);
      });
  };

  // Create edge styles with selection highlight and hide labels
  const edgesWithStyles = React.useMemo(() => {
    return listeners.map(edge => {
      // Create a new edge object without the label property
      const { label, ...edgeWithoutLabel } = edge;
      
      return {
        ...edgeWithoutLabel,
        style: {
          ...edge.style,
          stroke: selectedEdge?.id === edge.id ? '#3b82f6' : '#888888', // Gray connectors, blue when selected
          strokeWidth: selectedEdge?.id === edge.id ? 3 : edge.style?.strokeWidth || 2,
        },
        // Keep other properties but remove visible label
        labelStyle: {
          ...edge.labelStyle,
          fill: 'transparent', // Make text transparent (invisible)
        },
        labelBgStyle: {
          ...edge.labelBgStyle,
          fill: 'transparent', // Make background transparent
          fillOpacity: 0,
        },
      };
    });
  }, [listeners, selectedEdge]);
  
  // Use memoization to prevent unnecessary re-renders of ReactFlow
  const reactFlowElement = React.useMemo(() => (
    <ReactFlow
      nodes={stages}
      edges={edgesWithStyles}
      onNodesChange={onStagesChange}
      onEdgesChange={onListenersChange}
      onConnect={onConnect}
      onNodeClick={onStageClick}
      onEdgeClick={onEdgeClick}
      onPaneClick={onPaneClick}
      nodeTypes={stageTypes}
      connectionLineType={ConnectionLineType.Bezier}
      fitView
      fitViewOptions={{ padding: 0.3 }}
      minZoom={0.4}
      maxZoom={1.5}
      onInit={setReactFlowInstance}
      style={{ width: '100%', height: '100%' }} // Fixed dimensions to prevent layout shifts
    >
      <Controls />
      <Background variant="dots" gap={16} size={1} color="#bbb" />
    </ReactFlow>
  ), [stages, listeners, onStagesChange, onListenersChange, onConnect, onStageClick, onPaneClick, stageTypes, edgesWithStyles, onEdgeClick]);
  
  return (
    <div className="relative h-full w-full" ref={reactFlowWrapper}>
      <button
        onClick={handleExport}
        style={{ position: 'absolute', top: 16, left: 16, zIndex: 1000, background: '#222', color: 'white', padding: '10px 18px', borderRadius: 6, border: 'none', fontWeight: 600, cursor: 'pointer', boxShadow: '0 2px 8px rgba(128,128,128,0.20)' }}
      >
        Export as Image
      </button>
      <div className="flex-grow h-full" style={{ position: 'relative', zIndex: 1 }}>
        {reactFlowElement}
      </div>
      
      {/* Edge Delete UI */}
      {selectedEdge && (
        <div 
          className="absolute flex gap-2 bg-white shadow-gray-lg px-3 py-2 border z-10 rounded-lg"
          style={{ 
            top: '50%', 
            left: '50%', 
            transform: 'translate(-50%, -50%)',
            zIndex: 1000,
          }}
        >
          <div className="flex flex-col items-center">
            <div className="mb-2 font-medium">Selected Connection: {selectedEdge.id}</div>
            <Tippy content="Delete this connection" placement="top">
              <button 
                className="hover:bg-red-100 text-red-600 p-2 rounded-md flex items-center" 
                title="Delete Connection"
                onClick={() => handleDeleteEdge(selectedEdge.id)}
              >
                <span className="material-icons" style={{fontSize:20}}>delete</span>
                <span className="ml-2">Delete Connection</span>
              </button>
            </Tippy>
          </div>
        </div>
      )}
      
      {selectedStage && (
        <Sidebar 
          selectedStage={selectedStage} 
          onClose={closeSidebar} 
        />
      )}
    </div>
  );
}

export default WorkflowEditor;

<style jsx>{`
  .pipeline-badge {
    display: inline-flex;
    align-items: center;
    height: 1.8em;
  }
  .status-badge {
    display: inline-flex;
    align-items: center;
    height: 1.8em;
    padding: 0.2em 0.5em;
    border-radius: 0.2em;
    font-size: 0.8em;
    font-weight: 500;
  }
  .status-badge.passed {
    background-color: #c6efce;
    color: #2e865f;
  }
  .status-badge.running {
    background-color: #f7d2c4;
    color: #7a2518;
  }
  .status-badge.failed {
    background-color: #f2c6c6;
    color: #7a2518;
  }
`}</style>
  
  function OverlayModal({ open, onClose, children }) {
    if (!open) return null;
    return (
      <div className="modal is-open" aria-hidden={!open} style={{position:'fixed',top:0,left:0,right:0,bottom:0,zIndex:999999}}>
      <div className="modal-overlay" style={{position:'fixed',top:0,left:0,right:0,bottom:0,background:'rgba(40,50,50,0.6)',zIndex:999999}} onClick={onClose} />
      <div className="modal-content" style={{position:'fixed',top:'50%',left:'50%',transform:'translate(-50%, -50%)',zIndex:1000000,background:'#fff',borderRadius:8,boxShadow:'0 6px 40px rgba(128,128,128,0.20)',maxWidth:600,width:'90vw',padding:32}}>
      <button onClick={onClose} style={{position:'absolute',top:8,right:12,background:'none',border:'none',fontSize:26,color:'#888',cursor:'pointer'}} aria-label="Close">×</button>
      {children}
      </div>
      </div>
    );
  }
  