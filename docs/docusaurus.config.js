// @ts-check
// `@type` JSDoc annotations allow editor autocompletion and type checking
// (when paired with `@ts-check`).
// There are various equivalent ways to declare your Docusaurus config.
// See: https://docusaurus.io/docs/api/docusaurus-config

import { themes as prismThemes } from 'prism-react-renderer';
import * as OpenApiPlugin from "docusaurus-plugin-openapi-docs";

/** @type {import('@docusaurus/types').Config} */
const config = {
  // this setting controls if pages can be indexed by search engines
  // https://docusaurus.io/docs/next/api/docusaurus-config#noIndex
  noIndex: false,
  title: 'Semaphore',
  tagline: 'A CI/CD solution to elevate developer workflows',
  favicon: 'img/favicon.ico',

  // extra themes
  themes: [
    'docusaurus-theme-openapi-docs',
    '@docusaurus/theme-mermaid',
  ],
  markdown: {
    mermaid: true,
  },

  // Production url of your site here
  url: 'https://docs.semaphoreci.com',

  // Set the /<baseUrl>/ pathname under which your site is served
  // For GitHub pages deployment, it is often '/<projectName>/'
  baseUrl: process.env.BASE_URL ? process.env.BASE_URL : '/',

  // GitHub org and project. Needed for Github Pages.
  organizationName: 'semaphoreci',
  projectName: 'semaphore',

  onBrokenLinks: 'throw',
  onBrokenMarkdownLinks: 'warn',

  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  presets: [
    [
      'classic',
      /** @type {import('@docusaurus/preset-classic').Options} */
      ({
        docs: {
          sidebarCollapsible: true,
          routeBasePath: '/', // move docs to the website root
          sidebarPath: './sidebars.js',
          docItemComponent: "@theme/ApiItem", // Derived from docusaurus-theme-openapi
          editUrl: 'https://github.com/semaphoreio/semaphore/tree/main/docs/',

          /* Versioned Docs */
          lastVersion: 'current',
          versions: {
            current: {
              label: 'Cloud (SaaS)',
              path: '',
              banner: "none",
            },
            "CE": {
              label: 'Community Edition v1.3',
              path: 'CE',
              banner: "none"
            },
            "CE-1.2": {
              label: 'Community Edition v1.2',
              path: 'CE-1.2',
            },
            "CE-1.1": {
              label: 'Community Edition v1.1',
              path: 'CE-1.1',
            },
            "EE": {
              label: 'Enterprise Edition v1.3',
              path: 'EE',
              banner: "none"
            },
          },

        },
        blog: false,
        theme: {
          customCss: './src/css/custom.css',
        },
        gtag: {
          trackingID: 'G-YC5YMJQ25R',
          anonymizeIP: true
        },
      }),
    ],
  ],

  plugins: [
      '@docusaurus/plugin-ideal-image',
      [
        'docusaurus-plugin-openapi-docs',
        {
          id: "api", // plugin id
          docsPluginId: "classic", // configured for preset-classic
          config: {
            semaphoreAPI: {
              specPath: "https://docs.semaphoreci.com/v2/api-spec/openapi.yaml",
              outputDir: "docs/openapi-spec",
              downloadUrl: "https://docs.semaphoreci.com/v2/api-spec/openapi.json",
              sidebarOptions: {
                categoryLinkSource: "tag",
                groupPathsBy: "tag",
              },
            },
          }
        },
      ]
  ],

  themeConfig:
    /** @type {import('@docusaurus/preset-classic').ThemeConfig} */
    ({
      // Social card image
      image: 'img/semaphore-social-card.jpg',
      // search config - these are tied to the domain
      algolia: {
        // The application ID provided by Algolia
        appId: 'HJWFPD10QI',
        // Public API key: it is safe to commit it
        apiKey: '5d6175600a64cf232ea5be2b88cd5cab',
        indexName: 'v2-sxmoon',
        // Optional: see doc section below
        contextualSearch: true,
      },
      navbar: {
        title: 'Semaphore Docs',
        logo: {
          alt: 'Semaphore Logo',
          src: 'img/logo.svg',
          srcDark: 'img/logo-white.svg'
        },
        items: [
          {
            type: 'docSidebar',
            sidebarId: 'gettingStarted',
            position: 'left',
            label: 'Getting Started',
          },
          {
            type: 'docSidebar',
            sidebarId: 'usingSemaphore',
            position: 'left',
            label: 'Using Semaphore',
          },
          {
            type: 'docSidebar',
            sidebarId: 'reference',
            position: 'left',
            label: 'Reference',
          },
          // uncomment this when the new API is released
          // {
          //   type: 'docSidebar',
          //   sidebarId: 'apiSidebar',
          //   position: 'left',
          //   label: 'API Specification',
          // },
          {
            type: 'html',
            position: 'right',
            value: '<a href="/CE/getting-started/about-semaphore">Semaphore Editions →</a>'
          },
          /* version */
          {
            type: 'docsVersionDropdown',
            position: 'right',
            // dropdownItemsAfter: [{to: '/versions', label: 'All versions'}],
            dropdownActiveClassDisabled: true,
          },
          {
            href: 'https://github.com/semaphoreio/semaphore',
            className: 'header-github-link',
            'aria-label': 'GitHub repository',
            // label: 'GitHub',
            position: 'right',

          },
          {
            type: 'search',
            position: 'right',
          },
        ],
      },

      // This is an optional announcement bar. It goes on the top of the page
      // announcementBar: {
      //   id: `announcementBar-1`,
      //   content: `Semaphore <strong>Enterprise Edition</strong> v1.3.0 is available! — ⭐️ If you like Semaphore, <em>give it a star</em> on <a target="_blank" rel="noopener noreferrer" href="https://github.com/semaphoreio/semaphore">GitHub</a>`,
      //   backgroundColor: '#49a26e',
      //   textColor: '#f5f6f7'
      // },
      footer: {
        style: 'dark',
        links: [
          {
            title: 'Community',
            items: [
              {
                label: 'YouTube',
                href: 'https://www.youtube.com/c/SemaphoreCI',
              },
              {
                label: 'Discord',
                href: 'https://discord.gg/FBuUrV24NH',
              },
              {
                label: 'Twitter',
                href: 'https://twitter.com/semaphoreci',
              },
              {
                label: 'GitHub',
                href: 'https://github.com/semaphoreio',
              },
              {
                label: 'LinkedIn',
                href: 'https://www.linkedin.com/company/rendered-text/',
              },
            ],
          },
          {
            title: 'More',
            items: [
              {
                label: 'Semaphore Blog',
                href: 'https://semaphore.io/blog',
              },
              {
                label: 'Guides and E-Books',
                href: 'https://semaphore.io/resources',
              },
              {
                label: 'CI/CD Learning Tool',
                href: 'https://semaphore.io/cicd-learning-hub',
              },
            ],
          },
        ],
        copyright: `Copyright © ${new Date().getFullYear()} Semaphore Technologies doo. Built with Docusaurus.`,
      },
      prism: {
        theme: prismThemes.github,
        darkTheme: prismThemes.dracula,
        additionalLanguages: ['elixir', 'java', 'groovy'],
      },
    }),
    // future: {
      // experimental_faster: true,
    // },
};

export default config;
