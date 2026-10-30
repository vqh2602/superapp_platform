import React from 'react';
import { BridgeInspectorTab } from './tabs/BridgeInspectorTab.js';
export const DevToolsDrawer: React.FC = () => <section style={{flex: 1, maxWidth: 600, minWidth: 380, height: '100%', padding: 16, background: '#0b1120', borderRadius: 16}}>
  <h3>Bridge Inspector</h3><p style={{color: '#94a3b8', fontSize: 13}}>Responses come from the connected native host. Device APIs require SuperApp.</p><BridgeInspectorTab />
</section>;
