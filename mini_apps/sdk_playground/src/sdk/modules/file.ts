import { BridgeTransport } from '../bridgeTransport';

export class FileModule {
  constructor(private transport: BridgeTransport) {}

  /**
   * Mở Share Sheet để lưu hoặc chia sẻ 1 file
   */
  public async saveFile(options: {
    fileName: string;
    content?: string;
    url?: string;
    mimeType?: string;
  }): Promise<{ success: boolean; fileName: string; action: string }> {
    return this.transport.invoke('saveFile', options);
  }

  /**
   * Mở trình quản lý file hệ thống để chọn 1 (hoặc nhiều) file
   */
  public async pickFile(options: {
    allowMultiple?: boolean;
    allowedExtensions?: string[];
  } = {}): Promise<{
    files: Array<{
      fileName: string;
      mimeType: string;
      sizeBytes: number;
      path: string;
    }>;
    count: number;
  }> {
    return this.transport.invoke('pickFile', options);
  }

  /**
   * Mở màn hình xem trước 1 file (PDF, ảnh...) trong Super App
   */
  public async filePreview(options: {
    fileUrl: string;
    fileName?: string;
    fileType?: string;
  }): Promise<{ success: boolean; fileName: string; fileUrl: string }> {
    return this.transport.invoke('filePreview', options);
  }
}
