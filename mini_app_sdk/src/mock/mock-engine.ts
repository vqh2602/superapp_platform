import type { BridgeRequest, BridgeResponse } from '../transport/types.js';
import { MockStateStore } from './store.js';
export interface MockLogEntry {
  id: string; action: string; payload: any; success: boolean; response?: any;
  error?: any; durationMs: number; timestamp: number;
}
/** @deprecated No fake native responses. Run the miniapp inside SuperApp. */
export class SDKMockEngine {
  readonly store = new MockStateStore();
  constructor(..._args: unknown[]) {}
  async dispatch(request: BridgeRequest): Promise<BridgeResponse> {
    return { id: request.id, action: request.action, success: false,
      error: { code: 'NATIVE_NOT_AVAILABLE', message: 'Native data requires a connected SuperApp host' } };
  }
  getLogs(): MockLogEntry[] { return []; }
  clearLogs(): void {}
  onLog(_listener: (entry: MockLogEntry) => void): () => void { return () => {}; }
}
