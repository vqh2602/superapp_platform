import { IsString, IsNotEmpty, Matches, IsOptional } from 'class-validator';

export class SubmitReviewDto {
  @IsString()
  @IsNotEmpty()
  @Matches(/^\d+\.\d+\.\d+$/, {
    message: 'Version must follow semver format X.Y.Z (e.g. 1.0.0)',
  })
  version: string;

  @IsString()
  @IsOptional()
  notes?: string;
}
