export class MediaMockHandler {
  public async scanQRCode(payload: { prompt?: string } = {}): Promise<any> {
    return {
      content: 'https://superapp.vn/pay?order=mock_qr_12345',
      format: 'QR_CODE',
    };
  }

  public async chooseImage(payload: { count?: number } = {}): Promise<any> {
    const count = payload.count || 1;
    const dummyImages = [
      'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=500',
      'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=500',
    ];
    return {
      tempFilePaths: dummyImages.slice(0, count),
      count: Math.min(count, dummyImages.length),
    };
  }
}
