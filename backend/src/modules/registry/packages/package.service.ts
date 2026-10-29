import { BadRequestException, Injectable } from '@nestjs/common';
import { plainToInstance } from 'class-transformer';
import { validateSync } from 'class-validator';
import { createHash, randomUUID } from 'crypto';
import { mkdir, readFile, rm, writeFile } from 'fs/promises';
import { posix, resolve, join } from 'path';
import * as yauzl from 'yauzl';
import { MiniAppRuntimeType } from '../../../entities/enums';
import { PackageManifest } from './package-manifest';

export const MAX_PACKAGE_BYTES = 20 * 1024 * 1024;
const MAX_EXPANDED_BYTES = 50 * 1024 * 1024;
const MAX_FILE_BYTES = 10 * 1024 * 1024;
const MAX_FILES = 500;

export interface ValidatedPackage {
  manifest: PackageManifest;
  files: Map<string, Buffer>;
  checksum: string;
  size: number;
  schema?: Record<string, any>;
}

export function safePackagePath(name: string): boolean {
  return typeof name === 'string' && /^[a-zA-Z0-9_][a-zA-Z0-9_./-]*$/.test(name) &&
    !name.split('/').some(part => part === '..' || part === '.' || part === '') &&
    posix.normalize(name) === name;
}

@Injectable()
export class PackageService {
  get storageRoot() {
    return resolve(process.env.MINIAPP_STORAGE_DIR || 'storage/miniapps');
  }

  async inspect(buffer: Buffer, expectedAppId: string): Promise<ValidatedPackage> {
    if (!buffer?.length) throw new BadRequestException('Chọn file ZIP Mini App');
    if (buffer.length > MAX_PACKAGE_BYTES) throw new BadRequestException('Gói ZIP tối đa 20 MB');
    const files = await this.readZip(buffer);
    if (!files.has('app.json')) throw new BadRequestException('Thiếu app.json tại thư mục gốc của ZIP');
    const data = this.json(files.get('app.json'), 'app.json');
    const manifest = plainToInstance(PackageManifest, data);
    const errors = validateSync(manifest, { whitelist: true, forbidNonWhitelisted: true });
    if (errors.length) throw new BadRequestException(errors.flatMap(error => Object.values(error.constraints || {})));
    if (manifest.appId !== expectedAppId) throw new BadRequestException(`App ID trong gói (${manifest.appId}) khác Mini App đang chọn (${expectedAppId})`);
    const entry = manifest.runtimeType === MiniAppRuntimeType.WEB ? 'dist/index.html' : 'schema.json';
    if (manifest.entry !== entry || !files.get(entry)?.length) {
      throw new BadRequestException(`runtimeType ${manifest.runtimeType} yêu cầu entry "${entry}" và file tương ứng trong ZIP`);
    }
    if (!safePackagePath(manifest.icon) || !/\.(png|jpe?g|webp)$/i.test(manifest.icon) || !files.has(manifest.icon)) {
      throw new BadRequestException('icon phải trỏ tới file PNG/JPEG/WebP có trong ZIP');
    }
    this.validateImage(files.get(manifest.icon), manifest.icon);
    let schema: Record<string, any> | undefined;
    if (manifest.runtimeType === MiniAppRuntimeType.SCHEMA) {
      schema = this.json(files.get(entry), entry);
      if (!Number.isInteger(schema.schemaVersion) || schema.schemaVersion < 1 ||
          !Array.isArray(schema.pages) || !schema.pages.length ||
          schema.pages.some((page: any) => !page || typeof page.id !== 'string' ||
            !page.id.trim() || !Array.isArray(page.components)) ||
          new Set(schema.pages.map((page: any) => page.id)).size !== schema.pages.length) {
        throw new BadRequestException('schema.json cần schemaVersion nguyên dương và pages có id duy nhất, components dạng mảng');
      }
    }
    return { manifest, files, schema, checksum: createHash('sha256').update(buffer).digest('hex'), size: buffer.length };
  }

