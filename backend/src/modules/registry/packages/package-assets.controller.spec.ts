import { BadRequestException, ForbiddenException, NotFoundException } from '@nestjs/common';
import { MiniAppStatus } from '../../../entities/enums';
import { PackageAssetsController } from './package-assets.controller';

describe('Package asset delivery', () => {
  let app: any;
  let snapshot: any;
  let packages: any;
  let controller: PackageAssetsController;
  let response: any;
  beforeEach(() => {
    app = { id: 'demo_app', status: MiniAppStatus.PUBLISHED, activePublishedVersion: '1.0.0' };
    snapshot = { packageKey: '11111111-1111-4111-8111-111111111111', manifest: { icon: 'icon.png' } };
    packages = { file: jest.fn(async () => Buffer.from('content')) };
    controller = new PackageAssetsController({ findOneBy: async () => app } as any, { findOneBy: async () => snapshot } as any, packages);
    response = { setHeader: jest.fn(), type: jest.fn().mockReturnThis(), send: jest.fn() };
  });
  it('sets a file extension MIME type and Cache-Control headers', async () => {
    await controller.file('demo_app', '1.0.0', 'dist/index.html', response);
    expect(response.type).toHaveBeenCalledWith('.html');
    expect(response.setHeader).toHaveBeenCalledWith('Cache-Control', 'no-cache');

    await controller.file('demo_app', '1.0.0', 'dist/assets/app.js', response);
    expect(response.type).toHaveBeenCalledWith('.js');
    expect(response.setHeader).toHaveBeenCalledWith('Cache-Control', 'public, max-age=31536000, immutable');

    await controller.file('demo_app', '1.0.0', 'dist/assets/style.css', response);
    expect(response.type).toHaveBeenCalledWith('.css');
    expect(response.setHeader).toHaveBeenCalledWith('Cache-Control', 'public, max-age=31536000, immutable');
  });
  it('returns 304 when ETag matches If-None-Match header', async () => {
    const endMock = jest.fn();
    response.status = jest.fn().mockReturnValue({ end: endMock });
    const req: any = { headers: {} };

    await controller.file('demo_app', '1.0.0', 'dist/index.html', response, req);
    const etagCall = response.setHeader.mock.calls.find((call: any[]) => call[0] === 'ETag');
    expect(etagCall).toBeDefined();
    const calculatedEtag = etagCall[1];

    req.headers['if-none-match'] = calculatedEtag;
    await controller.file('demo_app', '1.0.0', 'dist/index.html', response, req);
    expect(response.status).toHaveBeenCalledWith(304);
    expect(endMock).toHaveBeenCalled();
  });
  it('blocks runtime resources for hidden apps', async () => {
    app.status = MiniAppStatus.UNPUBLISHED;
    await expect(controller.file('demo_app', '1.0.0', 'dist/index.html', response)).rejects.toThrow(ForbiddenException);
    expect(packages.file).not.toHaveBeenCalled();
  });
  it('keeps package icons accessible to management while hidden', async () => {
    app.status = MiniAppStatus.UNPUBLISHED;
    await controller.file('demo_app', '1.0.0', 'icon.png', response);
    expect(response.type).toHaveBeenCalledWith('.png');
  });
  it('blocks inactive versions and path traversal', async () => {
    await expect(controller.file('demo_app', '0.9.0', 'dist/index.html', response)).rejects.toThrow(ForbiddenException);
    await expect(controller.file('demo_app', '1.0.0', '../app.json', response)).rejects.toThrow(BadRequestException);
  });
  it('returns 404 for missing package files', async () => {
    packages.file.mockRejectedValue(Object.assign(new Error('missing'), { code: 'ENOENT' }));
    await expect(controller.file('demo_app', '1.0.0', 'dist/missing.js', response)).rejects.toThrow(NotFoundException);
  });
});
