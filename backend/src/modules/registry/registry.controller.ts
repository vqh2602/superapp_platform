import {
  Controller,
  Get,
  Post,
  Put,
  Param,
  Body,
  Headers,
  Query,
} from '@nestjs/common';
import { RegistryService } from './registry.service';
import { CreateMiniAppDto } from './dto/create-app.dto';
import { UpdateDraftDto } from './dto/update-draft.dto';
import { SubmitReviewDto } from './dto/submit-review.dto';
import { ReviewActionDto } from './dto/review-action.dto';
import { PublishVersionDto } from './dto/publish-version.dto';

@Controller('api/v1/registry/apps')
export class RegistryController {
  constructor(private readonly registryService: RegistryService) {}

  @Post()
  async createDraft(
    @Headers('x-tenant-id') tenantId: string = 'tenant_001',
    @Body() dto: CreateMiniAppDto,
  ) {
    return this.registryService.createDraft(tenantId, dto);
  }

  @Get()
  async getTenantApps(
    @Headers('x-tenant-id') tenantId: string = 'tenant_001',
    @Query('all') all?: string,
  ) {
    if (all === 'true' || tenantId === 'all') {
      return this.registryService.getAllApps();
    }
    return this.registryService.getTenantApps(tenantId);
  }

  @Get('audits')
  async getAudits(@Query('appId') appId?: string) {
    return this.registryService.getAudits(appId);
  }

  @Get(':id')
  async getAppDetails(
    @Param('id') appId: string,
    @Headers('x-tenant-id') tenantId?: string,
  ) {
    return this.registryService.getAppDetails(appId, tenantId);
  }

  @Put(':id')
  async updateDraft(
    @Param('id') appId: string,
    @Headers('x-tenant-id') tenantId: string = 'tenant_001',
    @Body() dto: UpdateDraftDto,
  ) {
    return this.registryService.updateDraft(appId, tenantId, dto);
  }

  @Post(':id/submit')
  async submitForReview(
    @Param('id') appId: string,
    @Headers('x-tenant-id') tenantId: string = 'tenant_001',
    @Headers('x-user-id') actorId: string = 'customer_001',
    @Body() dto: SubmitReviewDto,
  ) {
    return this.registryService.submitForReview(appId, tenantId, actorId, dto);
  }

  @Post(':id/review')
  async reviewVersion(
    @Param('id') appId: string,
    @Headers('x-user-id') actorId: string = 'admin_001',
    @Body() dto: ReviewActionDto,
  ) {
    return this.registryService.reviewVersion(appId, actorId, dto);
  }

  @Post(':id/publish')
  async publishVersion(
    @Param('id') appId: string,
    @Headers('x-user-id') actorId: string = 'admin_001',
    @Body() dto: PublishVersionDto,
  ) {
    return this.registryService.publishVersion(appId, dto.version, actorId);
  }

  @Post(':id/unpublish')
  async unpublishApp(
    @Param('id') appId: string,
    @Headers('x-user-id') actorId: string = 'admin_001',
    @Body('reason') reason?: string,
  ) {
    return this.registryService.unpublishApp(appId, actorId, reason);
  }

  @Post(':id/rollback')
  async rollbackApp(
    @Param('id') appId: string,
    @Headers('x-user-id') actorId: string = 'admin_001',
    @Body('version') targetVersion: string,
    @Body('reason') reason?: string,
  ) {
    return this.registryService.rollbackApp(appId, targetVersion, actorId, reason);
  }

  @Post(':id/suspend')
  async suspendApp(
    @Param('id') appId: string,
    @Headers('x-user-id') actorId: string = 'admin_001',
    @Body('reason') reason?: string,
  ) {
    return this.registryService.suspendApp(appId, actorId, reason);
  }
}
