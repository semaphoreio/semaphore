import React from 'react';
// Import the original mapper
import MDXComponents from '@theme-original/MDXComponents';
//import { Icon } from '@iconify/react'; // Import the entire Iconify library.
import { Icon } from '@iconify-icon/react';

import Card from '@site/src/components/Card';
import CardBody from '@site/src/components/Card/CardBody';
import CardFooter from '@site/src/components/Card/CardFooter';
import CardHeader from '@site/src/components/Card/CardHeader';
import CardImage from '@site/src/components/Card/CardImage';

import Columns from '@site/src/components/Columns';
import Column from '@site/src/components/Column';

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
};
