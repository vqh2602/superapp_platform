import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ConflictException,
  ForbiddenException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { MiniAppEntity } from '../../entities/mini-app.entity';
import { MiniAppVersionEntity } from '../../entities/mini-app-version.entity';
import { ReviewAuditEntity } from '../../entities/review-audit.entity';
import { MiniAppStatus, MiniAppRuntimeType, ReviewAction } from '../../entities/enums';
import { CreateMiniAppDto } from './dto/create-app.dto';
import { UpdateDraftDto } from './dto/update-draft.dto';
import { SubmitReviewDto } from './dto/submit-review.dto';
import { ReviewActionDto, ReviewDecision } from './dto/review-action.dto';

@Injectable()
export class RegistryService {
  constructor(
    @InjectRepository(MiniAppEntity)
    private readonly appRepo: Repository<MiniAppEntity>,
    @InjectRepository(MiniAppVersionEntity)
    private readonly versionRepo: Repository<MiniAppVersionEntity>,
    @InjectRepository(ReviewAuditEntity)
    private readonly auditRepo: Repository<ReviewAuditEntity>,
  ) {}

  /**
   * Customer creates a new Draft Mini App
   */
  async createDraft(tenantId: string, dto: CreateMiniAppDto): Promise<MiniAppEntity> {
    const existing = await this.appRepo.findOne({ where: { id: dto.id } });
    if (existing) {
      throw new ConflictException(`Mini App with ID "${dto.id}" already exists`);
    }

    const app = this.appRepo.create({
      id: dto.id,
      name: dto.name,
      description: dto.description || '',
      icon: dto.icon || 'code',
      category: dto.category || 'General',
      tenantId: tenantId,
      runtimeType: dto.runtimeType || MiniAppRuntimeType.SCHEMA,
      status: MiniAppStatus.DRAFT,
      capabilities: dto.capabilities || [],
      draftSchema: dto.draftSchema || {
        schemaVersion: 1,
        pages: [
          {
            id: 'home',
            title: dto.name,
            components: [
              {
                id: 'welcome_text',
                type: 'text',
                props: { value: `Chào mừng bạn đến với ${dto.name}` },
              },
            ],
          },
        ],
      },
    });

    return this.appRepo.save(app);
  }

  /**
   * List all apps belonging to tenant
   */
  async getTenantApps(tenantId: string): Promise<MiniAppEntity[]> {
    return this.appRepo.find({
      where: { tenantId },
      relations: ['versions'],
      order: { updatedAt: 'DESC' },
    });
  }

  /**
   * List all apps across all tenants (for Admin)
   */
  async getAllApps(): Promise<MiniAppEntity[]> {
    return this.appRepo.find({
      relations: ['versions'],
      order: { updatedAt: 'DESC' },
    });
  }

  /**
   * Get review audit history
   */
  async getAudits(appId?: string): Promise<ReviewAuditEntity[]> {
    if (appId) {
      return this.auditRepo.find({
        where: { appId },
        order: { timestamp: 'DESC' },
      });
    }
    return this.auditRepo.find({
      order: { timestamp: 'DESC' },
    });
  }

  /**
   * Get app details + draft + version history
   */
  async getAppDetails(appId: string, tenantId?: string): Promise<MiniAppEntity> {
    const query = this.appRepo
      .createQueryBuilder('app')
      .leftJoinAndSelect('app.versions', 'versions')
      .where('app.id = :appId', { appId })
      .orderBy('versions.createdAt', 'DESC');

    if (tenantId) {
      query.andWhere('app.tenantId = :tenantId', { tenantId });
    }

    const app = await query.getOne();
    if (!app) {
      throw new NotFoundException(`Mini App "${appId}" not found`);
    }

    return app;
  }

  /**
   * Update draft configuration and schema
   */
  async updateDraft(appId: string, tenantId: string, dto: UpdateDraftDto): Promise<MiniAppEntity> {
    const app = await this.appRepo.findOne({ where: { id: appId } });
    if (!app) {
      throw new NotFoundException(`Mini App "${appId}" not found`);
    }

    if (app.tenantId !== tenantId) {
      throw new ForbiddenException('You do not have permission to modify this Mini App');
    }

    if (dto.name !== undefined) app.name = dto.name;
    if (dto.description !== undefined) app.description = dto.description;
    if (dto.icon !== undefined) app.icon = dto.icon;
    if (dto.category !== undefined) app.category = dto.category;
    if (dto.capabilities !== undefined) app.capabilities = dto.capabilities;
    if (dto.draftSchema !== undefined) app.draftSchema = dto.draftSchema;

    return this.appRepo.save(app);
  }

