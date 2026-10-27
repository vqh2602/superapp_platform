import { IsString, IsNotEmpty, ValidateIf, Matches, IsArray, IsObject, MaxLength, ArrayUnique } from 'class-validator';

export class UpdateDraftDto {
  @ValidateIf((_, value) => value !== undefined)
  @IsString()
  @Matches(/\S/)
  @MaxLength(128)
  name?: string;

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
  @IsArray()
  @IsString({ each: true })
  @IsNotEmpty({ each: true })
  @Matches(/^[a-zA-Z][a-zA-Z0-9_.]*$/, { each: true })
  @ArrayUnique()
  capabilities?: string[];

  @ValidateIf((_, value) => value !== undefined)
  @IsObject()
  draftSchema?: Record<string, any>;
}
