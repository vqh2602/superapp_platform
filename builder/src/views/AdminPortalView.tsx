import React, { useEffect, useRef, useState } from 'react';
import { Box, Check, Eye, EyeOff, FileArchive, Plus, Search, Upload } from 'lucide-react';
import { MiniAppEntity, MiniAppRuntimeType, PackageInspection } from '../types';
import { buildApiUrl } from '../api';

interface Props { apps: MiniAppEntity[]; onRefreshApps: () => Promise<void>; }
const inputClass = 'mt-1 w-full bg-slate-950 border border-slate-700 rounded-lg px-3 py-2.5 text-sm text-slate-100 focus:border-indigo-400 outline-none';
const buttonClass = 'inline-flex items-center justify-center gap-2 px-4 py-2.5 rounded-lg bg-indigo-600 hover:bg-indigo-500 disabled:opacity-50 text-sm font-semibold';
const panelClass = 'bg-slate-900 border border-slate-800 rounded-2xl p-5 space-y-4';

async function request(path: string, method: string, body: unknown) {
  const form = body instanceof FormData;
  const url = buildApiUrl(`/api/v1/registry/apps${path}`);
  const response = await fetch(url, {
    method, ...(form ? {} : { headers: { 'Content-Type': 'application/json' } }),
    body: form ? body : JSON.stringify(body),
  });
  const data = await response.json();
  if (!response.ok) throw new Error(Array.isArray(data.message) ? data.message.join('\n') : data.message || 'Thao tác thất bại');
  return data;
}

function AppIcon({ icon, name, color }: { icon: string; name: string; color?: string }) {
  const [failed, setFailed] = useState(false);
  useEffect(() => setFailed(false), [icon]);
  const image = /^(https?:\/\/|\/api\/v1\/miniapps\/)/.test(icon);
  const resolvedIcon = icon.startsWith('/') ? buildApiUrl(icon) : icon;
  return <div style={{ backgroundColor: color || '#6366F1' }} className="w-12 h-12 rounded-xl overflow-hidden shrink-0 flex items-center justify-center font-bold text-xl">
    {image && !failed ? <img src={resolvedIcon} alt={`Icon ${name}`} onError={() => setFailed(true)} className="w-full h-full object-cover" /> : name.slice(0, 1).toUpperCase() || <Box />}
  </div>;
}

export const AdminPortalView: React.FC<Props> = ({ apps, onRefreshApps }) => {
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [creating, setCreating] = useState(false);
  const [search, setSearch] = useState('');
  const selected = apps.find(app => app.id === selectedId) || (!creating ? apps[0] : undefined);
  const filtered = apps.filter(app => `${app.name} ${app.id}`.toLowerCase().includes(search.toLowerCase()));
  return <main className="flex-1 overflow-auto p-4 md:p-6">
    <div className="max-w-7xl mx-auto space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-4"><div><h2 className="text-2xl font-bold">Quản lý Mini App</h2>
        <p className="text-sm text-slate-400 mt-1">{apps.length} ứng dụng · {apps.filter(app => app.status === 'PUBLISHED').length} đang hiển thị</p></div>
        <button className={buttonClass} onClick={() => { setCreating(true); setSelectedId(null); }}><Plus size={16} />Thêm Mini App</button></div>
      <div className="grid grid-cols-1 md:grid-cols-[260px_minmax(0,1fr)] xl:grid-cols-[320px_minmax(0,1fr)] gap-6 items-start">
        <aside className="space-y-3 max-h-80 overflow-auto md:sticky md:top-0 md:max-h-[calc(100vh-210px)]">
          <label className="relative block"><Search size={16} className="absolute left-3 top-4 text-slate-400" /><input aria-label="Tìm Mini App" placeholder="Tìm tên hoặc App ID" className={`${inputClass} pl-9`} value={search} onChange={event => setSearch(event.target.value)} /></label>
          {filtered.length === 0 && <p className="p-4 text-sm text-slate-400">Không có Mini App phù hợp.</p>}
          {filtered.map(app => <button key={app.id} onClick={() => { setSelectedId(app.id); setCreating(false); }} className={`w-full flex gap-3 text-left p-4 rounded-xl border ${selected?.id === app.id && !creating ? 'border-indigo-500 bg-indigo-500/10' : 'border-slate-800 bg-slate-900'}`}>
            <AppIcon icon={app.icon} name={app.name} color={app.themeColor} /><div className="min-w-0 flex-1"><strong className="block truncate">{app.name}</strong>
              <p className="text-xs text-slate-400 truncate mt-1">{app.id}</p><div className="flex justify-between gap-2 mt-2 text-xs"><span className="text-slate-400">{app.activePublishedVersion || 'Chưa có bản'} · {app.runtimeType}</span><span className={app.status === 'PUBLISHED' ? 'text-emerald-400' : 'text-slate-400'}>{app.status === 'PUBLISHED' ? 'Đang hiện' : 'Đang ẩn'}</span></div></div>
          </button>)}
        </aside>
        {(creating || selected) ? <MiniAppEditor key={creating ? 'new' : selected!.id} app={creating ? undefined : selected} onSaved={async id => { await onRefreshApps(); setSelectedId(id); setCreating(false); }} />
          : <div className={`${panelClass} text-slate-400`}>Thêm Mini App để bắt đầu quản lý.</div>}
      </div>
    </div>
  </main>;
};

