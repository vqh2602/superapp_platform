import { BadRequestException } from '@nestjs/common';
import { mkdtemp, readdir, rm } from 'fs/promises';
import { tmpdir } from 'os';
import { join } from 'path';
import { MiniAppRuntimeType } from '../../../entities/enums';
import { PackageService } from './package.service';
import { makePackage, packageEntries, testManifest, zipFiles } from './test-package';

describe('Super App package v1', () => {
  const service = new PackageService();
  it('validates a web package and computes the actual archive checksum', async () => {
    const pkg = await service.inspect(await makePackage(), testManifest.appId);
    expect(pkg.manifest.version).toBe('1.0.0');
    expect(pkg.files.has('dist/assets/app.js')).toBe(true);
    expect(pkg.checksum).toMatch(/^[a-f0-9]{64}$/);
  });
  it('loads schema packages from their declared entry', async () => {
    const pkg = await service.inspect(await makePackage({ ...testManifest, runtimeType: MiniAppRuntimeType.SCHEMA, entry: 'schema.json' }), testManifest.appId);
    expect(pkg.schema.pages[0].id).toBe('home');
  });
  it('rejects non-ZIP and malformed manifest JSON', async () => {
    await expect(service.inspect(Buffer.from('not zip'), testManifest.appId)).rejects.toThrow(BadRequestException);
    await expect(service.inspect(await zipFiles([['app.json', '{']]), testManifest.appId)).rejects.toThrow(BadRequestException);
  });
  it('rejects mismatched App ID', async () => {
    await expect(service.inspect(await makePackage(), 'another_app')).rejects.toThrow('khác Mini App');
  });
  it.each([
    { manifestVersion: 2 }, { version: 'latest' }, { version: '01.0.0' }, { permissions: [1] },
    { permissions: ['bad,permission'] }, { permissions: ['navigation.close', 'navigation.close'] },
    { permissions: null }, { runtimeType: 'native' }, { entry: 'index.html' },
    { icon: '../icon.png' }, { icon: 'missing.png' }, { unknownField: 'ignored?' },
    { website: 'javascript:alert(1)' }, { supportEmail: 123 },
  ])('rejects invalid manifest fields %p', async overrides => {
    await expect(service.inspect(await makePackage({ ...testManifest, ...overrides }), testManifest.appId)).rejects.toThrow(BadRequestException);
  });
  it.each(['app.json', 'dist/index.html', 'icon.png'])('requires file %s', async missing => {
    await expect(service.inspect(await zipFiles(packageEntries().filter(([name]) => name !== missing)), testManifest.appId)).rejects.toThrow(BadRequestException);
  });
  it('rejects missing/wrong schema data', async () => {
    const manifest = { ...testManifest, runtimeType: 'schema', entry: 'schema.json' };
    const entries = packageEntries(manifest).map(([name, value]) => [name, name === 'schema.json' ? '{"pages":[]}' : value] as [string, Buffer | string]);
    await expect(service.inspect(await zipFiles(entries), testManifest.appId)).rejects.toThrow(BadRequestException);
  });
  it('rejects duplicate names', async () => {
    await expect(service.inspect(await zipFiles([...packageEntries(), ['icon.png', 'duplicate']]), testManifest.appId)).rejects.toThrow(BadRequestException);
  });
  it('rejects traversal filenames from the ZIP directory', async () => {
    const buffer = await zipFiles([...packageEntries(), ['ok/evil.txt', 'evil']]);
    const malicious = Buffer.from(buffer.toString('binary').split('ok/evil.txt').join('../evil.txt'), 'binary');
    await expect(service.inspect(malicious, testManifest.appId)).rejects.toThrow(BadRequestException);
  });
  it('rejects ZIP bombs by expanded entry size', async () => {
    const buffer = await zipFiles([...packageEntries(), ['dist/large.js', Buffer.alloc(11 * 1024 * 1024)]]);
    await expect(service.inspect(buffer, testManifest.appId)).rejects.toThrow(BadRequestException);
  });
  it('rejects images with the wrong content', async () => {
    const entries = packageEntries().map(([name, value]) => [name, name === 'icon.png' ? 'not a PNG' : value] as [string, Buffer | string]);
    await expect(service.inspect(await zipFiles(entries), testManifest.appId)).rejects.toThrow(BadRequestException);
  });
  it('stores and reads all files without leaving data after removal', async () => {
    const root = await mkdtemp(join(tmpdir(), 'miniapp-package-'));
    jest.spyOn(service, 'storageRoot', 'get').mockReturnValue(root);
    try {
      const pkg = await service.inspect(await makePackage(), testManifest.appId);
      const key = await service.store(pkg);
      expect((await service.file(key, 'dist/assets/app.js')).toString()).toContain('Mini App running');
      await expect(service.file(key, '../app.json')).rejects.toThrow(BadRequestException);
      await service.remove(key);
      expect(await readdir(root)).toEqual([]);
    } finally { jest.restoreAllMocks(); await rm(root, { recursive: true, force: true }); }
  });
});
