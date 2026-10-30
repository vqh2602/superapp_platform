import { ITransport } from '../../transport/index.js';

export class FileModule {
  constructor(private transport: ITransport) {}

  /**
   * Lưu tệp tin vào bộ nhớ ứng dụng
   */
  public async saveFile(options: { data: string; fileName: string; mimeType?: string }): Promise<{
    success: boolean;
    filePath: string;
  }> {
    return this.transport.invoke('saveFile', options);
  }

  /**
   * Chọn tệp từ máy (PDF, Docx, Image...)
   */
  public async pickFile(options: { allowedExtensions?: string[]; mimeTypes?: string[] } = {}): Promise<{
    name: string;
    size: number;
    uri: string;
    mimeType?: string;
  }> {
    return this.transport.invoke('pickFile', options);
  }

  /**
   * Xem trước tệp tài liệu bằng trình đọc native
   */
  public async filePreview(options: { filePath: string; title?: string }): Promise<{ success: boolean }> {
    return this.transport.invoke('filePreview', options);
  }
}
