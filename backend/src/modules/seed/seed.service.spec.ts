import * as fs from 'fs';
import { SeedService } from './seed.service';

// Exercise the repair path against an already-published version: this used to
// accept any existing HTML, including the generated "sdk_playground loaded" page.
describe('SeedService system bundles', () => {
  const html = Buffer.from('<html><body><div id="root"></div><script>renderApp()</script></body></html>');
  const manifest = { appId: 'sdk_playground', version: '1.0.5', name: 'SDK Playground (React)', permissions: [] };
  const icon = Buffer.from('icon');
  const manifestBuffer = Buffer.from(JSON.stringify(manifest, null, 2));
  let service: SeedService;
  let versions: any;
  let packages: any;
  let version: any;

  beforeEach(() => {
    version = { appId: manifest.appId, version: manifest.version, packageKey: 'old-package' };
    versions = { findOne: jest.fn().mockResolvedValue(version), save: jest.fn().mockResolvedValue(undefined) };
    packages = { file: jest.fn(), store: jest.fn().mockResolvedValue('new-package') };
    service = new SeedService({} as any, versions, {} as any, packages);
    jest.spyOn(service as any, 'getMiniAppBundle').mockReturnValue({ html, icon, allFiles: new Map([['dist/index.html', html], ['dist/main.dart.js', Buffer.from('compiled-flutter')]]) });
  });

  afterEach(() => jest.restoreAllMocks());

  it('replaces a placeholder and persists the new package key and checksum', async () => {
    packages.file.mockResolvedValue(Buffer.from('<h3>sdk_playground loaded</h3>'));
    expect(await (service as any).ensurePackageStored(manifest.appId, manifest.version, manifest)).toBe('new-package');
    expect(packages.store.mock.calls[0][0].files.get('dist/index.html')).toEqual(html);
    expect(versions.save).toHaveBeenCalledWith(expect.objectContaining({
      packageKey: 'new-package', checksum: expect.stringMatching(/^[a-f0-9]{64}$/),
      packageSize: html.length + icon.length + manifestBuffer.length + Buffer.byteLength('compiled-flutter'),
    }));
  });

  it('keeps an identical built package on subsequent restarts', async () => {
    packages.file.mockImplementation(async (_key: string, name: string) => new Map([
      ['app.json', manifestBuffer], ['icon.png', icon], ['dist/index.html', html], ['dist/main.dart.js', Buffer.from('compiled-flutter')],
    ]).get(name));
    expect(await (service as any).ensurePackageStored(manifest.appId, manifest.version, manifest)).toBe('old-package');
    expect(packages.store).not.toHaveBeenCalled();
    expect(versions.save).not.toHaveBeenCalled();
  });

  it('restores a published package whose files are missing', async () => {
    packages.file.mockRejectedValue(Object.assign(new Error('missing'), { code: 'ENOENT' }));
    await (service as any).ensurePackageStored(manifest.appId, manifest.version, manifest);
    expect(versions.save).toHaveBeenCalledWith(expect.objectContaining({ packageKey: 'new-package' }));
  });

  it('replaces a package when Flutter JS changes while index.html stays the same', async () => {
    packages.file.mockImplementation(async (_key: string, name: string) => new Map([
      ['app.json', manifestBuffer], ['icon.png', icon], ['dist/index.html', html], ['dist/main.dart.js', Buffer.from('old-flutter')],
    ]).get(name));
    await (service as any).ensurePackageStored(manifest.appId, manifest.version, manifest);
    expect(packages.store.mock.calls[0][0].files.get('dist/main.dart.js')).toEqual(Buffer.from('compiled-flutter'));
    expect(versions.save).toHaveBeenCalledWith(expect.objectContaining({packageKey: 'new-package', manifest}));
  });

  it('fails rather than publishing placeholder HTML when builds are absent', async () => {
    jest.restoreAllMocks();
    jest.spyOn(fs, 'existsSync').mockReturnValue(false);
    await expect((service as any).ensurePackageStored(manifest.appId, manifest.version, manifest))
      .rejects.toThrow('Missing built bundle for sdk_playground');
    expect(packages.store).not.toHaveBeenCalled();
  });
});
