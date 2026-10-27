import React, { useState } from 'react';
import { MiniAppSchema } from './types';
import { renderComponent } from './components/ComponentRegistry';
import { executeAction } from './actions/actionExecutor';
import { ArrowLeft, Home, Bell } from 'lucide-react';

interface SchemaRendererProps {
  schema: MiniAppSchema;
  appId?: string;
  initialPageId?: string;
  isNativeBridge?: boolean;
}

const isDarkColor = (colorStr?: string) => {
  if (!colorStr) return false;
  const hex = colorStr.replace('#', '').trim();
  if (hex.length === 6) {
    const r = parseInt(hex.substring(0, 2), 16);
    const g = parseInt(hex.substring(2, 4), 16);
    const b = parseInt(hex.substring(4, 6), 16);
    return (0.299 * r + 0.587 * g + 0.114 * b) < 128;
  }
  if (hex.length === 3) {
    const r = parseInt(hex[0] + hex[0], 16);
    const g = parseInt(hex[1] + hex[1], 16);
    const b = parseInt(hex[2] + hex[2], 16);
    return (0.299 * r + 0.587 * g + 0.114 * b) < 128;
  }
  return false;
};

export const SchemaRenderer: React.FC<SchemaRendererProps> = ({
  schema,
  appId = 'schema_app',
  initialPageId,
  isNativeBridge = false,
}) => {
  const [currentPageId, setCurrentPageId] = useState<string>(
    initialPageId || schema.pages?.[0]?.id || 'home',
  );
  const [toast, setToast] = useState<{ message: string; type: 'success' | 'error' | 'info' } | null>(null);

  const showToast = (message: string, type: 'success' | 'error' | 'info' = 'info') => {
    setToast({ message, type });
    setTimeout(() => setToast(null), 3000);
  };

  const isDark = isDarkColor(schema.theme?.backgroundColor);
  const bgColor = schema.theme?.backgroundColor || '#F8FAFC';
  const textColor = isDark ? '#F8FAFC' : '#0F172A';

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
        width: '100%',
        backgroundColor: bgColor,
        color: textColor,
        display: 'flex',
        flexDirection: 'column',
        position: 'relative',
        margin: 0,
        padding: 0,
        boxSizing: 'border-box',
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

      {/* App Navigation Bar: Only show in standalone browser or on subpages for back navigation */}
      {(!isNativeBridge || isSubPage) && (
        <header
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            padding: '12px 16px',
            backgroundColor: isDark ? bgColor : '#FFFFFF',
            borderBottom: isDark ? '1px solid rgba(255, 255, 255, 0.08)' : '1px solid #E2E8F0',
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
                  background: isDark ? 'rgba(255, 255, 255, 0.12)' : '#F1F5F9',
                  border: 'none',
                  borderRadius: '8px',
                  padding: '6px',
                  cursor: 'pointer',
                  display: 'flex',
                  alignItems: 'center',
                }}
              >
                <ArrowLeft size={18} color={isDark ? '#FFFFFF' : '#334155'} />
              </button>
            )}
            <h2 style={{ fontSize: '16px', fontWeight: 800, margin: 0, color: isDark ? '#FFFFFF' : '#0F172A' }}>
              {currentPage.title || 'Mini App'}
            </h2>
          </div>
          {!isNativeBridge && (
            <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
              <span
                style={{
                  fontSize: '10px',
                  fontWeight: 700,
                  backgroundColor: isDark ? 'rgba(16, 185, 129, 0.2)' : '#ECFDF5',
                  color: isDark ? '#34D399' : '#059669',
                  padding: '2px 8px',
                  borderRadius: '10px',
                }}
              >
                SCHEMA RUNTIME
              </span>
            </div>
          )}
        </header>
      )}

      {/* Page Body Components */}
      <main
        style={{
          flex: 1,
          width: '100%',
          padding: '16px',
          boxSizing: 'border-box',
          backgroundColor: bgColor,
          color: textColor,
        }}
      >
        {currentPage.components?.map((component) => renderComponent(component, handleAction))}
      </main>

      {/* Bottom page switcher if app has multiple pages */}
      {schema.pages?.length > 1 && (
        <footer
          style={{
            display: 'flex',
            backgroundColor: isDark ? bgColor : '#FFFFFF',
            borderTop: isDark ? '1px solid rgba(255, 255, 255, 0.08)' : '1px solid #E2E8F0',
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
