import React, { useState, useCallback, useRef } from 'react';
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
const DeploymentCardStage = ({ data, selected, onIconAction }) => {
  const [showOverlay, setShowOverlay] = React.useState(false);
  const handleAction = (action) => {
    if (action === 'code') setShowOverlay(true);
    if (onIconAction) onIconAction(action);
  };
  return (
    <div className={`bg-white roundedg shadow-md border ${selected ? 'ring-2 ring-blue-500' : 'border-gray-200'} relative`}>
      {/* Icon block above node when selected */}
      {selected && (
        <div className="absolute -top-10 left-1/2 -translate-x-1/2 flex gap-2 bg-white shadow-lg br4 px-3 py-2 border z-10">
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
            <div className="flex items-center p-2 bg-gray-50 rounded mb-1">
              <div className="material-symbols-outlined v-mid purple b">flaky</div>
              <span className="text-sm ml2">{data.queue[0]}</span>
            </div>
            {data.queue.length > 1 && (
              <div className="text-xs text-blue-600 hover:text-blue-800">
                <a href="#" className="no-underline hover:underline">{data.queue.length - 1} more items</a>
              </div>
            )}
          </>
        ) : (
          <div className="text-sm text-gray-500 italic">No items in queue</div>
        )}
      </div>
      <CustomBarHandle type="target" position={Position.Left} />
      <CustomBarHandle type="source" position={Position.Right} />
    </div>
  );
};

// Custom integration component for GitHub repository
const GitHubIntegration = ({ data, selected }) => {
  return (
    <div className={`bg-white roundedg shadow-md border ${selected ? 'ring-2 ring-blue-500' : 'border-gray-200'}`}>
      <Handle 
        type="target" 
        position={Position.Left} 
        style={{ background: '#000', width: 10, height: 10 }} 
      />
      <div className="flex items-center p-3 bg-[#24292e] text-white rounded-tg">
        <span className="mr-2">
          <svg viewBox="0 0 16 16" width="16" height="16" fill="currentColor">
            <path fillRule="evenodd" d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0016 8c0-4.42-3.58-8-8-8z"></path>
          </svg>
        </span>
        <span className="font-semibold">{data.repoName}</span>
        {selected && <div className="absolute top-0 right-0 w-3 h-3 bg-blue-500 rounded-full m-1"></div>}
      </div>
      <div className="p-4">
        <div className="mb-3">
          <a href={data.repoUrl} target="_blank" rel="noopener noreferrer" className="text-blue-600 hover:text-blue-800 break-all">
            {data.repoUrl}
          </a>
        </div>
        <div>
          <h4 className="text-sm font-medium text-gray-700 mb-2">Last Event</h4>
          <div className="bg-gray-50 border border-gray-200 rounded p-3">
            <div className="flex justify-between mb-1">
              <span className="text-sm text-gray-600">Event Type:</span>
              <span className="text-sm font-medium">{data.lastEvent.type}</span>
            </div>
            <div className="flex justify-between mb-1">
              <span className="text-sm text-gray-600">Release:</span>
              <span className="text-sm font-medium">{data.lastEvent.release}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-sm text-gray-600">Timestamp:</span>
              <span className="text-sm font-medium">{data.lastEvent.timestamp}</span>
            </div>
          </div>
        </div>
      </div>
      <Handle 
        type="source" 
        position={Position.Right} 
        style={{ background: '#000', width: 10, height: 10 }} 
      />
    </div>
  );
};

// Sidebar component to display selected stage details
const Sidebar = ({ selectedStage, onClose }) => {
  const [activeTab, setActiveTab] = useState('general');
  const [width, setWidth] = useState(600);
  const isDragging = useRef(false);
  const sidebarRef = useRef(null);

  // Sidebar tab definitions
  const tabs = [
    { key: 'general', label: 'General' },
    { key: 'history', label: 'History' },
    { key: 'queue', label: 'Queue' },
    { key: 'settings', label: 'Settings' },
  ];

  // Handle mouse down on resize handle
  const handleMouseDown = (e) => {
    isDragging.current = true;
    document.body.style.cursor = 'ew-resize';
    document.addEventListener('mousemove', handleMouseMove);
    document.addEventListener('mouseup', handleMouseUp);
  };

  // Handle mouse move during resize
  const handleMouseMove = (e) => {
    if (!isDragging.current) return;
    const sidebarLeft = sidebarRef.current.getBoundingClientRect().left;
    const newWidth = Math.max(300, Math.min(800, window.innerWidth - e.clientX));
    // Only update if width changes, and batch with requestAnimationFrame
    if (width !== newWidth) {
      requestAnimationFrame(() => setWidth(newWidth));
    }
  };

  // Handle mouse up to stop resizing
  const handleMouseUp = () => {
    isDragging.current = false;
    document.body.style.cursor = '';
    document.removeEventListener('mousemove', handleMouseMove);
    document.removeEventListener('mouseup', handleMouseUp);
  };

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
              <path fillRule="evenodd" d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0016 8c0-4.42-3.58-8-8-8z"></path>
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
};

// Define stage types
const stageTypes = {
  deploymentCard: (props) => (
    <DeploymentCardStage {...props} onIconAction={(action) => console.log('Icon action:', action)} />
  ),
  githubIntegration: GitHubIntegration,
};

