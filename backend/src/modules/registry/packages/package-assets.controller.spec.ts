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
  it('sets a file extension MIME type for nested CSS/JS/HTML paths', async () => {
    for (const [filename, extension] of [['dist/index.html', '.html'], ['dist/assets/app.js', '.js'], ['dist/assets/style.css', '.css']]) {
      await controller.file('demo_app', '1.0.0', filename, response);
      expect(response.type).toHaveBeenCalledWith(extension);
    }
    expect(response.setHeader).toHaveBeenCalledWith('Cache-Control', 'no-store');
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
