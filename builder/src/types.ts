export type MiniAppStatus =
  | 'DRAFT'
  | 'SUBMITTED'
  | 'IN_REVIEW'
  | 'APPROVED'
  | 'REJECTED'
  | 'PUBLISHED'
  | 'UNPUBLISHED'
  | 'SUSPENDED';

export type MiniAppRuntimeType = 'web' | 'schema';

export interface ComponentAction {
  type: 'navigate' | 'native_action';
  pageId?: string;
  action?: string;
  params?: Record<string, any>;
}

export interface ComponentDefinition {
  id: string;
  type: 'text' | 'image' | 'button' | 'container' | 'product_card' | 'product_list' | 'input';
  props: Record<string, any>;
  events?: {
    onClick?: ComponentAction;
  };
  children?: ComponentDefinition[];
}

export interface PageDefinition {
  id: string;
  title: string;
  components: ComponentDefinition[];
}

export interface MiniAppSchema {
  schemaVersion: number;
  theme?: {
    primaryColor?: string;
    backgroundColor?: string;
  };
  pages: PageDefinition[];
}

export interface MiniAppVersionEntity {
  id: string;
  appId: string;
  version: string;
  schemaVersion: number;
  status: MiniAppStatus;
  schema?: MiniAppSchema | null;
  entryUrl?: string | null;
  capabilities: string[];
  reviewNotes?: string;
  rejectionReason?: string;
  submittedAt: string;
  reviewedAt?: string;
  publishedAt?: string;
  createdAt: string;
}

export interface MiniAppEntity {
  id: string;
  name: string;
  description: string;
  icon: string;
  category: string;
  tenantId: string;
  runtimeType: MiniAppRuntimeType;
  status: MiniAppStatus;
  activePublishedVersion?: string | null;
  entryUrl?: string | null;
  isAsset: boolean;
  capabilities: string[];
  draftSchema?: MiniAppSchema | null;
  versions?: MiniAppVersionEntity[];
  createdAt: string;
  updatedAt: string;
}

export interface ReviewAuditEntity {
  id: string;
  appId: string;
  version: string;
  action: 'SUBMIT' | 'APPROVE' | 'REJECT' | 'PUBLISH' | 'UNPUBLISH' | 'ROLLBACK' | 'SUSPEND';
  actorId: string;
  actorRole: string;
  reason?: string;
  timestamp: string;
}
