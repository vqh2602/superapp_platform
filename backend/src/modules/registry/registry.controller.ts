import { BadRequestException, Controller, Get, Post, Put, Patch, Param, Body, UploadedFile, UseInterceptors } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { memoryStorage } from 'multer';
import { RegistryService } from './registry.service';
import { CreateMiniAppDto } from './dto/create-app.dto';
import { UpdateMiniAppDto } from './dto/update-app.dto';
import { VisibilityDto } from './dto/visibility.dto';
import { MAX_PACKAGE_BYTES } from './packages/package.service';

const packageUpload = () => FileInterceptor('file', {
  storage: memoryStorage(), limits: { fileSize: MAX_PACKAGE_BYTES, files: 1, fields: 1, fieldSize: 8000 },
});

@Controller('api/v1/registry/apps')
export class RegistryController {
  constructor(private readonly registryService: RegistryService) {}

  @Post()
  createApp(@Body() dto: CreateMiniAppDto) { return this.registryService.createApp(dto); }

  @Get()
  getApps() { return this.registryService.getAllApps(); }

  @Get(':id')
  getAppDetails(@Param('id') id: string) { return this.registryService.getAppDetails(id); }

  @Put(':id')
  updateApp(@Param('id') id: string, @Body() dto: UpdateMiniAppDto) { return this.registryService.updateApp(id, dto); }

  @Patch(':id/visibility')
  setVisibility(@Param('id') id: string, @Body() dto: VisibilityDto) { return this.registryService.setVisibility(id, dto.visible); }

  @Post(':id/packages/inspect')
  @UseInterceptors(packageUpload())
  inspectPackage(@Param('id') id: string, @UploadedFile() file?: Express.Multer.File) {
    if (!file) throw new BadRequestException('Chọn file ZIP Mini App');
    return this.registryService.inspectPackage(id, file.buffer);
  }

  @Post(':id/versions')
  @UseInterceptors(packageUpload())
  uploadPackage(@Param('id') id: string, @UploadedFile() file: Express.Multer.File, @Body() body: { notes?: string }) {
    if (!file) throw new BadRequestException('Phiên bản mới phải là file ZIP có app.json; gửi multipart/form-data với trường file');
    if (Object.keys(body).some(key => key !== 'notes') || (body.notes !== undefined && typeof body.notes !== 'string')) throw new BadRequestException('Chỉ nhận file và ghi chú notes');
    return this.registryService.uploadPackage(id, file.buffer, body.notes);
  }
}