  async store(pkg: ValidatedPackage): Promise<string> {
    const key = randomUUID();
    const directory = join(this.storageRoot, key);
    try {
      for (const [name, content] of pkg.files) {
        const target = join(directory, name);
        await mkdir(resolve(target, '..'), { recursive: true });
        await writeFile(target, content, { flag: 'wx' });
      }
      return key;
    } catch (error) {
      await this.remove(key);
      throw error;
    }
  }

  async remove(key: string) {
    await rm(join(this.storageRoot, key), { recursive: true, force: true });
  }

  async file(key: string, name: string): Promise<Buffer> {
    if (!/^[a-zA-Z0-9_.-]+$/.test(key) || !safePackagePath(name)) throw new BadRequestException('Đường dẫn tài nguyên không hợp lệ');
    return readFile(join(this.storageRoot, key, name));
  }

  private json(buffer: Buffer, file: string): Record<string, any> {
    try {
      if (buffer.length > 1024 * 1024) throw new Error();
      const value = JSON.parse(buffer.toString('utf8'));
      if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error();
      return value;
    } catch { throw new BadRequestException(`${file} phải là JSON object hợp lệ, tối đa 1 MB`); }
  }

  private validateImage(buffer: Buffer, name: string) {
    const valid = /\.png$/i.test(name) ? buffer.subarray(0, 8).equals(Buffer.from([137,80,78,71,13,10,26,10]))
      : /\.jpe?g$/i.test(name) ? buffer[0] === 255 && buffer[1] === 216 && buffer[2] === 255
      : buffer.toString('ascii', 0, 4) === 'RIFF' && buffer.toString('ascii', 8, 12) === 'WEBP';
    if (!valid || buffer.length > 2 * 1024 * 1024) throw new BadRequestException('Icon không đúng định dạng ảnh hoặc lớn hơn 2 MB');
  }

  private readZip(buffer: Buffer): Promise<Map<string, Buffer>> {
    return new Promise((resolveFiles, reject) => {
      yauzl.fromBuffer(buffer, { lazyEntries: true, validateEntrySizes: true, strictFileNames: true }, (error, zip) => {
        if (error) { reject(new BadRequestException('File ZIP không hợp lệ')); return; }
        const files = new Map<string, Buffer>();
        const names = new Set<string>();
        let total = 0;
        let count = 0;
        const fail = (reason: unknown) => { zip.close(); reject(reason instanceof BadRequestException ? reason : new BadRequestException('Không đọc được gói ZIP')); };
        zip.on('error', fail);
        zip.on('end', () => resolveFiles(files));
        zip.on('entry', (entry: yauzl.Entry) => {
          const directory = entry.fileName.endsWith('/');
          const name = directory ? entry.fileName.slice(0, -1) : entry.fileName;
          if (++count > MAX_FILES || !safePackagePath(name) || names.has(name) ||
              ((entry.externalFileAttributes >>> 16) & 0xf000) === 0xa000 ||
              (entry.generalPurposeBitFlag & 1) !== 0 || entry.uncompressedSize > MAX_FILE_BYTES ||
              total + entry.uncompressedSize > MAX_EXPANDED_BYTES) {
            fail(new BadRequestException('ZIP chứa đường dẫn không hợp lệ, file trùng/symlink/mã hóa hoặc vượt giới hạn (500 file, 10 MB/file, 50 MB giải nén)'));
            return;
          }
          names.add(name);
          if (directory) { zip.readEntry(); return; }
          zip.openReadStream(entry, (streamError, stream) => {
            if (streamError) { fail(streamError); return; }
            const chunks: Buffer[] = [];
            let size = 0;
            stream.on('data', (chunk: Buffer) => {
              size += chunk.length; total += chunk.length;
              if (size > MAX_FILE_BYTES || total > MAX_EXPANDED_BYTES) { stream.destroy(new Error('ZIP size limit exceeded')); return; }
              chunks.push(chunk);
            });
            stream.on('error', fail);
            stream.on('end', () => { files.set(name, Buffer.concat(chunks)); zip.readEntry(); });
          });
        });
        zip.readEntry();
      });
    });
  }
}
