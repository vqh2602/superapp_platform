import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { ConflictException, NotFoundException, BadRequestException, ForbiddenException } from '@nestjs/common';
import { RegistryService } from './registry.service';
import { MiniAppEntity } from '../../entities/mini-app.entity';
import { MiniAppVersionEntity } from '../../entities/mini-app-version.entity';
import { ReviewAuditEntity } from '../../entities/review-audit.entity';
import { MiniAppStatus, MiniAppRuntimeType } from '../../entities/enums';
import { ReviewDecision } from './dto/review-action.dto';

describe('RegistryService Tests', () => {
  let service: RegistryService;
  let mockAppRepo: any;
  let mockVersionRepo: any;
  let mockAuditRepo: any;

  beforeEach(async () => {
    mockAppRepo = {
      findOne: jest.fn(),
      create: jest.fn((dto) => ({ ...dto })),
      save: jest.fn((entity) => Promise.resolve({ ...entity, updatedAt: new Date() })),
      find: jest.fn(),
      createQueryBuilder: jest.fn(),
    };

    mockVersionRepo = {
      findOne: jest.fn(),
      create: jest.fn((dto) => ({ ...dto, id: 'mock_ver_id' })),
      save: jest.fn((entity) => Promise.resolve({ ...entity })),
      find: jest.fn(),
    };

    mockAuditRepo = {
      create: jest.fn((dto) => ({ ...dto, id: 'mock_audit_id' })),
      save: jest.fn((entity) => Promise.resolve(entity)),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        RegistryService,
        { provide: getRepositoryToken(MiniAppEntity), useValue: mockAppRepo },
        { provide: getRepositoryToken(MiniAppVersionEntity), useValue: mockVersionRepo },
        { provide: getRepositoryToken(ReviewAuditEntity), useValue: mockAuditRepo },
      ],
    }).compile();

    service = module.get<RegistryService>(RegistryService);
  });

  describe('createDraft', () => {
    it('creates a new draft app successfully', async () => {
      mockAppRepo.findOne.mockResolvedValue(null);

      const result = await service.createDraft('tenant_123', {
        id: 'coffee_shop',
        name: 'Coffee Shop',
        category: 'Food & Beverage',
      });

      expect(result.id).toBe('coffee_shop');
      expect(result.tenantId).toBe('tenant_123');
      expect(result.status).toBe(MiniAppStatus.DRAFT);
      expect(mockAppRepo.save).toHaveBeenCalled();
    });

    it('throws ConflictException if app ID already exists', async () => {
      mockAppRepo.findOne.mockResolvedValue({ id: 'coffee_shop' });

      await expect(
        service.createDraft('tenant_123', {
          id: 'coffee_shop',
          name: 'Coffee Shop',
        }),
      ).rejects.toThrow(ConflictException);
    });
  });

  describe('updateDraft', () => {
    it('updates draft when tenant matches', async () => {
      mockAppRepo.findOne.mockResolvedValue({
        id: 'coffee_shop',
        tenantId: 'tenant_123',
        name: 'Old Name',
      });

      const updated = await service.updateDraft('coffee_shop', 'tenant_123', {
        name: 'New Name',
      });

      expect(updated.name).toBe('New Name');
    });

    it('rejects update if tenant does not match (tenant isolation)', async () => {
      mockAppRepo.findOne.mockResolvedValue({
        id: 'coffee_shop',
        tenantId: 'tenant_other',
      });

      await expect(
        service.updateDraft('coffee_shop', 'tenant_attacker', { name: 'Hacked' }),
      ).rejects.toThrow(ForbiddenException);
    });
  });

  describe('submitForReview', () => {
    it('creates immutable version snapshot and updates app status', async () => {
      mockAppRepo.findOne.mockResolvedValue({
        id: 'coffee_shop',
        tenantId: 'tenant_123',
        runtimeType: MiniAppRuntimeType.SCHEMA,
        draftSchema: { pages: [{ id: 'home' }] },
        capabilities: ['payment.createOrder'],
      });
      mockVersionRepo.findOne.mockResolvedValue(null);

      const version = await service.submitForReview(
        'coffee_shop',
        'tenant_123',
        'customer_001',
        { version: '1.0.0', notes: 'Initial submission' },
      );

      expect(version.version).toBe('1.0.0');
      expect(version.status).toBe(MiniAppStatus.SUBMITTED);
      expect(mockAuditRepo.save).toHaveBeenCalled();
    });

    it('rejects if version already exists', async () => {
      mockAppRepo.findOne.mockResolvedValue({
        id: 'coffee_shop',
        tenantId: 'tenant_123',
        draftSchema: { pages: [{ id: 'home' }] },
      });
      mockVersionRepo.findOne.mockResolvedValue({ version: '1.0.0' });

      await expect(
        service.submitForReview('coffee_shop', 'tenant_123', 'customer_001', {
          version: '1.0.0',
        }),
      ).rejects.toThrow(ConflictException);
    });
  });

  describe('reviewVersion', () => {
    it('approves submitted version', async () => {
      mockVersionRepo.findOne.mockResolvedValue({
        appId: 'coffee_shop',
        version: '1.0.0',
        status: MiniAppStatus.SUBMITTED,
      });
      mockAppRepo.findOne.mockResolvedValue({
        id: 'coffee_shop',
        status: MiniAppStatus.SUBMITTED,
      });

      const res = await service.reviewVersion('coffee_shop', 'admin_001', {
        version: '1.0.0',
        decision: ReviewDecision.APPROVE,
        notes: 'Looks great',
      });

      expect(res.status).toBe(MiniAppStatus.APPROVED);
    });

    it('rejects submitted version with feedback', async () => {
      mockVersionRepo.findOne.mockResolvedValue({
        appId: 'coffee_shop',
        version: '1.0.0',
        status: MiniAppStatus.SUBMITTED,
      });
      mockAppRepo.findOne.mockResolvedValue({
        id: 'coffee_shop',
        status: MiniAppStatus.SUBMITTED,
      });

      const res = await service.reviewVersion('coffee_shop', 'admin_001', {
        version: '1.0.0',
        decision: ReviewDecision.REJECT,
        notes: 'Missing logo',
      });

      expect(res.status).toBe(MiniAppStatus.REJECTED);
    });
  });

  describe('publishVersion', () => {
    it('publishes approved version and sets activePublishedVersion atomically', async () => {
      mockVersionRepo.findOne.mockResolvedValue({
        appId: 'coffee_shop',
        version: '1.0.0',
        status: MiniAppStatus.APPROVED,
      });
      mockAppRepo.findOne.mockResolvedValue({
        id: 'coffee_shop',
        status: MiniAppStatus.APPROVED,
      });

      const app = await service.publishVersion('coffee_shop', '1.0.0', 'admin_001');

      expect(app.activePublishedVersion).toBe('1.0.0');
      expect(app.status).toBe(MiniAppStatus.PUBLISHED);
    });

    it('rejects publishing if version is not approved', async () => {
      mockVersionRepo.findOne.mockResolvedValue({
        appId: 'coffee_shop',
        version: '1.0.0',
        status: MiniAppStatus.SUBMITTED,
      });

      await expect(
        service.publishVersion('coffee_shop', '1.0.0', 'admin_001'),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('unpublishApp and suspendApp', () => {
    it('unpublishes app', async () => {
      mockAppRepo.findOne.mockResolvedValue({
        id: 'coffee_shop',
        status: MiniAppStatus.PUBLISHED,
        activePublishedVersion: '1.0.0',
      });

      const app = await service.unpublishApp('coffee_shop', 'admin_001', 'End of promotion');
      expect(app.status).toBe(MiniAppStatus.UNPUBLISHED);
      expect(mockAuditRepo.save).toHaveBeenCalled();
    });

    it('suspends app', async () => {
      mockAppRepo.findOne.mockResolvedValue({
        id: 'coffee_shop',
        status: MiniAppStatus.PUBLISHED,
        activePublishedVersion: '1.0.0',
      });

      const app = await service.suspendApp('coffee_shop', 'admin_001', 'Security audit');
      expect(app.status).toBe(MiniAppStatus.SUSPENDED);
      expect(mockAuditRepo.save).toHaveBeenCalled();
    });
  });
});
