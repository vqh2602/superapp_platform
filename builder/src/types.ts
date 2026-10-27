export type MiniAppStatus = 'DRAFT' | 'SUBMITTED' | 'IN_REVIEW' | 'APPROVED' | 'REJECTED' | 'PUBLISHED' | 'UNPUBLISHED' | 'SUSPENDED';
export type MiniAppRuntimeType = 'web' | 'schema';

export interface PackageManifest {
  manifestVersion: 1;
  appId: string;
  name: string;
  description: string;
  category: string;
  version: string;
  runtimeType: MiniAppRuntimeType;
  entry: string;
  icon: string;
  permissions: string[];
  developerName?: string;
  supportEmail?: string;
  website?: string;
  themeColor?: string;
}

export interface PackageInspection {
  manifest: PackageManifest;
  checksum: string;
  size: number;
  fileCount: number;
}

export interface MiniAppVersionEntity {
  id: string;
  version: string;
  manifest?: PackageManifest | null;
  checksum?: string | null;
  packageSize?: number | null;
  reviewNotes?: string;
  createdAt: string;
}

export interface MiniAppEntity {
  id: string;
  name: string;
  description: string;
  icon: string;
  category: string;
  runtimeType: MiniAppRuntimeType;
  status: MiniAppStatus;
  activePublishedVersion?: string | null;
  entryUrl?: string | null;
  isAsset: boolean;
  capabilities: string[];
  requestedPermissions: string[];
  developerName: string;
  supportEmail: string;
  website: string;
  themeColor: string;
  versions?: MiniAppVersionEntity[];
  createdAt: string;
  updatedAt: string;
}
