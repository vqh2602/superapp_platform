import { ArrayUnique, Equals, IsArray, IsEmail, IsEnum, IsInt, IsNotEmpty, IsString, IsUrl, Matches, MaxLength, ValidateIf } from 'class-validator';
import { MiniAppRuntimeType } from '../../../entities/enums';

export const APP_ID_PATTERN = /^[a-z0-9][a-z0-9_-]{2,63}$/;
export const VERSION_PATTERN = /^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/;
export const CAPABILITY_PATTERN = /^[a-zA-Z][a-zA-Z0-9_.]*$/;

/** Super App package format v1. app.json is always at the ZIP root. */
export class PackageManifest {
  @IsInt()
  @Equals(1)
  manifestVersion: number;

  @IsString()
  @Matches(APP_ID_PATTERN)
  appId: string;

  @IsString()
  @Matches(/\S/)
  @MaxLength(128)
  name: string;

  @IsString()
  @MaxLength(4000)
  description: string;

  @IsString()
  @Matches(/\S/)
  @MaxLength(64)
  category: string;

  @IsString()
  @MaxLength(32)
  @Matches(VERSION_PATTERN)
  version: string;

  @IsEnum(MiniAppRuntimeType)
  runtimeType: MiniAppRuntimeType;

  @IsString()
  @IsNotEmpty()
  @MaxLength(200)
  entry: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(200)
  icon: string;

  @IsArray()
  @IsString({ each: true })
  @Matches(CAPABILITY_PATTERN, { each: true })
  @ArrayUnique()
  permissions: string[];

  @ValidateIf((_, value) => value !== undefined)
  @IsString()
  @MaxLength(128)
  developerName?: string;

  @ValidateIf((_, value) => value !== undefined && value !== '')
  @IsEmail()
  @MaxLength(254)
  supportEmail?: string;

  @ValidateIf((_, value) => value !== undefined && value !== '')
  @IsUrl({ protocols: ['http', 'https'], require_protocol: true, require_tld: false })
  @MaxLength(512)
  website?: string;

  @ValidateIf((_, value) => value !== undefined)
  @Matches(/^#[a-fA-F0-9]{6}$/)
  themeColor?: string;
}
