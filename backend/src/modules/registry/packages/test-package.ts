import { ZipFile } from 'yazl';
import { PackageManifest } from './package-manifest';
import { MiniAppRuntimeType } from '../../../entities/enums';

export const testIcon = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jZusAAAAASUVORK5CYII=', 'base64');
export const testSchema = { schemaVersion: 1, pages: [{ id: 'home', title: 'Demo', components: [] }] };
export const testManifest: PackageManifest = {
  manifestVersion: 1, appId: 'coffee_shop', name: 'Coffee Shop', description: 'Demo package', category: 'Food',
  version: '1.0.0', runtimeType: MiniAppRuntimeType.WEB, entry: 'dist/index.html', icon: 'icon.png',
  permissions: ['navigation.close', 'payment.createOrder'],
};

export async function zipFiles(entries: Array<[string, Buffer | string]>) {
  const zip = new ZipFile();
  const chunks: Buffer[] = [];
  const result = new Promise<Buffer>((resolve, reject) => {
    zip.outputStream.on('data', chunk => chunks.push(chunk));
    zip.outputStream.on('end', () => resolve(Buffer.concat(chunks)));
    zip.outputStream.on('error', reject);
  });
  for (const [name, value] of entries) zip.addBuffer(Buffer.isBuffer(value) ? value : Buffer.from(value), name);
  zip.end();
  return result;
}

export function packageEntries(manifest: any = testManifest): Array<[string, Buffer | string]> {
  return [
    ['app.json', JSON.stringify(manifest)], ['icon.png', testIcon],
    ['dist/index.html', '<!doctype html><script type="module" src="./assets/app.js"></script>'],
    ['dist/assets/app.js', 'document.body.textContent = "Mini App running";'],
    ['schema.json', JSON.stringify(testSchema)],
  ];
}
export const makePackage = (manifest: any = testManifest) => zipFiles(packageEntries(manifest));
