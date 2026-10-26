import { Controller, Get, Param, Query } from '@nestjs/common';
import { CatalogService, CatalogQueryDto } from './catalog.service';

@Controller('api/v1/catalog')
export class CatalogController {
  constructor(private readonly catalogService: CatalogService) {}

  @Get('apps')
  async getPublishedApps(@Query() query: CatalogQueryDto) {
    return this.catalogService.getPublishedApps(query);
  }

  @Get('apps/:id')
  async getPublishedAppById(@Param('id') id: string) {
    return this.catalogService.getPublishedAppById(id);
  }

  @Get('categories')
  async getCategories() {
    return this.catalogService.getCategories();
  }
}
