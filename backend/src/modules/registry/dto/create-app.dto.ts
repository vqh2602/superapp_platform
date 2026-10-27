import { ArrayUnique, IsArray, IsEmail, IsEnum, IsString, IsUrl, Matches, MaxLength, ValidateIf } from 'class-validator';
import { MiniAppRuntimeType } from '../../../entities/enums';
import { APP_ID_PATTERN, CAPABILITY_PATTERN } from '../packages/package-manifest';

export class CreateMiniAppDto {
  @IsString()
  @Matches(APP_ID_PATTERN)
  id: string;

  @IsString()
  @Matches(/\S/)
  @MaxLength(128)
  name: string;

  @ValidateIf((_, value) => value !== undefined)
  @IsString()
  @MaxLength(4000)
  description?: string;

  @ValidateIf((_, value) => value !== undefined)
  @IsString()
  @MaxLength(512)
  @Matches(/^(?:[a-zA-Z][a-zA-Z0-9_-]*|https?:\/\/[^\s]+|\/api\/v1\/miniapps\/[^\s]+)$/)
  icon?: string;

  @ValidateIf((_, value) => value !== undefined)
  @IsString()
  @Matches(/\S/)
  @MaxLength(64)
  category?: string;

  @ValidateIf((_, value) => value !== undefined)
  @IsArray()
  @IsString({ each: true })
  @Matches(CAPABILITY_PATTERN, { each: true })
  @ArrayUnique()
  capabilities?: string[];

  @ValidateIf((_, value) => value !== undefined)
  @IsString()
  @MaxLength(128)
  developerName?: string;

  @ValidateIf((_, value) => value !== undefined)
  @IsString()
  @ValidateIf((_, value) => value !== undefined && value !== '')
  @IsEmail()
  @MaxLength(254)
  supportEmail?: string;

  @ValidateIf((_, value) => value !== undefined)
  @IsString()
  @ValidateIf((_, value) => value !== undefined && value !== '')
  @IsUrl({ protocols: ['http', 'https'], require_protocol: true, require_tld: false })
  @MaxLength(512)
  website?: string;

  @ValidateIf((_, value) => value !== undefined)
  @IsString()
  @Matches(/^#[a-fA-F0-9]{6}$/)
  themeColor?: string;

  @ValidateIf((_, value) => value !== undefined)
  @IsEnum(MiniAppRuntimeType)
  runtimeType?: MiniAppRuntimeType;

}
