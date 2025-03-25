import React from 'react';
import styles from './styles.module.css';

const NiceButton = ({ 
    title, // = "Install",
    subtitle, //= "Semaphore",
    icon: Icon,
    url,
    onClick,
    newTab = false
  }) => {
    return (
      <a 
        href={url}
        target={newTab ? "_blank" : "_self"}
        rel={newTab ? "noopener noreferrer" : ""}
        onClick={onClick}
        className={styles.niceButton}
      >
        <div className={styles.niceButtonIcon}>
          <Icon />
        </div>
        <span className={styles.niceButtonTitle}>{title}</span>
        <span className={styles.niceButtonSubtitle}>{subtitle}</span>
      </a>
    );
  };


const ButtonContainer = ({ children }) => {
    return (
      <div className={styles.buttonContainer}>
        {children}
      </div>
    );
};


export { NiceButton, ButtonContainer };