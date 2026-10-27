import {
  Body,
  Controller,
  Get,
  HttpCode,
  Param,
  Patch,
  Post,
  Query,
  Req,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { AccessTokenGuard, AuthRequest } from '../auth/access-token.guard';
import { NoStoreInterceptor } from '../auth/no-store.interceptor';
import { CreateOrderDto, UpdateOrderStatusDto } from './order.dto';
import { OrderService } from './order.service';

@Controller('api/v1/orders')
@UseGuards(AccessTokenGuard)
@UseInterceptors(NoStoreInterceptor)
export class OrderController {
  constructor(private readonly orderService: OrderService) {}

  @Post()
  @HttpCode(201)
  async createOrder(@Req() req: AuthRequest, @Body() dto: CreateOrderDto) {
    const order = await this.orderService.createOrder(req.auth.user.id, dto);
    return {
      orderId: order.id,
      amount: Number(order.amount),
      currency: order.currency,
      description: order.description,
      appId: order.appId,
      userId: order.userId,
      status: order.status,
      createdAt: order.createdAt.toISOString(),
    };
  }

  @Get(':orderId')
  async getOrder(@Req() req: AuthRequest, @Param('orderId') orderId: string) {
    const order = await this.orderService.getOrder(orderId, req.auth.user.id);
    return {
      orderId: order.id,
      amount: Number(order.amount),
      currency: order.currency,
      description: order.description,
      appId: order.appId,
      userId: order.userId,
      status: order.status,
      paymentMethod: order.paymentMethod,
      createdAt: order.createdAt.toISOString(),
      completedAt: order.completedAt ? order.completedAt.toISOString() : null,
    };
  }

  @Patch(':orderId/status')
  async updateStatus(
    @Req() req: AuthRequest,
    @Param('orderId') orderId: string,
    @Body() dto: UpdateOrderStatusDto,
  ) {
    const order = await this.orderService.updateOrderStatus(
      orderId,
      dto,
      req.auth.user.id,
    );
    return {
      orderId: order.id,
      amount: Number(order.amount),
      currency: order.currency,
      description: order.description,
      appId: order.appId,
      userId: order.userId,
      status: order.status,
      paymentMethod: order.paymentMethod,
      createdAt: order.createdAt.toISOString(),
      completedAt: order.completedAt ? order.completedAt.toISOString() : null,
    };
  }

  @Get()
  async listOrders(
    @Req() req: AuthRequest,
    @Query('appId') appId?: string,
  ) {
    const orders = await this.orderService.listUserOrders(
      req.auth.user.id,
      appId,
    );
    return orders.map((order) => ({
      orderId: order.id,
      amount: Number(order.amount),
      currency: order.currency,
      description: order.description,
      appId: order.appId,
      userId: order.userId,
      status: order.status,
      paymentMethod: order.paymentMethod,
      createdAt: order.createdAt.toISOString(),
      completedAt: order.completedAt ? order.completedAt.toISOString() : null,
    }));
  }
}
