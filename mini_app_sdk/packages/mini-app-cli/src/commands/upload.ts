import fs from 'node:fs';
import path from 'node:path';
import { loadManifest } from '../utils/config.js';
import { logger } from '../utils/logger.js';

export interface UploadCommandOptions {
  registry?: string;
  tenantId?: string;
  actorId?: string;
  submit?: boolean;
  notes?: string;
}

export async function uploadProject(options: UploadCommandOptions = {}): Promise<void> {
  const manifest = loadManifest();
  const registryUrl = options.registry || process.env.SUPERAPP_REGISTRY_URL || 'http://localhost:3000';
  const tenantId = options.tenantId || 'tenant_001';
  const actorId = options.actorId || 'dev_partner_001';

  logger.title(`Tải lên SuperApp Dynamic Registry: ${manifest.name}`);

  const distPath = path.resolve(process.cwd(), 'dist');
  const metaPath = path.join(distPath, 'bundle-meta.json');

  if (!fs.existsSync(metaPath)) {
    logger.warn('Chưa tìm thấy bundle đã build. Đang tự động chạy build trước...');
    const { buildProject } = await import('./build.js');
    await buildProject();
  }

  const bundleMeta = JSON.parse(fs.readFileSync(metaPath, 'utf-8'));

  logger.step(1, 3, `Đang kết nối đến Dynamic Registry Backend: ${registryUrl}`);
  logger.info(`Tenant ID: ${tenantId}`);
  logger.info(`App ID: ${manifest.appId} (v${manifest.version})`);

  // Payload aligning with backend RegistryService
  const updatePayload = {
    name: manifest.name,
    category: manifest.category || 'utilities',
    description: manifest.description || '',
    iconUrl: manifest.iconUrl || '',
    runtimeType: 'web',
    schemaDraft: {
      version: manifest.version,
      entry: manifest.entry,
      permissions: manifest.permissions || [],
      checksum: bundleMeta.checksum,
      themeColor: manifest.themeColor || '#0068FF',
      uploadedAt: new Date().toISOString(),
    },
  };

  try {
    // 1. Check or update draft
    logger.step(2, 3, `Cập nhật bản thảo (Draft) lên Registry...`);
    const updateRes = await fetch(`${registryUrl}/api/v1/registry/apps/${manifest.appId}`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        'x-tenant-id': tenantId,
      },
      body: JSON.stringify(updatePayload),
    });

    if (!updateRes.ok) {
      // If 404, create new draft
      if (updateRes.status === 404) {
        logger.info(`Mini App chưa tồn tại. Đang tạo mới bản ghi ứng dụng...`);
        const createRes = await fetch(`${registryUrl}/api/v1/registry/apps`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'x-tenant-id': tenantId,
          },
          body: JSON.stringify({
            appId: manifest.appId,
            ...updatePayload,
          }),
        });

        if (!createRes.ok) {
          const errText = await createRes.text();
          throw new Error(`Tạo mới thất bại (HTTP ${createRes.status}): ${errText}`);
        }
      } else {
        const errText = await updateRes.text();
        throw new Error(`Cập nhật thất bại (HTTP ${updateRes.status}): ${errText}`);
      }
    }

    logger.success(`Cập nhật bản nháp Mini App thành công!`);

    // 2. Submit for review if requested
    if (options.submit) {
      logger.step(3, 3, `Gửi yêu cầu xét duyệt phiên bản ${manifest.version}...`);
      const submitRes = await fetch(`${registryUrl}/api/v1/registry/apps/${manifest.appId}/submit`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-tenant-id': tenantId,
          'x-user-id': actorId,
        },
        body: JSON.stringify({
          version: manifest.version,
          changelog: options.notes || `Phát hành phiên bản ${manifest.version} từ Mini App CLI`,
        }),
      });

      if (!submitRes.ok) {
        const errText = await submitRes.text();
        throw new Error(`Gửi xét duyệt thất bại (HTTP ${submitRes.status}): ${errText}`);
      }

      logger.success(`Đã gửi xét duyệt phiên bản v${manifest.version}! Trạng thái: SUBMITTED`);
      logger.info(`Admin có thể phê duyệt tại: http://localhost:5174/admin`);
    } else {
      logger.step(3, 3, `Bản nháp đã được lưu. Để gửi xét duyệt, chạy lại kèm cờ --submit`);
    }

    console.log(`\n🎉 Hoàn tất quy trình xuất bản!`);
  } catch (err: any) {
    logger.error('Lỗi khi tải lên SuperApp Registry:', err.message);
    process.exit(1);
  }
}
