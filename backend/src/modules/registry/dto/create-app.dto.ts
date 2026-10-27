import { IsString, IsNotEmpty, ValidateIf, Matches, IsEnum, IsArray, IsObject, IsBoolean, MaxLength, ArrayUnique } from 'class-validator';
import { MiniAppRuntimeType } from '../../../entities/enums';

export class CreateMiniAppDto {
  @IsString()
  @Matches(/^[a-z0-9_]{3,32}$/)
  id: string;

  @IsString()
  @Matches(/\S/)
  @MaxLength(128)
  name: string;

  @ValidateIf((_, value) => value !== undefined)
  @IsString()
  description?: string;

  @ValidateIf((_, value) => value !== undefined)
  @IsString()
  @MaxLength(64)
  icon?: string;

  @ValidateIf((_, value) => value !== undefined)
  @IsString()
  @MaxLength(64)
  category?: string;

  @ValidateIf((_, value) => value !== undefined)
  @IsEnum(MiniAppRuntimeType)
  runtimeType?: MiniAppRuntimeType;

  @ValidateIf((_, value) => value !== undefined)
  @IsArray()
  @IsString({ each: true })
  @IsNotEmpty({ each: true })
  @Matches(/^[a-zA-Z][a-zA-Z0-9_.]*$/, { each: true })
  @ArrayUnique()
  capabilities?: string[];

  @ValidateIf((_, value) => value !== undefined)
  @IsObject()
  draftSchema?: Record<string, any>;

  @ValidateIf((_, value) => value !== undefined)
  @IsString()
  @MaxLength(255)
  entryUrl?: string;

  @ValidateIf((_, value) => value !== undefined)
  @IsBoolean()
  isAsset?: boolean;
}
