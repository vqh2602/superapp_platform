import { Transform } from 'class-transformer';
import { ArrayMaxSize, ArrayUnique, Equals, IsArray, IsBoolean, IsEmail, IsString, IsUrl, Matches, MaxLength, MinLength, ValidateIf } from 'class-validator';
import { APP_ID_PATTERN, CAPABILITY_PATTERN } from '../registry/packages/package-manifest';

export class LoginDto {
  @Transform(({ value }) => typeof value === 'string' ? value.trim().toLowerCase() : value)
  @IsEmail() @MaxLength(254) email: string;
  @IsString() @MinLength(8) @MaxLength(128) password: string;
}
export class RegisterDto extends LoginDto {
  @Transform(({ value }) => typeof value === 'string' ? value.trim() : value)
  @IsString() @Matches(/\S/) @MaxLength(128) displayName: string;
}
export class RefreshTokenDto {
  @IsString() @Matches(/^refresh_[a-zA-Z0-9_-]{43}$/) refreshToken: string;
}
export class UpdateProfileDto {
  @ValidateIf((_, value) => value !== undefined)
  @Transform(({ value }) => typeof value === 'string' ? value.trim() : value)
  @IsString() @Matches(/\S/) @MaxLength(128) displayName?: string;

  @ValidateIf((_, value) => value !== undefined && value !== '')
  @IsUrl({ protocols: ['http', 'https'], require_protocol: true, require_tld: false })
  @MaxLength(512) avatarUrl?: string;
}
export class PermissionDecisionDto {
  @IsArray() @ArrayMaxSize(50) @ArrayUnique()
  @IsString({ each: true }) @Matches(CAPABILITY_PATTERN, { each: true }) @MaxLength(128, { each: true })
  permissions: string[];
  @IsBoolean() granted: boolean;
}
export class AuthCodeRequestDto {
  @IsString() @Matches(APP_ID_PATTERN) appId: string;
  @IsString() @Matches(/^[a-zA-Z0-9_-]{43}$/) codeChallenge: string;
  @Equals('S256') codeChallengeMethod: 'S256';
  @ValidateIf((_, value) => value !== undefined)
  @IsArray() @ArrayMaxSize(50) @ArrayUnique()
  @IsString({ each: true }) @Matches(CAPABILITY_PATTERN, { each: true }) @MaxLength(128, { each: true })
  scopes?: string[];
}
export class ExchangeCodeDto {
  @IsString() @Matches(APP_ID_PATTERN) appId: string;
  @IsString() @Matches(/^code_[a-zA-Z0-9_-]{43}$/) authCode: string;
  @IsString() @Matches(/^[a-zA-Z0-9._~-]{43,128}$/) codeVerifier: string;
}
