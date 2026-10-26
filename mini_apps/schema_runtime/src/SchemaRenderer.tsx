import React, { useState } from 'react';
import { MiniAppSchema } from './types';
import { renderComponent } from './components/ComponentRegistry';
import { executeAction } from './actions/actionExecutor';
import { ArrowLeft, Home, Bell } from 'lucide-react';

interface SchemaRendererProps {
  schema: MiniAppSchema;
  appId?: string;
  initialPageId?: string;
}

export const SchemaRenderer: React.FC<SchemaRendererProps> = ({
  schema,
  appId = 'schema_app',
  initialPageId,
}) => {
  const [currentPageId, setCurrentPageId] = useState<string>(
    initialPageId || schema.pages?.[0]?.id || 'home',
  );
  const [toast, setToast] = useState<{ message: string; type: 'success' | 'error' | 'info' } | null>(null);

  const showToast = (message: string, type: 'success' | 'error' | 'info' = 'info') => {
    setToast({ message, type });
    setTimeout(() => setToast(null), 3000);
  };

  const currentPage = schema.pages?.find((p) => p.id === currentPageId) || schema.pages?.[0];

  const handleAction = (action: any) => {
    executeAction(action, {
      appId,
      onNavigate: (pageId) => setCurrentPageId(pageId),
      showNotification: showToast,
    });
  };

  if (!currentPage) {
    return (
      <div style={{ padding: 24, textAlign: 'center', color: '#64748B' }}>
        <h3>Trang không tồn tại</h3>
        <p>Không tìm thấy trang nào trong schema.</p>
      </div>
    );
  }

  const isSubPage = currentPage.id !== schema.pages?.[0]?.id;

  return (
    <div
      style={{
        minHeight: '100vh',
        backgroundColor: schema.theme?.backgroundColor || '#F8FAFC',
        color: '#0F172A',
        display: 'flex',
        flexDirection: 'column',
        position: 'relative',
      }}
    >
      {/* Toast Notification */}
      {toast && (
        <div
          style={{
            position: 'fixed',
            top: 14,
            left: 14,
            right: 14,
            zIndex: 9999,
            backgroundColor:
              toast.type === 'success'
                ? '#10B981'
                : toast.type === 'error'
                ? '#EF4444'
                : '#1E293B',
            color: 'white',
            padding: '12px 16px',
            borderRadius: '12px',
            fontSize: '13px',
            fontWeight: 600,
            boxShadow: '0 8px 20px rgba(0,0,0,0.2)',
            display: 'flex',
            alignItems: 'center',
            gap: '8px',
            animation: 'fadeIn 0.2s ease',
          }}
        >
          <Bell size={16} />
          <span>{toast.message}</span>
        </div>
      )}

      {/* App Navigation Bar */}
      <header
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          padding: '14px 16px',
          backgroundColor: '#FFFFFF',
          borderBottom: '1px solid #E2E8F0',
          position: 'sticky',
          top: 0,
          zIndex: 10,
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
          {isSubPage && (
            <button
              onClick={() => setCurrentPageId(schema.pages[0].id)}
              style={{
                background: '#F1F5F9',
                border: 'none',
                borderRadius: '8px',
                padding: '6px',
                cursor: 'pointer',
                display: 'flex',
                alignItems: 'center',
              }}
            >
              <ArrowLeft size={18} color="#334155" />
            </button>
          )}
          <h2 style={{ fontSize: '16px', fontWeight: 800, margin: 0, color: '#0F172A' }}>
            {currentPage.title || 'Mini App'}
          </h2>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
          <span
            style={{
              fontSize: '10px',
              fontWeight: 700,
              backgroundColor: '#ECFDF5',
              color: '#059669',
              padding: '2px 8px',
              borderRadius: '10px',
            }}
          >
            SCHEMA RUNTIME
          </span>
        </div>
      </header>

      {/* Page Body Components */}
      <main style={{ flex: 1, padding: '16px' }}>
        {currentPage.components?.map((component) => renderComponent(component, handleAction))}
      </main>

      {/* Bottom page switcher if app has multiple pages */}
      {schema.pages?.length > 1 && (
        <footer
          style={{
            display: 'flex',
            backgroundColor: '#FFFFFF',
            borderTop: '1px solid #E2E8F0',
            padding: '8px 12px',
            position: 'sticky',
            bottom: 0,
            justifyContent: 'space-around',
          }}
        >
          {schema.pages.map((p) => {
            const active = p.id === currentPageId;
            return (
              <button
                key={p.id}
                onClick={() => setCurrentPageId(p.id)}
                style={{
                  background: 'none',
                  border: 'none',
                  color: active ? '#2563EB' : '#64748B',
                  fontWeight: active ? 700 : 500,
                  fontSize: '12px',
                  display: 'flex',
                  flexDirection: 'column',
                  alignItems: 'center',
                  gap: '4px',
                  cursor: 'pointer',
                  padding: '6px 12px',
                }}
              >
                <Home size={16} />
                <span>{p.title}</span>
              </button>
            );
          })}
        </footer>
      )}
    </div>
  );
};
