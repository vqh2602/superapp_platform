import { IsString, IsNotEmpty, IsEnum, IsOptional } from 'class-validator';

export enum ReviewDecision {
  APPROVE = 'APPROVE',
  REJECT = 'REJECT',
}

export class ReviewActionDto {
  @IsString()
  @IsNotEmpty()
  version: string;

  @IsEnum(ReviewDecision)
  decision: ReviewDecision;

  @IsString()
  @IsOptional()
  notes?: string;
}
