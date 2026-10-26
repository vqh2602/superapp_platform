import { IsString, IsOptional, IsArray } from 'class-validator';

export class UpdateDraftDto {
  @IsString()
  @IsOptional()
  name?: string;

  @IsString()
  @IsOptional()
  description?: string;

  @IsString()
  @IsOptional()
  icon?: string;

  @IsString()
  @IsOptional()
  category?: string;

  @IsArray()
  @IsOptional()
  capabilities?: string[];

  @IsOptional()
  draftSchema?: Record<string, any>;
}
