import clsx from 'clsx';
import Link from '@docusaurus/Link';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import Layout from '@theme/Layout';
import { useColorMode } from '@docusaurus/theme-common';

import Heading from '@theme/Heading';
import styles from './index.module.css';

function HomepageHeader() {
  const { siteConfig } = useDocusaurusContext();
  const githubStarsUrl = `https://ghbtns.com/github-btn.html?user=semaphoreio&repo=semaphore&type=star&count=true&size=large`;
  const { colorMode } = useColorMode();

  return (
    <header
      style={{ background: 'rgba(0,0,0,0)' }}
      className={clsx('hero hero--primary', styles.heroBanner)}
    >
      <div className="container">
        <Heading as="h1" className={`hero__title ${colorMode}`}>
          <span>{siteConfig.title}</span>
        </Heading>

        <p className={`hero__subtitle ${colorMode}`}>{siteConfig.tagline}</p>

        <div className={styles.buttonsWrapper}>
          <div className={styles.buttonContainer}>
            <Link
              className="button button--primary button--lg"
              to="/CE/getting-started/install"
            >
              Community Edition
            </Link>
          </div>

          <div className={styles.buttonContainer}>
            <Link
              className="button button--secondary button--lg"
              to="/EE/getting-started/install"
            >
              Enterprise Edition
            </Link>
          </div>

          <div className={styles.buttonContainer}>
            <Link
              className="button button--outline button--secondary button--lg"
              to="/getting-started/guided-tour"
            >
              Guided Tour
            </Link>
          </div>

          <div className={styles.buttonContainer}>
            <iframe
              className={styles.indexCtasGitHubButton}
              src={githubStarsUrl}
              width={160}
              height={30}
              title="GitHub Stars"
            />
          </div>
        </div>
      </div>
    </header>
  );
}

import { FeatureCardsRow } from '@site/src/components/FeatureCards';

export default function Home() {
  const { siteConfig } = useDocusaurusContext();
  return (
    <Layout title={siteConfig.title} description={siteConfig.tagline}>
      <HomepageHeader />
      <main>
        <FeatureCardsRow />
      </main>
    </Layout>
  );
}
