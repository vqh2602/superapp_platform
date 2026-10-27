import { IsBoolean } from 'class-validator';

export class VisibilityDto {
  @IsBoolean()
  visible: boolean;
}