  /**
   * Submit draft for review -> Creates immutable version snapshot
   */
  async submitForReview(
    appId: string,
    tenantId: string,
    actorId: string,
    dto: SubmitReviewDto,
  ): Promise<MiniAppVersionEntity> {
    const app = await this.appRepo.findOne({ where: { id: appId } });
    if (!app) {
      throw new NotFoundException(`Mini App "${appId}" not found`);
    }

    if (app.tenantId !== tenantId) {
      throw new ForbiddenException('You do not have permission to submit this Mini App');
    }

    // Check version duplicate
    const existingVer = await this.versionRepo.findOne({
      where: { appId, version: dto.version },
    });
    if (existingVer) {
      throw new ConflictException(`Version "${dto.version}" for app "${appId}" has already been submitted`);
    }

    // Validate schema
    if (app.runtimeType === MiniAppRuntimeType.SCHEMA && (!app.draftSchema || !app.draftSchema.pages?.length)) {
      throw new BadRequestException('Mini App schema must contain at least 1 page before submitting');
    }

    const now = new Date();
    const versionSnapshot = this.versionRepo.create({
      appId,
      version: dto.version,
      schemaVersion: 1,
      status: MiniAppStatus.SUBMITTED,
      schema: app.draftSchema,
      entryUrl: app.entryUrl,
      capabilities: app.capabilities,
      reviewNotes: dto.notes || '',
      submittedAt: now,
    });

    const savedVersion = await this.versionRepo.save(versionSnapshot);

    // Update app status
    app.status = MiniAppStatus.SUBMITTED;
    await this.appRepo.save(app);

    // Audit log
    await this.auditRepo.save(
      this.auditRepo.create({
        appId,
        version: dto.version,
        action: ReviewAction.SUBMIT,
        actorId,
        actorRole: 'customer',
        reason: dto.notes || 'Submitted version for review',
        timestamp: now,
      }),
    );

    return savedVersion;
  }

  /**
   * Admin reviews submitted version (Approve / Reject)
   */
  async reviewVersion(
    appId: string,
    actorId: string,
    dto: ReviewActionDto,
  ): Promise<MiniAppVersionEntity> {
    const version = await this.versionRepo.findOne({
      where: { appId, version: dto.version },
    });
    if (!version) {
      throw new NotFoundException(`Version "${dto.version}" of app "${appId}" not found`);
    }

    if (version.status !== MiniAppStatus.SUBMITTED && version.status !== MiniAppStatus.IN_REVIEW) {
      throw new BadRequestException(`Cannot review version in status "${version.status}"`);
    }

    const now = new Date();
    const app = await this.appRepo.findOne({ where: { id: appId } });

    if (dto.decision === ReviewDecision.APPROVE) {
      version.status = MiniAppStatus.APPROVED;
      version.reviewedAt = now;
      version.reviewNotes = dto.notes || 'Approved by admin';

      if (app && app.status !== MiniAppStatus.PUBLISHED) {
        app.status = MiniAppStatus.APPROVED;
        await this.appRepo.save(app);
      }

      await this.auditRepo.save(
        this.auditRepo.create({
          appId,
          version: dto.version,
          action: ReviewAction.APPROVE,
          actorId,
          actorRole: 'admin',
          reason: dto.notes || 'Approved',
          timestamp: now,
        }),
      );
    } else {
      version.status = MiniAppStatus.REJECTED;
      version.reviewedAt = now;
      version.reviewNotes = dto.notes || 'Rejected by admin';

      if (app && app.status !== MiniAppStatus.PUBLISHED) {
        app.status = MiniAppStatus.REJECTED;
        await this.appRepo.save(app);
      }

      await this.auditRepo.save(
        this.auditRepo.create({
          appId,
          version: dto.version,
          action: ReviewAction.REJECT,
          actorId,
          actorRole: 'admin',
          reason: dto.notes || 'Rejected',
          timestamp: now,
        }),
      );
    }

    return this.versionRepo.save(version);
  }

