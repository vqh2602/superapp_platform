import { ITransport } from '../../transport/index.js';

export class DebugModule {
  constructor(private transport: ITransport) {}

  /**
   * Kiểm tra phản hồi echo từ SuperApp Bridge
   */
  public async echo(payload: any): Promise<any> {
    return this.transport.invoke('debug.echo', payload);
  }

  /**
   * Giả lập lỗi native để kiểm tra xử lý ngoại lệ
   */
  public async simulateFailure(type: string): Promise<any> {
    return this.transport.invoke('debug.simulateFailure', { type });
  }
}
