import React from 'react';
// Import the original mapper
import MDXComponents from '@theme-original/MDXComponents';
//import { Icon } from '@iconify/react'; // Import the entire Iconify library.
import { Icon } from '@iconify-icon/react';

// Card component: CTA with text and button
import Card from '@site/src/components/Card';
import CardBody from '@site/src/components/Card/CardBody';
import CardFooter from '@site/src/components/Card/CardFooter';
import CardHeader from '@site/src/components/Card/CardHeader';
import CardImage from '@site/src/components/Card/CardImage';

// Columns component: organize elements into columns
import Columns from '@site/src/components/Columns';
import Column from '@site/src/components/Column';

// Tabs component: show different ways to do the same thing
import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';

// Available component: inform a feature is available only on certain Cloud plans
import Available from '@site/src/components/Available';

// VideoTutorial: collapsible section to embed youtube videos
import VideoTutorial from '@site/src/components/VideoTutorial';

// Steps component: for long step-by-step list of steps
import Steps from '@site/src/components/Steps';

export default {
  // Re-use the default mapping
  ...MDXComponents,
  IIcon: Icon, // Make the iconify Icon component available in MDX as <icon />.
  Card, 
  CardHeader, 
  CardBody, 
  CardFooter, 
  CardImage,
  Columns,
  Column, 
  Tabs,
  TabItem,
  Available,
  VideoTutorial,
  Steps
};
