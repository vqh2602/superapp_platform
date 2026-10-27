import { Controller, Get, Post, Put, Patch, Param, Body } from '@nestjs/common';
import { RegistryService } from './registry.service';
import { CreateMiniAppDto } from './dto/create-app.dto';
import { UpdateDraftDto } from './dto/update-draft.dto';
import { UploadVersionDto } from './dto/upload-version.dto';
import { VisibilityDto } from './dto/visibility.dto';

@Controller('api/v1/registry/apps')
export class RegistryController {
  constructor(private readonly registryService: RegistryService) {}

  @Post()
  createApp(@Body() dto: CreateMiniAppDto) {
    return this.registryService.createApp(dto);
  }

  @Get()
  getApps() {
    return this.registryService.getAllApps();
  }

  @Get(':id')
  getAppDetails(@Param('id') id: string) {
    return this.registryService.getAppDetails(id);
  }

  @Put(':id')
  updateApp(@Param('id') id: string, @Body() dto: UpdateDraftDto) {
    return this.registryService.updateApp(id, dto);
  }

  @Patch(':id/visibility')
  setVisibility(@Param('id') id: string, @Body() dto: VisibilityDto) {
    return this.registryService.setVisibility(id, dto.visible);
  }

  @Post(':id/versions')
  uploadVersion(@Param('id') id: string, @Body() dto: UploadVersionDto) {
    return this.registryService.uploadVersion(id, dto);
  }
}
