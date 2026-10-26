import { IsString, IsNotEmpty, IsOptional, Matches, IsEnum, IsArray } from 'class-validator';
import { MiniAppRuntimeType } from '../../../entities/enums';

export class CreateMiniAppDto {
  @IsString()
  @IsNotEmpty()
  @Matches(/^[a-z0-9_]{3,32}$/, {
    message: 'App ID must be 3-32 lowercase alphanumeric characters or underscore (e.g. coffee_shop)',
  })
  id: string;

  @IsString()
  @IsNotEmpty()
  name: string;

  @IsString()
  @IsOptional()
  description?: string;

  @IsString()
  @IsOptional()
  icon?: string;

  @IsString()
  @IsOptional()
  category?: string;

  @IsEnum(MiniAppRuntimeType)
  @IsOptional()
  runtimeType?: MiniAppRuntimeType;

  @IsArray()
  @IsOptional()
  capabilities?: string[];

  @IsOptional()
  draftSchema?: Record<string, any>;
}
