import {
  Injectable,
  NotFoundException,
  ForbiddenException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { OrderEntity, OrderStatus } from '../../entities/order.entity';
import { CreateOrderDto, UpdateOrderStatusDto } from './order.dto';
import { randomBytes } from 'crypto';

@Injectable()
export class OrderService {
  constructor(
    @InjectRepository(OrderEntity)
    private readonly orderRepo: Repository<OrderEntity>,
  ) {}

  generateOrderId(): string {
    const time = Date.now();
    const rand = randomBytes(3).toString('hex').toUpperCase();
    return `ORD_${time}_${rand}`;
  }

  async createOrder(userId: string, dto: CreateOrderDto): Promise<OrderEntity> {
    const orderId = this.generateOrderId();
    const order = this.orderRepo.create({
      id: orderId,
      userId,
      appId: dto.appId,
      amount: dto.amount,
      currency: dto.currency || 'VND',
      description: dto.description,
      status: OrderStatus.PENDING,
      paymentMethod: null,
      completedAt: null,
    });

    return this.orderRepo.save(order);
  }

  async getOrder(orderId: string, userId?: string): Promise<OrderEntity> {
    const order = await this.orderRepo.findOneBy({ id: orderId });
    if (!order) {
      throw new NotFoundException(`Order "${orderId}" not found`);
    }

    if (userId && order.userId !== userId) {
      throw new ForbiddenException('You do not have permission to view this order');
    }

    return order;
  }

  async updateOrderStatus(
    orderId: string,
    dto: UpdateOrderStatusDto,
    userId?: string,
  ): Promise<OrderEntity> {
    const order = await this.getOrder(orderId, userId);

    order.status = dto.status;
    if (dto.paymentMethod !== undefined) {
      order.paymentMethod = dto.paymentMethod;
    }
    if (dto.status === OrderStatus.SUCCESS || dto.status === OrderStatus.FAILED || dto.status === OrderStatus.CANCELLED) {
      order.completedAt = new Date();
    }

    return this.orderRepo.save(order);
  }

  async listUserOrders(userId: string, appId?: string): Promise<OrderEntity[]> {
    const where: any = { userId };
    if (appId) {
      where.appId = appId;
    }

    return this.orderRepo.find({
      where,
      order: { createdAt: 'DESC' },
    });
  }
}
