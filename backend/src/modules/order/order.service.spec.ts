import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { OrderEntity, OrderStatus } from '../../entities/order.entity';
import { OrderService } from './order.service';

describe('OrderService', () => {
  let service: OrderService;
  let mockOrderRepo: any;

  beforeEach(async () => {
    mockOrderRepo = {
      create: jest.fn((dto) => ({ ...dto })),
      save: jest.fn(async (order) => ({
        ...order,
        createdAt: order.createdAt || new Date(),
        updatedAt: new Date(),
      })),
      findOneBy: jest.fn(),
      find: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        OrderService,
        {
          provide: getRepositoryToken(OrderEntity),
          useValue: mockOrderRepo,
        },
      ],
    }).compile();

    service = module.get<OrderService>(OrderService);
  });

  it('creates an order with pending status', async () => {
    const order = await service.createOrder('user-123', {
      appId: 'shopee',
      amount: 150000,
      description: 'Giày thể thao',
      currency: 'VND',
    });

    expect(order.id).toMatch(/^ORD_\d+_[A-F0-9]{6}$/);
    expect(order.userId).toBe('user-123');
    expect(order.status).toBe(OrderStatus.PENDING);
    expect(mockOrderRepo.save).toHaveBeenCalled();
  });

  it('updates order status to SUCCESS with paymentMethod', async () => {
    const existing = {
      id: 'ORD_123',
      userId: 'user-123',
      appId: 'shopee',
      amount: 150000,
      currency: 'VND',
      description: 'Giày',
      status: OrderStatus.PENDING,
      paymentMethod: null,
      createdAt: new Date(),
      completedAt: null,
    };
    mockOrderRepo.findOneBy.mockResolvedValue(existing);

    const updated = await service.updateOrderStatus(
      'ORD_123',
      { status: OrderStatus.SUCCESS, paymentMethod: 'SUPERAPP_WALLET' },
      'user-123',
    );

    expect(updated.status).toBe(OrderStatus.SUCCESS);
    expect(updated.paymentMethod).toBe('SUPERAPP_WALLET');
    expect(updated.completedAt).toBeInstanceOf(Date);
  });
});
