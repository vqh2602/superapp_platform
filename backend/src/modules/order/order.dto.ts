import {
  IsEnum,
  IsNumber,
  IsOptional,
  IsPositive,
  IsString,
  MaxLength,
} from 'class-validator';
import { OrderStatus } from '../../entities/order.entity';

export class CreateOrderDto {
  @IsNumber()
  @IsPositive()
  amount: number;

  @IsString()
  @MaxLength(255)
  description: string;

  @IsString()
  @MaxLength(100)
  appId: string;

  @IsOptional()
  @IsString()
  @MaxLength(10)
  currency?: string;
}

export class UpdateOrderStatusDto {
  @IsEnum(OrderStatus)
  status: OrderStatus;

  @IsOptional()
  @IsString()
  @MaxLength(64)
  paymentMethod?: string;
}
