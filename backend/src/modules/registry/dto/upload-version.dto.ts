import { IsString, IsOptional, IsObject, IsBoolean, Matches, MaxLength, ValidateIf } from 'class-validator';

export class UploadVersionDto {
  @IsString()
  @MaxLength(32)
  @Matches(/^\d+\.\d+\.\d+$/, { message: 'Version must have format X.Y.Z' })
  version: string;

  @IsOptional()
  @IsString()
  notes?: string;

  @ValidateIf((_, value) => value !== undefined)
  @IsObject()
  schema?: Record<string, any>;

  @ValidateIf((_, value) => value !== undefined)
  @IsString()
  @MaxLength(255)
  entryUrl?: string;

  @ValidateIf((_, value) => value !== undefined)
  @IsBoolean()
  isAsset?: boolean;
}
