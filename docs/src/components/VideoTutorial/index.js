import styles from './styles.module.css';
import Youtube from '@site/static/img/youtube.svg';

/**
 * Collapsible containing an embedded youtube video
 * @param {string} title - the title of the video 
 * @param {string} url - the "embed mode" youtube url
 * @returns 
 */
const VideoTutorial  = ({title, src, opened}) => {
    return (
        <details className={styles.details} {...(opened && { open: true })}>  
         <summary className={styles.summary}><span className={styles.icon}><Youtube/></span>Video Tutorial: {title}</summary>
         <div className={styles.content}>
           <iframe className={styles.iframe} width="560" height="315" src={src} title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>
         </div>
        </details>
    );
};

export default VideoTutorial;
