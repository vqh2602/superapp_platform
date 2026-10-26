import React from 'react';
import { useSDK } from '../context/SDKContext';
import { Activity, Trash2 } from 'lucide-react';

export const EventLogViewer: React.FC = () => {
  const { eventLogs, clearEventLogs } = useSDK();

  return (
    <div className="event-logger-card">
      <div className="card-header-bar">
        <div className="header-title-row">
          <Activity size={18} className="text-primary" />
          <h3 className="section-title">Event Logs (Lifecycle & Bridge Events)</h3>
          <span className="count-pill">{eventLogs.length}</span>
        </div>
        {eventLogs.length > 0 && (
          <button className="text-btn text-danger" onClick={clearEventLogs}>
            <Trash2 size={14} />
            <span>Clear</span>
          </button>
        )}
      </div>

      <div className="event-list">
        {eventLogs.length === 0 ? (
          <div className="empty-hint">Chưa có sự kiện nào từ Flutter (miniapp.ready, resume, sessionChanged...)</div>
        ) : (
          eventLogs.map((evt) => (
            <div key={evt.id} className="event-row">
              <div className="event-info">
                <span className="event-name">{evt.event}</span>
                <span className="event-time">{evt.timestamp}</span>
              </div>
              <pre className="event-payload">{JSON.stringify(evt.payload, null, 2)}</pre>
            </div>
          ))
        )}
      </div>
    </div>
  );
};
