import React from 'react';
import { Play } from 'lucide-react';
import { RunnerConfig, useSDK } from '../context/SDKContext';

interface FeatureItemProps {
  icon: React.ReactNode;
  config: RunnerConfig;
  statusText?: string;
  isDanger?: boolean;
}

export const FeatureItem: React.FC<FeatureItemProps> = ({
  icon,
  config,
  statusText = 'Ready',
  isDanger = false,
}) => {
  const { openRunner } = useSDK();

  return (
    <div className={`feature-card ${isDanger ? 'feature-card-danger' : ''}`}>
      <div className="feature-icon-wrapper">{icon}</div>
      <div className="feature-content">
        <div className="feature-title-row">
          <h3 className="feature-name">{config.title}</h3>
          <span className={`status-tag ${isDanger ? 'tag-danger' : 'tag-ready'}`}>{statusText}</span>
        </div>
        <p className="feature-desc">{config.description}</p>
        <code className="feature-code">{config.actionCode}</code>
      </div>
      <div className="feature-action">
        <button
          className={`run-demo-btn ${isDanger ? 'btn-danger' : ''}`}
          onClick={() => openRunner(config)}
        >
          <Play size={14} />
          <span>Run Demo</span>
        </button>
      </div>
    </div>
  );
};