// Initial stages configuration
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
      queue: ['Feature: Add user authentication', 'Bugfix: Fix login redirect', 'Feature: Add dark mode']
    },
    position: { x: -400, y: 145 },
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
      queue: ['Feature: Add user authentication', 'Bugfix: Fix layout on mobile', 'Feature: Add dark mode']
    },
    position: { x: 100, y: 127 },
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
      queue: ['FEAT-211: Partially rebuild pipeline']
    },
    position: { x: 600, y: 137 },
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
      queue: []
    },
    position: { x: 1100, y: -150 },
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
      queue: []
    },
    position: { x: 1100, y: 150 },
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
      status: 'Running',
      timestamp: 'Deploying now',
      labels: ['5e3d12b', 'v.4.1.3', 'v.2.3.1', 'community'],
      queue: ['FEAT-211: Partially rebuild pipeline']
    },
    position: { x: 1100, y: 450 },
    style: {
      width: 320,
    },
  },
  
  // Second workflow - Toolbox
  {
    id: '6',
    type: 'githubIntegration',
    data: { 
      repoName: 'semaphoreci/toolbox',
      repoUrl: 'https://github.com/semaphoreci/toolbox',
      lastEvent: {
        type: 'push',
        release: 'main',
        timestamp: '2025-04-09 09:30 AM'
      },
      status: 'Passed',
      timestamp: 'Deployed 2 hours ago',
      labels: ['3e7a91d', 'v.4.1.3', 'v.2.3.1', 'community'],
      queue: ['Test: Integration tests', 'Test: Performance benchmarks']
    },
    position: { x: -400, y: 645 },
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
      queue: ['Test: Integration tests', 'Test: Performance benchmarks']
    },
    position: { x: 100, y: 627 },
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
      queue: []
    },
    position: { x: 600, y: 648 },
    style: {
      width: 320,
    },
  },
];

// Initial listeners configuration - connecting the stages
const initialListeners = [
  // First workflow connections
  {
    id: 'e0-1',
    source: '0',
    target: '1',
    type: 'smoothstep',
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
    type: 'smoothstep',
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
    type: 'smoothstep',
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
    type: 'smoothstep',
    animated: true,
    label: 'Promote to EU',
    style: { stroke: '#888', strokeDasharray: '6 4', strokeWidth: 2 },
    labelStyle: { fill: '#000', fontWeight: 500 },
    labelBgStyle: { fill: 'rgba(255, 255, 255, 0.9)', fillOpacity: 0.9 },
  },
  {
    id: 'e2-5',
    source: '2',
    target: '5',
    type: 'smoothstep',
    animated: true,
    label: 'Promote to JP',
    style: { stroke: '#888', strokeDasharray: '6 4', strokeWidth: 2 },
    labelStyle: { fill: '#000', fontWeight: 500 },
    labelBgStyle: { fill: 'rgba(255, 255, 255, 0.9)', fillOpacity: 0.9 },
  },
  
  // Second workflow connections
  {
    id: 'e6-7',
    source: '6',
    target: '7',
    type: 'smoothstep',
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
    type: 'smoothstep',
    animated: true,
    label: 'Deploy to Production',
    style: { stroke: '#888', strokeDasharray: '6 4', strokeWidth: 2 },
    labelStyle: { fill: '#000', fontWeight: 500 },
    labelBgStyle: { fill: 'rgba(255, 255, 255, 0.9)', fillOpacity: 0.9 },
  },
];

function WorkflowEditor() {
  const [stages, setStages, onStagesChange] = useNodesState(initialStages);
  const [listeners, setListeners, onListenersChange] = useEdgesState(initialListeners);
  const [selectedStage, setSelectedStage] = useState(null);
  const [iconAction, setIconAction] = useState(null); 
  const [reactFlowInstance, setReactFlowInstance] = useState(null);

  const SIDEBAR_WIDTH = 400; 

  // Handle new connections between stages
  const onConnect = useCallback(
    (params) => setListeners((eds) => {
      // Animate/dash if connecting from staging (2 or 7) to production (4, 5, or 8) but NOT 3
      const stagingIds = ['2', '7'];
      const dashedProductionIds = ['4', '5', '8'];
      if ((stagingIds.includes(params.source) && dashedProductionIds.includes(params.target)) ||
          (dashedProductionIds.includes(params.source) && stagingIds.includes(params.target))) {
        return addEdge({ ...params, type: ConnectionLineType.SmoothStep, animated: true, style: { stroke: '#888', strokeDasharray: '6 4', strokeWidth: 2 } }, eds);
      }
      return addEdge({ ...params, type: ConnectionLineType.SmoothStep, animated: false, style: { stroke: '#888', strokeWidth: 2 } }, eds);
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
  }, []);

  // Handle icon block actions
  const handleIconAction = (action) => {
    setIconAction(action);
    // You can perform additional logic here, e.g., open modals, show info, etc.
  };

  return (
    <div className="relative h-full w-full">
      <div className="flex-grow h-full" style={{ position: 'relative', zIndex: 1 }}>
        <ReactFlow
          nodes={stages}
          edges={listeners}
          onNodesChange={onStagesChange}
          onEdgesChange={onListenersChange}
          onConnect={onConnect}
          onNodeClick={onStageClick}
          onPaneClick={onPaneClick}
          nodeTypes={stageTypes}
          connectionLineType={ConnectionLineType.SmoothStep}
          fitView
          fitViewOptions={{ padding: 0.3 }}
          minZoom={0.4}
          maxZoom={1.5}
          onInit={setReactFlowInstance}
        >
          <Controls />
          <Background variant="dots" gap={12} size={1} />
        </ReactFlow>
      </div>
      
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
      <div className="modal-content" style={{position:'fixed',top:'50%',left:'50%',transform:'translate(-50%, -50%)',zIndex:1000000,background:'#fff',borderRadius:8,boxShadow:'0 6px 40px rgba(0,0,0,0.18)',maxWidth:600,width:'90vw',padding:32}}>
        <button onClick={onClose} style={{position:'absolute',top:8,right:12,background:'none',border:'none',fontSize:26,color:'#888',cursor:'pointer'}} aria-label="Close">×</button>
        {children}
      </div>
    </div>
  );
}
