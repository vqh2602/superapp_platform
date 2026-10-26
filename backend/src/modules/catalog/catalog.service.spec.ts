import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { ForbiddenException, NotFoundException } from '@nestjs/common';
import { CatalogService } from './catalog.service';
import { MiniAppEntity } from '../../entities/mini-app.entity';
import { MiniAppVersionEntity } from '../../entities/mini-app-version.entity';
import { MiniAppStatus, MiniAppRuntimeType } from '../../entities/enums';

describe('CatalogService Tests', () => {
  let service: CatalogService;
  let mockAppRepo: any;
  let mockVersionRepo: any;

  beforeEach(async () => {
    mockAppRepo = {
      findOne: jest.fn(),
      find: jest.fn(),
      createQueryBuilder: jest.fn(),
    };

    mockVersionRepo = {
      findOne: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        CatalogService,
        { provide: getRepositoryToken(MiniAppEntity), useValue: mockAppRepo },
        { provide: getRepositoryToken(MiniAppVersionEntity), useValue: mockVersionRepo },
      ],
    }).compile();

    service = module.get<CatalogService>(CatalogService);
  });

  describe('getPublishedApps', () => {
    it('only queries PUBLISHED apps with activePublishedVersion', async () => {
      const qbMock: any = {
        where: jest.fn().mockReturnThis(),
        andWhere: jest.fn().mockReturnThis(),
        orderBy: jest.fn().mockReturnThis(),
        skip: jest.fn().mockReturnThis(),
        take: jest.fn().mockReturnThis(),
        getManyAndCount: jest.fn().mockResolvedValue([
          [
            {
              id: 'coffee_shop',
              name: 'Coffee Shop',
              description: 'Great coffee',
              icon: 'coffee',
              category: 'Food & Beverage',
              runtimeType: MiniAppRuntimeType.SCHEMA,
              activePublishedVersion: '1.0.0',
              capabilities: [],
              updatedAt: new Date(),
            },
          ],
          1,
        ]),
      };

      mockAppRepo.createQueryBuilder.mockReturnValue(qbMock);

      const result = await service.getPublishedApps({ category: 'All' });

      expect(qbMock.where).toHaveBeenCalledWith('app.status = :status', {
        status: MiniAppStatus.PUBLISHED,
      });
      expect(result.items.length).toBe(1);
      expect(result.items[0].id).toBe('coffee_shop');
    });
  });

  describe('getPublishedAppById', () => {
    it('returns published manifest and active schema', async () => {
      mockAppRepo.findOne.mockResolvedValue({
        id: 'coffee_shop',
        name: 'Coffee Shop',
        status: MiniAppStatus.PUBLISHED,
        activePublishedVersion: '1.0.0',
        runtimeType: MiniAppRuntimeType.SCHEMA,
        capabilities: ['payment.createOrder'],
        updatedAt: new Date(),
      });

      mockVersionRepo.findOne.mockResolvedValue({
        appId: 'coffee_shop',
        version: '1.0.0',
        schema: { pages: [{ id: 'home' }] },
      });

      const res = await service.getPublishedAppById('coffee_shop');

      expect(res.id).toBe('coffee_shop');
      expect(res.version).toBe('1.0.0');
      expect(res.schema?.pages).toBeDefined();
    });

    it('blocks launch if app is SUSPENDED (throws ForbiddenException)', async () => {
      mockAppRepo.findOne.mockResolvedValue({
        id: 'bad_app',
        status: MiniAppStatus.SUSPENDED,
      });

      await expect(service.getPublishedAppById('bad_app')).rejects.toThrow(
        ForbiddenException,
      );
    });

    it('blocks launch if app is not published (throws ForbiddenException)', async () => {
      mockAppRepo.findOne.mockResolvedValue({
        id: 'draft_app',
        status: MiniAppStatus.DRAFT,
      });

      await expect(service.getPublishedAppById('draft_app')).rejects.toThrow(
        ForbiddenException,
      );
    });
  });
});