function MiniAppEditor({ app, onSaved }: { app?: MiniAppEntity; onSaved: (id: string) => Promise<void> }) {
  const [id, setId] = useState('');
  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [icon, setIcon] = useState('');
  const [category, setCategory] = useState('General');
  const [runtimeType, setRuntimeType] = useState<MiniAppRuntimeType>('web');
  const [developerName, setDeveloperName] = useState('');
  const [supportEmail, setSupportEmail] = useState('');
  const [website, setWebsite] = useState('');
  const [themeColor, setThemeColor] = useState('#6366F1');
  const [granted, setGranted] = useState<string[]>([]);
  const [legacyGrants, setLegacyGrants] = useState('');
  const [file, setFile] = useState<File | null>(null);
  const [inspection, setInspection] = useState<PackageInspection | null>(null);
  const [notes, setNotes] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [message, setMessage] = useState('');
  const fileGeneration = useRef(0);
  const active = app?.versions?.find(version => version.version === app.activePublishedVersion);
  const requested = active?.manifest?.permissions || app?.requestedPermissions || [];
  const hasManifest = !!active?.manifest;

  useEffect(() => {
    if (!app) return;
    setId(app.id); setName(app.name); setDescription(app.description); setIcon(app.icon);
    setCategory(app.category); setRuntimeType(app.runtimeType); setGranted(app.capabilities);
    setLegacyGrants(app.capabilities.join('\n')); setDeveloperName(app.developerName || '');
    setSupportEmail(app.supportEmail || ''); setWebsite(app.website || ''); setThemeColor(app.themeColor || '#6366F1');
  }, [app]);

  const run = async (action: () => Promise<void>, success: string) => {
    setBusy(true); setError(''); setMessage('');
    try { await action(); setMessage(success); } catch (err) { setError(err instanceof Error ? err.message : 'Thao tác thất bại'); }
    finally { setBusy(false); }
  };
  const metadata = { name, description, icon: icon || 'code', category, developerName, supportEmail, website, themeColor };

  const inspectFile = async (selected: File | null) => {
    const generation = ++fileGeneration.current;
    setFile(selected); setInspection(null); setError(''); setMessage('');
    if (!selected || !app) return;
    if (selected.size > 20 * 1024 * 1024) { setFile(null); setError('Gói ZIP tối đa 20 MB'); return; }
    setBusy(true);
    try {
      const form = new FormData(); form.append('file', selected);
      const result = await request(`/${app.id}/packages/inspect`, 'POST', form);
      if (generation === fileGeneration.current) setInspection(result);
    } catch (err) { if (generation === fileGeneration.current) setError(err instanceof Error ? err.message : 'Gói không hợp lệ'); }
    finally { if (generation === fileGeneration.current) setBusy(false); }
  };

  return <div className="space-y-5 min-w-0">
    {error && <div role="alert" className="p-4 rounded-xl bg-red-500/10 text-red-300 whitespace-pre-line">{error}</div>}
    {message && <div role="status" className="p-4 rounded-xl bg-emerald-500/10 text-emerald-300">{message}</div>}
    <form className={panelClass} onSubmit={event => { event.preventDefault(); void run(async () => {
      const saved = await request(app ? `/${app.id}` : '', app ? 'PUT' : 'POST', app ? metadata : { ...metadata, id, runtimeType });
      await onSaved(saved.id);
    }, 'Đã lưu thông tin Mini App.'); }}>
      <div className="flex items-center gap-3"><AppIcon icon={icon} name={name} color={themeColor} /><div><h3 className="text-lg font-semibold">{app ? 'Thông tin Mini App' : 'Thêm Mini App'}</h3><p className="text-xs text-slate-400">Thông tin hiển thị trên Super App</p></div></div>
      <fieldset disabled={busy} className="space-y-4">
        <div className="grid sm:grid-cols-2 gap-4"><label className="block text-sm">App ID<input required readOnly={!!app} pattern="[a-z0-9][a-z0-9_-]{2,63}" value={id} onChange={event => setId(event.target.value)} className={`${inputClass} read-only:text-slate-500`} placeholder="coffee_shop" /></label>
          <label className="block text-sm">Loại runtime<select disabled={!!app} value={runtimeType} onChange={event => setRuntimeType(event.target.value as MiniAppRuntimeType)} className={inputClass}><option value="web">Web · HTML / JS / CSS</option><option value="schema">Schema · JSON</option></select></label></div>
        <label className="block text-sm">Tên hiển thị<input required maxLength={128} value={name} onChange={event => setName(event.target.value)} className={inputClass} /></label>
        <label className="block text-sm">Mô tả<textarea rows={3} maxLength={4000} value={description} onChange={event => setDescription(event.target.value)} className={inputClass} /></label>
        <label className="block text-sm">Icon<input maxLength={512} value={icon} onChange={event => setIcon(event.target.value)} className={inputClass} placeholder="https://example.com/icon.png" /></label>
        <p className="text-xs text-slate-400">Nhập URL ảnh hoặc dùng icon trong gói ZIP. Gói upload sẽ cập nhật icon từ app.json.</p>
        <div className="grid sm:grid-cols-2 gap-4"><label className="block text-sm">Danh mục<input required maxLength={64} value={category} onChange={event => setCategory(event.target.value)} className={inputClass} /></label>
          <label className="block text-sm">Nhà phát triển<input maxLength={128} value={developerName} onChange={event => setDeveloperName(event.target.value)} className={inputClass} /></label>
          <label className="block text-sm">Email hỗ trợ<input type="email" maxLength={254} value={supportEmail} onChange={event => setSupportEmail(event.target.value)} className={inputClass} /></label>
          <label className="block text-sm">Website<input type="url" maxLength={512} value={website} onChange={event => setWebsite(event.target.value)} className={inputClass} placeholder="https://…" /></label></div>
        <div className="grid sm:grid-cols-2 gap-4"><label className="block text-sm">Màu thương hiệu<input type="color" value={themeColor} onChange={event => setThemeColor(event.target.value)} className={`${inputClass} h-11`} /></label><label className="block text-sm">Phiên bản đang dùng<input readOnly value={app?.activePublishedVersion || 'Chưa upload gói'} className={`${inputClass} text-slate-400`} /></label></div>
        <button type="submit" className={buttonClass} disabled={busy}><Check size={16} />{busy ? 'Đang xử lý…' : 'Lưu thông tin'}</button>
      </fieldset>
    </form>
    {!app && <p className="text-sm text-slate-400">Lưu Mini App trước, sau đó upload gói ZIP để khai báo phiên bản và quyền yêu cầu.</p>}
    {app && <>
      <section className={panelClass}>
        <div className="flex flex-wrap justify-between items-center gap-3"><div><h3 className="font-semibold">{app.status === 'PUBLISHED' ? 'Đang hiển thị trên Super App' : 'Đang ẩn trên Super App'}</h3><p className="text-xs text-slate-400 mt-1">Upload giữ nguyên trạng thái này.</p></div>
          <button className={buttonClass} disabled={busy || !app.activePublishedVersion} onClick={() => void run(async () => { await request(`/${app.id}/visibility`, 'PATCH', { visible: app.status !== 'PUBLISHED' }); await onSaved(app.id); }, 'Đã cập nhật hiển thị.')}>
            {app.status === 'PUBLISHED' ? <EyeOff size={16} /> : <Eye size={16} />}{app.status === 'PUBLISHED' ? 'Ẩn Mini App' : 'Hiện Mini App'}</button></div>
      </section>
      <form className={panelClass} onSubmit={event => { event.preventDefault(); void run(async () => {
        const capabilities = hasManifest ? granted : [...new Set(legacyGrants.split(/[\n,]/).map(value => value.trim()).filter(Boolean))];
        await request(`/${app.id}`, 'PUT', { capabilities }); await onSaved(app.id);
      }, 'Đã lưu quyền được cấp. Mở lại Mini App để áp dụng.'); }}>
        <h3 className="font-semibold">Quyền yêu cầu và quyền được cấp</h3><p className="text-xs text-slate-400">Quyền yêu cầu lấy từ app.json của phiên bản đang dùng. Đánh dấu để cấp quyền. Quyền mới trong gói upload mặc định chưa được cấp.</p>
        {hasManifest ? <div className="space-y-2">{requested.length === 0 && <p className="text-sm text-slate-400">Phiên bản này không yêu cầu quyền.</p>}{requested.map(permission => <label key={permission} className="flex flex-wrap justify-between items-center gap-2 rounded-lg bg-slate-950 p-3 text-sm"><span className="font-mono break-all">{permission}</span><span className="flex items-center gap-2"><input type="checkbox" disabled={busy} checked={granted.includes(permission)} onChange={event => setGranted(previous => event.target.checked ? [...previous, permission] : previous.filter(value => value !== permission))} />Cấp quyền</span></label>)}</div>
          : <><p className="text-xs text-amber-300">Ứng dụng chưa có gói chuẩn. Upload ZIP để quản lý quyền theo manifest.</p><label className="block text-sm">Quyền được cấp hiện tại<textarea rows={4} value={legacyGrants} onChange={event => setLegacyGrants(event.target.value)} className={`${inputClass} font-mono`} disabled={busy} /></label></>}
        <button type="submit" disabled={busy} className={buttonClass}>Lưu quyền</button>
      </form>
      <section className={panelClass}>
        <div className="flex gap-3 items-center"><FileArchive className="text-indigo-400" /><div><h3 className="font-semibold">Upload phiên bản mới</h3><p className="text-xs text-slate-400 mt-1">Gói ZIP chuẩn Super App v1 · tối đa 20 MB</p></div></div>
        <details className="text-xs text-slate-400"><summary className="cursor-pointer text-indigo-300">Cấu trúc gói bắt buộc</summary><pre className="mt-3 bg-slate-950 p-3 rounded-lg overflow-auto">{`miniapp.zip\n├── app.json\n├── icon.png\n└── ${app.runtimeType === 'web' ? 'dist/\n    ├── index.html\n    └── assets/' : 'schema.json'}`}</pre><p className="mt-2">app.json khai báo manifestVersion: 1, appId, name, description, category, version, runtimeType, entry, icon, permissions. Dùng đường dẫn tương đối khi build web.</p><a className="inline-block mt-2 text-indigo-300 underline" href={`/examples/${app.runtimeType}-demo.zip`} download>Tải gói mẫu {app.runtimeType} để tham khảo</a><p className="mt-2">Gói mẫu dùng App ID {app.runtimeType}_demo. Đổi appId trong app.json theo ứng dụng đang chọn rồi đóng gói lại.</p></details>
        <label className="block text-sm">Chọn gói phiên bản<input type="file" accept=".zip,application/zip" disabled={busy} className={`${inputClass} file:mr-4 file:rounded file:border-0 file:bg-slate-700 file:text-white file:px-3 file:py-1`} onChange={event => { void inspectFile(event.target.files?.[0] || null); event.target.value = ''; }} /></label>
        {file && <p className="text-xs text-slate-400">{file.name} · {(file.size / 1024).toFixed(1)} KB</p>}
        {inspection && <div className="bg-slate-950 rounded-xl p-4 space-y-2 text-sm"><p className="text-emerald-400 flex items-center gap-2"><Check size={16} />Gói hợp lệ</p><p>{inspection.manifest.name} · <strong>v{inspection.manifest.version}</strong> · {inspection.manifest.runtimeType}</p><p className="text-slate-400">App ID: {inspection.manifest.appId} · {inspection.fileCount} file</p><p className="text-slate-400">Entry: {inspection.manifest.entry}</p><p className="text-slate-400">Quyền yêu cầu: {inspection.manifest.permissions.join(', ') || 'Không có'}</p><p className="font-mono text-xs break-all text-slate-500">SHA256: {inspection.checksum}</p><p className="text-xs text-amber-300">Upload sẽ chuyển sang phiên bản này và cập nhật thông tin/icon theo app.json. Quyền đã cấp được giữ nếu vẫn được yêu cầu.</p></div>}
        <label className="block text-sm">Ghi chú phát hành<textarea maxLength={8000} rows={2} value={notes} onChange={event => setNotes(event.target.value)} className={inputClass} disabled={busy} /></label>
        <button className={buttonClass} disabled={busy || !file || !inspection} onClick={() => void run(async () => {
          const form = new FormData(); form.append('file', file!); form.append('notes', notes);
          await request(`/${app.id}/versions`, 'POST', form); setFile(null); setInspection(null); setNotes(''); await onSaved(app.id);
        }, 'Đã upload phiên bản. Kiểm tra quyền được cấp rồi bật hiển thị nếu cần.')}><Upload size={16} />{busy ? 'Đang xử lý…' : 'Upload và dùng phiên bản này'}</button>
      </section>
      <section className={panelClass}><h3 className="font-semibold">Lịch sử phiên bản</h3>
        {!app.versions?.length && <p className="text-sm text-slate-400">Chưa có phiên bản.</p>}
        {[...(app.versions || [])].sort((a, b) => Date.parse(b.createdAt) - Date.parse(a.createdAt)).map(version => <div key={version.id} className="border-t border-slate-800 pt-3 text-sm space-y-1">
          <p><strong>v{version.version}</strong>{version.version === app.activePublishedVersion && <span className="ml-2 text-emerald-400 text-xs">Đang dùng</span>}<span className="ml-3 text-slate-400 text-xs">{new Date(version.createdAt).toLocaleString('vi-VN')}</span></p>
          {version.manifest && <p className="text-xs text-slate-400">Gói v{version.manifest.manifestVersion} · {version.manifest.runtimeType} · {((version.packageSize || 0) / 1024).toFixed(1)} KB · {version.manifest.permissions.length} quyền yêu cầu</p>}
          {version.reviewNotes && <p className="text-slate-400">{version.reviewNotes}</p>}
          {version.checksum && <p className="text-xs text-slate-500 font-mono break-all">SHA256: {version.checksum}</p>}
        </div>)}
      </section>
    </>}
  </div>;
}
