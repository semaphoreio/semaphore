// src/components/Steps.js
import React from 'react';
import styles from './styles.module.css';

export default function Steps({ children }) {
  return (
    <div className={styles.stepsContainer}>
      {children}
    </div>
  );
}