import { IsString, IsNotEmpty } from 'class-validator';

export class PublishVersionDto {
  @IsString()
  @IsNotEmpty()
  version: string;
}