  /**
   * Admin publishes approved version -> updates activePublishedVersion atomically
   */
  async publishVersion(appId: string, versionStr: string, actorId: string): Promise<MiniAppEntity> {
    const version = await this.versionRepo.findOne({
      where: { appId, version: versionStr },
    });
    if (!version) {
      throw new NotFoundException(`Version "${versionStr}" of app "${appId}" not found`);
    }

    if (version.status !== MiniAppStatus.APPROVED && version.status !== MiniAppStatus.PUBLISHED) {
      throw new BadRequestException(
        `Version must be APPROVED before publishing. Current status: ${version.status}`,
      );
    }

    const app = await this.appRepo.findOne({ where: { id: appId } });
    if (!app) {
      throw new NotFoundException(`Mini App "${appId}" not found`);
    }

    const now = new Date();
    version.status = MiniAppStatus.PUBLISHED;
    version.publishedAt = now;
    await this.versionRepo.save(version);

    // Atomically set active published version
    app.activePublishedVersion = versionStr;
    app.status = MiniAppStatus.PUBLISHED;
    const updatedApp = await this.appRepo.save(app);

    await this.auditRepo.save(
      this.auditRepo.create({
        appId,
        version: versionStr,
        action: ReviewAction.PUBLISH,
        actorId,
        actorRole: 'admin',
        reason: `Published version ${versionStr}`,
        timestamp: now,
      }),
    );

    return updatedApp;
  }

  /**
   * Admin unpublishes app -> immediately hidden from catalog and direct launch blocked
   */
  async unpublishApp(appId: string, actorId: string, reason?: string): Promise<MiniAppEntity> {
    const app = await this.appRepo.findOne({ where: { id: appId } });
    if (!app) {
      throw new NotFoundException(`Mini App "${appId}" not found`);
    }

    app.status = MiniAppStatus.UNPUBLISHED;
    const saved = await this.appRepo.save(app);

    await this.auditRepo.save(
      this.auditRepo.create({
        appId,
        version: app.activePublishedVersion || 'unknown',
        action: ReviewAction.UNPUBLISH,
        actorId,
        actorRole: 'admin',
        reason: reason || 'Unpublished by admin',
        timestamp: new Date(),
      }),
    );

    return saved;
  }

  /**
   * Rollback to a previous approved/published version
   */
  async rollbackApp(appId: string, targetVersion: string, actorId: string, reason?: string): Promise<MiniAppEntity> {
    const target = await this.versionRepo.findOne({
      where: { appId, version: targetVersion },
    });
    if (!target) {
      throw new NotFoundException(`Target version "${targetVersion}" of app "${appId}" not found`);
    }

    if (target.status !== MiniAppStatus.APPROVED && target.status !== MiniAppStatus.PUBLISHED) {
      throw new BadRequestException(
        `Target version must have been APPROVED or PUBLISHED. Status: ${target.status}`,
      );
    }

    const app = await this.appRepo.findOne({ where: { id: appId } });
    if (!app) {
      throw new NotFoundException(`Mini App "${appId}" not found`);
    }

    app.activePublishedVersion = targetVersion;
    app.status = MiniAppStatus.PUBLISHED;
    const saved = await this.appRepo.save(app);

    await this.auditRepo.save(
      this.auditRepo.create({
        appId,
        version: targetVersion,
        action: ReviewAction.ROLLBACK,
        actorId,
        actorRole: 'admin',
        reason: reason || `Rollback to version ${targetVersion}`,
        timestamp: new Date(),
      }),
    );

    return saved;
  }

  /**
   * Suspend an app due to policy violation or security risk
   */
  async suspendApp(appId: string, actorId: string, reason?: string): Promise<MiniAppEntity> {
    const app = await this.appRepo.findOne({ where: { id: appId } });
    if (!app) {
      throw new NotFoundException(`Mini App "${appId}" not found`);
    }

    app.status = MiniAppStatus.SUSPENDED;
    const saved = await this.appRepo.save(app);

    await this.auditRepo.save(
      this.auditRepo.create({
        appId,
        version: app.activePublishedVersion || 'unknown',
        action: ReviewAction.SUSPEND,
        actorId,
        actorRole: 'admin',
        reason: reason || 'Suspended for safety/compliance review',
        timestamp: new Date(),
      }),
    );

    return saved;
  }
}
