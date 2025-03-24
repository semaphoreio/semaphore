import React from 'react';
// Import the original mapper
import MDXComponents from '@theme-original/MDXComponents';
//import { Icon } from '@iconify/react'; // Import the entire Iconify library.
import { Icon } from '@iconify-icon/react';

export default {
  // Re-use the default mapping
  ...MDXComponents,
  IIcon: Icon, // Make the iconify Icon component available in MDX as <icon />.
};
