import React, { useState, useEffect } from 'react';
import {
  MiniAppEntity,
  MiniAppVersionEntity,
  ReviewAuditEntity,
  MiniAppStatus,
} from '../types';
import { MobileSimulator } from '../components/MobileSimulator';
import {
  ShieldCheck,
  CheckCircle2,
  XCircle,
  UploadCloud,
  EyeOff,
  RotateCcw,
  AlertTriangle,
  Clock,
  History,
  FileCheck,
  Smartphone,
  RefreshCw,
} from 'lucide-react';

interface AdminPortalViewProps {
  onRefreshApps: () => Promise<void>;
  apps: MiniAppEntity[];
}

export const AdminPortalView: React.FC<AdminPortalViewProps> = ({
  onRefreshApps,
  apps,
}) => {
  const [selectedAppId, setSelectedAppId] = useState<string>(apps[0]?.id || '');
  const [audits, setAudits] = useState<ReviewAuditEntity[]>([]);
  const [loadingAction, setLoadingAction] = useState<string | null>(null);
  const [rejectReason, setRejectReason] = useState<string>('');
  const [showRejectModal, setShowRejectModal] = useState<boolean>(false);
  const [rollbackVersion, setRollbackVersion] = useState<string>('');
  const [actionSuccess, setActionSuccess] = useState<string | null>(null);

  const selectedApp = apps.find((a) => a.id === selectedAppId) || apps[0];

  // Fetch audits
  const fetchAudits = async () => {
    try {
      const res = await fetch('/api/v1/registry/apps/audits');
      if (res.ok) {
        const data = await res.json();
        setAudits(data);
      }
    } catch (err) {
      console.warn('Failed to fetch audits:', err);
    }
  };

  useEffect(() => {
    fetchAudits();
  }, []);

  const showNotification = (msg: string) => {
    setActionSuccess(msg);
    setTimeout(() => setActionSuccess(null), 3500);
  };

  // Find latest submitted version or latest version
  const latestSubmittedVer = selectedApp?.versions?.find(
    (v) => v.status === 'SUBMITTED'
  );
  const latestApprovedVer = selectedApp?.versions?.find(
    (v) => v.status === 'APPROVED'
  );
  const activeVer = selectedApp?.versions?.find(
    (v) => v.version === selectedApp.activePublishedVersion
  );

  const targetVersionForReview = latestSubmittedVer || selectedApp?.versions?.[0];

  const handleApprove = async () => {
    if (!selectedApp || !targetVersionForReview) return;
    try {
      setLoadingAction('approve');
      const res = await fetch(`/api/v1/registry/apps/${selectedApp.id}/review`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-user-id': 'admin_001',
        },
        body: JSON.stringify({
          version: targetVersionForReview.version,
          decision: 'APPROVE',
          notes: 'Phê duyệt hợp lệ theo chính sách Super App Platform',
        }),
      });

      if (!res.ok) {
        const err = await res.json();
        throw new Error(err.message || 'Lỗi khi phê duyệt');
      }

      await onRefreshApps();
      await fetchAudits();
      showNotification(`✅ Đã phê duyệt phiên bản ${targetVersionForReview.version}!`);
    } catch (err: any) {
      alert(`Lỗi phê duyệt: ${err.message}`);
    } finally {
      setLoadingAction(null);
    }
  };

  const handleReject = async () => {
    if (!selectedApp || !targetVersionForReview) return;
    try {
      setLoadingAction('reject');
      const res = await fetch(`/api/v1/registry/apps/${selectedApp.id}/review`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-user-id': 'admin_001',
        },
        body: JSON.stringify({
          version: targetVersionForReview.version,
          decision: 'REJECT',
          notes: rejectReason || 'Không đáp ứng tiêu chuẩn giao diện',
        }),
      });

      if (!res.ok) {
        const err = await res.json();
        throw new Error(err.message || 'Lỗi khi từ chối');
      }

      setShowRejectModal(false);
      setRejectReason('');
      await onRefreshApps();
      await fetchAudits();
      showNotification(`❌ Đã từ chối phiên bản ${targetVersionForReview.version}`);
    } catch (err: any) {
      alert(`Lỗi từ chối: ${err.message}`);
    } finally {
      setLoadingAction(null);
    }
  };

  const handlePublish = async (versionStr: string) => {
    if (!selectedApp) return;
    try {
      setLoadingAction('publish');
      const res = await fetch(`/api/v1/registry/apps/${selectedApp.id}/publish`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-user-id': 'admin_001',
        },
        body: JSON.stringify({ version: versionStr }),
      });

      if (!res.ok) {
        const err = await res.json();
        throw new Error(err.message || 'Lỗi khi xuất bản');
      }

      await onRefreshApps();
      await fetchAudits();
      showNotification(
        `🚀 Đã XUẤT BẢN thành công phiên bản ${versionStr}! Mini App tự động hiện lên Flutter Super App.`
      );
    } catch (err: any) {
      alert(`Lỗi xuất bản: ${err.message}`);
    } finally {
      setLoadingAction(null);
    }
  };

  const handleUnpublish = async () => {
    if (!selectedApp) return;
    if (!confirm(`Bạn chắc chắn muốn hạ (Unpublish) Mini App "${selectedApp.name}"?`)) return;

    try {
      setLoadingAction('unpublish');
      const res = await fetch(`/api/v1/registry/apps/${selectedApp.id}/unpublish`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-user-id': 'admin_001',
        },
        body: JSON.stringify({ reason: 'Hạ app theo yêu cầu kiểm duyệt' }),
      });

      if (!res.ok) {
        const err = await res.json();
        throw new Error(err.message || 'Lỗi khi hạ app');
      }

      await onRefreshApps();
      await fetchAudits();
      showNotification(`🔒 Đã hạ (Unpublish) Mini App thành công!`);
    } catch (err: any) {
      alert(`Lỗi unpublish: ${err.message}`);
    } finally {
      setLoadingAction(null);
    }
  };

  const handleRollback = async () => {
    if (!selectedApp || !rollbackVersion) return;
    try {
      setLoadingAction('rollback');
      const res = await fetch(`/api/v1/registry/apps/${selectedApp.id}/rollback`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-user-id': 'admin_001',
        },
        body: JSON.stringify({
          version: rollbackVersion,
          reason: `Admin thực hiện rollback về phiên bản ${rollbackVersion}`,
        }),
      });

      if (!res.ok) {
        const err = await res.json();
        throw new Error(err.message || 'Lỗi rollback');
      }

      await onRefreshApps();
      await fetchAudits();
      showNotification(`⏪ Đã Rollback Mini App về phiên bản ${rollbackVersion}!`);
    } catch (err: any) {
      alert(`Lỗi rollback: ${err.message}`);
    } finally {
      setLoadingAction(null);
    }
  };

  const handleSuspend = async () => {
    if (!selectedApp) return;
    const reason = prompt('Nhập lý do đình chỉ (Suspend) khẩn cấp:');
    if (!reason) return;

    try {
      setLoadingAction('suspend');
      const res = await fetch(`/api/v1/registry/apps/${selectedApp.id}/suspend`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-user-id': 'admin_001',
        },
        body: JSON.stringify({ reason }),
      });

      if (!res.ok) {
        const err = await res.json();
        throw new Error(err.message || 'Lỗi đình chỉ');
      }

      await onRefreshApps();
      await fetchAudits();
      showNotification(`⛔ Đã ĐÌNH CHỈ (Suspend) Mini App khẩn cấp!`);
    } catch (err: any) {
      alert(`Lỗi suspend: ${err.message}`);
    } finally {
      setLoadingAction(null);
    }
  };

  // Preview schema for admin: use the submitted version snapshot!
  const previewSchema = targetVersionForReview?.schema || selectedApp?.draftSchema;

  return (
    <div className="flex-1 flex flex-col h-full overflow-hidden bg-slate-950">
      {/* Top Banner */}
      <div className="h-14 border-b border-slate-800 bg-slate-900/90 px-6 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="w-8 h-8 rounded-lg bg-indigo-500/10 border border-indigo-500/30 flex items-center justify-center text-indigo-400 font-bold">
            <ShieldCheck className="w-5 h-5" />
          </div>
          <div>
            <h2 className="text-sm font-bold text-slate-100">Super App Admin Moderation & Publishing</h2>
            <p className="text-[11px] text-slate-400">
              Kiểm duyệt snapshot đóng băng, phê duyệt, xuất bản động & kiểm toán an toàn
            </p>
          </div>
        </div>

        <button
          onClick={async () => {
            await onRefreshApps();
            await fetchAudits();
          }}
          className="flex items-center gap-1.5 px-3 py-1.5 bg-slate-800 hover:bg-slate-700 text-slate-300 rounded-xl text-xs font-semibold border border-slate-700 transition-all"
        >
          <RefreshCw className="w-3.5 h-3.5" />
          <span>Làm Mới</span>
        </button>
      </div>

      {actionSuccess && (
        <div className="bg-emerald-500/10 border-b border-emerald-500/30 px-6 py-2.5 text-xs text-emerald-400 flex items-center gap-2 font-medium">
          <CheckCircle2 className="w-4 h-4 flex-shrink-0" />
          <span>{actionSuccess}</span>
        </div>
      )}

      {/* Main Layout */}
      <div className="flex-1 flex overflow-hidden">
        {/* Left Column: Apps List */}
        <div className="w-80 border-r border-slate-800 bg-slate-900/40 flex flex-col overflow-y-auto p-4 gap-4">
          <div className="flex items-center justify-between">
            <h3 className="text-xs font-bold text-slate-300 uppercase tracking-wider">
              Danh Sách Mini Apps ({apps.length})
            </h3>
          </div>

          <div className="space-y-2">
            {apps.map((app) => (
              <div
                key={app.id}
                onClick={() => setSelectedAppId(app.id)}
                className={`p-3 rounded-2xl border text-xs cursor-pointer transition-all ${
                  app.id === selectedApp?.id
                    ? 'bg-indigo-500/10 border-indigo-500/50 shadow-md'
                    : 'bg-slate-900/60 border-slate-800/80 hover:bg-slate-900'
                }`}
              >
                <div className="flex items-start justify-between gap-2 mb-1.5">
                  <h4 className="font-bold text-slate-100 truncate">{app.name}</h4>
                  <span
                    className={`text-[9px] font-bold px-2 py-0.5 rounded-full uppercase flex-shrink-0 ${
                      app.status === 'PUBLISHED'
                        ? 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/30'
                        : app.status === 'SUBMITTED'
                        ? 'bg-blue-500/10 text-blue-400 border border-blue-500/30 animate-pulse'
                        : app.status === 'APPROVED'
                        ? 'bg-purple-500/10 text-purple-400 border border-purple-500/30'
                        : app.status === 'SUSPENDED'
                        ? 'bg-rose-500/10 text-rose-400 border border-rose-500/30'
                        : 'bg-slate-800 text-slate-400 border border-slate-700'
                    }`}
                  >
                    {app.status}
                  </span>
                </div>
                <div className="flex items-center justify-between text-[11px] text-slate-400">
                  <span className="font-mono text-[10px] text-slate-500">{app.id}</span>
                  <span className="text-[10px] bg-slate-800 px-1.5 py-0.5 rounded text-amber-400">
                    {app.runtimeType}
                  </span>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Center Column: App Review Details & Version History */}
        {selectedApp ? (
          <div className="flex-1 flex overflow-hidden">
            <div className="flex-1 p-6 overflow-y-auto space-y-6">
              {/* App Overview Card */}
              <div className="bg-slate-900/80 border border-slate-800 rounded-3xl p-5 space-y-4">
                <div className="flex items-start justify-between">
                  <div>
                    <h3 className="text-lg font-bold text-slate-100">{selectedApp.name}</h3>
                    <p className="text-xs text-slate-400 mt-0.5">{selectedApp.description}</p>
                  </div>
                  <div className="text-right">
                    <span className="text-[11px] text-slate-400 block">Tenant ID</span>
                    <span className="font-mono text-xs text-amber-400">{selectedApp.tenantId}</span>
                  </div>
                </div>

                <div className="grid grid-cols-4 gap-3 text-xs pt-3 border-t border-slate-800/80">
                  <div className="p-2.5 bg-slate-950 rounded-xl border border-slate-800">
                    <span className="text-[10px] text-slate-500 block">Runtime</span>
                    <span className="font-bold text-slate-200 capitalize">{selectedApp.runtimeType} Engine</span>
                  </div>
                  <div className="p-2.5 bg-slate-950 rounded-xl border border-slate-800">
                    <span className="text-[10px] text-slate-500 block">Active Published Version</span>
                    <span className="font-mono font-bold text-emerald-400">
                      {selectedApp.activePublishedVersion || 'Chưa publish'}
                    </span>
                  </div>
                  <div className="p-2.5 bg-slate-950 rounded-xl border border-slate-800">
                    <span className="text-[10px] text-slate-500 block">Danh mục</span>
                    <span className="font-semibold text-slate-300">{selectedApp.category}</span>
                  </div>
                  <div className="p-2.5 bg-slate-950 rounded-xl border border-slate-800">
                    <span className="text-[10px] text-slate-500 block">Capabilities</span>
                    <span className="font-bold text-slate-300">
                      {selectedApp.capabilities?.length || 0} quyền
                    </span>
                  </div>
                </div>
              </div>

              {/* Review / Approval Action Card */}
              <div className="bg-slate-900/80 border border-slate-800 rounded-3xl p-5 space-y-4">
                <div className="flex items-center justify-between pb-3 border-b border-slate-800">
                  <div className="flex items-center gap-2">
                    <FileCheck className="w-5 h-5 text-indigo-400" />
                    <h4 className="text-sm font-bold text-slate-200">
                      Quyết Định Xét Duyệt Bản Gửi (Review Decision)
                    </h4>
                  </div>
                  {targetVersionForReview && (
                    <span className="font-mono text-xs px-2.5 py-1 rounded-lg bg-indigo-500/10 text-indigo-400 border border-indigo-500/30">
                      Version: {targetVersionForReview.version} ({targetVersionForReview.status})
                    </span>
                  )}
                </div>

                {targetVersionForReview ? (
                  <div className="space-y-4 text-xs">
                    <div className="p-3 bg-slate-950 rounded-2xl border border-slate-800 text-slate-300 space-y-1.5">
                      <div className="flex items-center justify-between text-[11px] text-slate-500">
                        <span>Ghi chú từ Developer:</span>
                        <span>{new Date(targetVersionForReview.submittedAt).toLocaleString('vi-VN')}</span>
                      </div>
                      <p className="text-slate-200 font-medium italic">
                        "{targetVersionForReview.reviewNotes || 'Không có ghi chú'}"
                      </p>
                    </div>

                    {/* Action Buttons based on status */}
                    <div className="flex flex-wrap items-center gap-3 pt-2">
                      {targetVersionForReview.status === 'SUBMITTED' && (
                        <>
                          <button
                            onClick={handleApprove}
                            disabled={loadingAction === 'approve'}
                            className="flex items-center gap-2 px-4 py-2 bg-emerald-600 hover:bg-emerald-500 text-white rounded-xl font-bold shadow-lg shadow-emerald-950/40 transition-all active:scale-98"
                          >
                            <CheckCircle2 className="w-4 h-4" />
                            <span>Phê Duyệt (Approve)</span>
                          </button>

                          <button
                            onClick={() => setShowRejectModal(true)}
                            className="flex items-center gap-2 px-4 py-2 bg-rose-600 hover:bg-rose-500 text-white rounded-xl font-bold shadow-lg shadow-rose-950/40 transition-all active:scale-98"
                          >
                            <XCircle className="w-4 h-4" />
                            <span>Từ Chối (Reject)</span>
                          </button>
                        </>
                      )}

                      {(targetVersionForReview.status === 'APPROVED' ||
                        (selectedApp.status === 'APPROVED' && latestApprovedVer)) && (
                        <button
                          onClick={() =>
                            handlePublish(
                              targetVersionForReview.status === 'APPROVED'
                                ? targetVersionForReview.version
                                : latestApprovedVer!.version
                            )
                          }
                          disabled={loadingAction === 'publish'}
                          className="flex items-center gap-2 px-5 py-2.5 bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-500 hover:to-indigo-500 text-white rounded-xl font-bold shadow-lg shadow-blue-950/50 transition-all active:scale-98"
                        >
                          <UploadCloud className="w-4 h-4" />
                          <span>Xuất Bản Lên Super App (Publish)</span>
                        </button>
                      )}

                      {selectedApp.status === 'PUBLISHED' && (
                        <button
                          onClick={handleUnpublish}
                          disabled={loadingAction === 'unpublish'}
                          className="flex items-center gap-2 px-4 py-2 bg-amber-600/20 hover:bg-amber-600 text-amber-400 hover:text-white border border-amber-500/40 rounded-xl font-semibold transition-all"
                        >
                          <EyeOff className="w-4 h-4" />
                          <span>Hạ Mini App (Unpublish)</span>
                        </button>
                      )}

                      <button
                        onClick={handleSuspend}
                        className="flex items-center gap-2 px-3 py-2 bg-rose-950/40 hover:bg-rose-900/60 text-rose-400 border border-rose-500/40 rounded-xl font-semibold transition-all ml-auto"
                      >
                        <AlertTriangle className="w-4 h-4" />
                        <span>Đình Chỉ Vi Phạm (Suspend)</span>
                      </button>
                    </div>
                  </div>
                ) : (
                  <div className="text-center py-6 text-slate-500 text-xs">
                    Chưa có phiên bản nào được gửi xét duyệt
                  </div>
                )}
              </div>

              {/* Version History & Rollback Card */}
              <div className="bg-slate-900/80 border border-slate-800 rounded-3xl p-5 space-y-4">
                <div className="flex items-center justify-between pb-3 border-b border-slate-800">
                  <div className="flex items-center gap-2">
                    <History className="w-5 h-5 text-amber-400" />
                    <h4 className="text-sm font-bold text-slate-200">
                      Lịch Sử Phiên Bản & Rollback Khẩn Cấp
                    </h4>
                  </div>

                  {selectedApp.versions && selectedApp.versions.length > 1 && (
                    <div className="flex items-center gap-2 text-xs">
                      <select
                        value={rollbackVersion}
                        onChange={(e) => setRollbackVersion(e.target.value)}
                        className="bg-slate-950 border border-slate-700 rounded-lg px-2 py-1 text-slate-200"
                      >
                        <option value="">Chọn bản để Rollback...</option>
                        {selectedApp.versions
                          .filter(
                            (v) =>
                              (v.status === 'PUBLISHED' || v.status === 'APPROVED') &&
                              v.version !== selectedApp.activePublishedVersion
                          )
                          .map((v) => (
                            <option key={v.id} value={v.version}>
                              Version {v.version} ({v.status})
                            </option>
                          ))}
                      </select>
                      <button
                        onClick={handleRollback}
                        disabled={!rollbackVersion || loadingAction === 'rollback'}
                        className="px-3 py-1 bg-amber-500/20 text-amber-400 hover:bg-amber-500 hover:text-slate-950 rounded-lg font-bold transition-all disabled:opacity-40"
                      >
                        Rollback
                      </button>
                    </div>
                  )}
                </div>

                <div className="space-y-2 text-xs">
                  {selectedApp.versions?.map((ver) => (
                    <div
                      key={ver.id}
                      className="p-3 bg-slate-950 rounded-xl border border-slate-800 flex items-center justify-between"
                    >
                      <div className="flex items-center gap-3">
                        <span className="font-mono font-bold text-slate-100">v{ver.version}</span>
                        <span
                          className={`text-[9px] font-bold px-2 py-0.5 rounded-full uppercase ${
                            ver.status === 'PUBLISHED'
                              ? 'bg-emerald-500/10 text-emerald-400'
                              : ver.status === 'APPROVED'
                              ? 'bg-purple-500/10 text-purple-400'
                              : 'bg-slate-800 text-slate-400'
                          }`}
                        >
                          {ver.status}
                        </span>
                        <span className="text-slate-500 text-[11px]">
                          {new Date(ver.submittedAt).toLocaleDateString('vi-VN')}
                        </span>
                      </div>

                      {ver.status === 'APPROVED' && ver.version !== selectedApp.activePublishedVersion && (
                        <button
                          onClick={() => handlePublish(ver.version)}
                          className="px-2.5 py-1 bg-blue-500/20 text-blue-400 hover:bg-blue-500 hover:text-white rounded-lg font-semibold text-[11px] transition-all"
                        >
                          Publish v{ver.version}
                        </button>
                      )}
                    </div>
                  ))}
                </div>
              </div>

              {/* Audit Logs */}
              <div className="bg-slate-900/80 border border-slate-800 rounded-3xl p-5 space-y-3">
                <div className="flex items-center gap-2 pb-2 border-b border-slate-800">
                  <Clock className="w-4 h-4 text-slate-400" />
                  <h4 className="text-xs font-bold text-slate-300 uppercase tracking-wider">
                    Nhật Ký Kiểm Toán (Audit Logs)
                  </h4>
                </div>

                <div className="space-y-2 text-xs max-h-48 overflow-y-auto pr-1">
                  {audits
                    .filter((a) => a.appId === selectedApp.id)
                    .map((audit) => (
                      <div
                        key={audit.id}
                        className="p-2.5 bg-slate-950 rounded-xl border border-slate-800/80 flex items-center justify-between text-[11px]"
                      >
                        <div className="flex items-center gap-2">
                          <span
                            className={`font-mono font-bold px-1.5 py-0.5 rounded text-[10px] ${
                              audit.action === 'PUBLISH'
                                ? 'bg-emerald-500/20 text-emerald-400'
                                : audit.action === 'APPROVE'
                                ? 'bg-blue-500/20 text-blue-400'
                                : audit.action === 'REJECT'
                                ? 'bg-rose-500/20 text-rose-400'
                                : 'bg-slate-800 text-slate-300'
                            }`}
                          >
                            {audit.action}
                          </span>
                          <span className="text-slate-300 font-medium">v{audit.version}</span>
                          <span className="text-slate-500">by {audit.actorId}</span>
                          <span className="text-slate-400 italic">({audit.reason})</span>
                        </div>
                        <span className="text-slate-600 text-[10px]">
                          {new Date(audit.timestamp).toLocaleTimeString('vi-VN')}
                        </span>
                      </div>
                    ))}
                </div>
              </div>
            </div>

            {/* Right Column: Live Mobile Frame of the Snapshot Schema */}
            <div className="w-[360px] border-l border-slate-800 bg-slate-950 flex flex-col items-center justify-center p-4">
              <div className="mb-2 flex items-center gap-1.5 text-xs text-indigo-400 font-semibold">
                <Smartphone className="w-4 h-4" />
                <span>Xem Trước Snapshot Phiên Bản</span>
              </div>

              {previewSchema ? (
                <MobileSimulator schema={previewSchema} appName={selectedApp.name} />
              ) : (
                <div className="text-center text-xs text-slate-500">
                  Không tìm thấy schema để xem trước
                </div>
              )}
            </div>
          </div>
        ) : (
          <div className="flex-1 flex items-center justify-center text-slate-500 text-xs">
            Chọn một Mini App để kiểm duyệt
          </div>
        )}
      </div>

      {/* Reject Modal */}
      {showRejectModal && (
        <div className="fixed inset-0 bg-slate-950/80 backdrop-blur-sm flex items-center justify-center p-4 z-50">
          <div className="bg-slate-900 border border-slate-700 rounded-2xl w-full max-w-md p-6 shadow-2xl space-y-4 text-xs">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-xl bg-rose-500/10 text-rose-400 flex items-center justify-center">
                <XCircle className="w-5 h-5" />
              </div>
              <div>
                <h3 className="text-base font-bold text-slate-100">Từ Chối Phê Duyệt</h3>
                <p className="text-slate-400 text-[11px]">Thông báo lý do từ chối để Developer khắc phục</p>
              </div>
            </div>

            <div>
              <label className="text-slate-300 block mb-1 font-semibold">Lý do từ chối</label>
              <textarea
                rows={3}
                value={rejectReason}
                onChange={(e) => setRejectReason(e.target.value)}
                placeholder="Ví dụ: Hình ảnh chưa đúng kích thước, thiếu nút back về home..."
                className="w-full bg-slate-950 border border-slate-700 rounded-lg p-2.5 text-slate-100 outline-none resize-none focus:border-rose-400"
              />
            </div>

            <div className="flex items-center justify-end gap-2.5 pt-2">
              <button
                onClick={() => setShowRejectModal(false)}
                className="px-4 py-2 rounded-xl bg-slate-800 text-slate-300 font-semibold"
              >
                Hủy
              </button>
              <button
                onClick={handleReject}
                className="px-5 py-2 rounded-xl bg-rose-600 text-white font-bold hover:bg-rose-500"
              >
                Xác Nhận Từ Chối
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
