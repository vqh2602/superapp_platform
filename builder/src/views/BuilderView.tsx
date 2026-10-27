import React, { useState } from 'react';
import {
  MiniAppEntity,
  MiniAppSchema,
  PageDefinition,
  ComponentDefinition,
} from '../types';
import { MobileSimulator } from '../components/MobileSimulator';
import { PropertyInspector } from '../components/PropertyInspector';
import { defaultCoffeeShopApp, coffeeShopSchema } from '../templates/coffeeShopTemplate';
import {
  Save,
  Send,
  Plus,
  Trash2,
  Sparkles,
  Layers,
  Smartphone,
  CheckCircle2,
  AlertCircle,
  FileCode,
  Coffee,
  Check,
} from 'lucide-react';

interface BuilderViewProps {
  currentApp: MiniAppEntity;
  onAppChange: (app: MiniAppEntity) => void;
  onSaveDraft: (app: MiniAppEntity) => Promise<void>;
  onUploadVersion: (appId: string, version: string, notes: string) => Promise<void>;
}

export const BuilderView: React.FC<BuilderViewProps> = ({
  currentApp,
  onAppChange,
  onSaveDraft,
  onUploadVersion,
}) => {
  const [activePageId, setActivePageId] = useState<string>(
    currentApp.draftSchema?.pages?.[0]?.id || 'home'
  );
  const [selectedCompId, setSelectedCompId] = useState<string | null>(null);
  const [isSaving, setIsSaving] = useState(false);
  const [saveSuccess, setSaveSuccess] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [showSubmitModal, setShowSubmitModal] = useState(false);
  const [submitVersion, setSubmitVersion] = useState('1.0.0');
  const [submitNotes, setSubmitNotes] = useState('Phiên bản đầu tiên của Mini App');
  const [errorBanner, setErrorBanner] = useState<string | null>(null);

  const schema: MiniAppSchema = currentApp.draftSchema || {
    schemaVersion: 1,
    pages: [{ id: 'home', title: currentApp.name, components: [] }],
  };

  const activePage =
    schema.pages.find((p) => p.id === activePageId) || schema.pages[0];

  // Helper to find component recursively
  const findComponent = (
    components: ComponentDefinition[],
    id: string
  ): ComponentDefinition | null => {
    for (const c of components) {
      if (c.id === id) return c;
      if (c.children) {
        const found = findComponent(c.children, id);
        if (found) return found;
      }
    }
    return null;
  };

  const selectedComponent = selectedCompId
    ? findComponent(activePage?.components || [], selectedCompId)
    : null;

  // Add Component to active page
  const addComponent = (type: ComponentDefinition['type']) => {
    if (!activePage) return;
    const newId = `${type}_${Date.now().toString().slice(-4)}`;
    let newComp: ComponentDefinition;

    switch (type) {
      case 'text':
        newComp = {
          id: newId,
          type: 'text',
          props: { value: 'Đoạn văn bản mới', variant: 'body', color: '#E2E8F0' },
        };
        break;
      case 'image':
        newComp = {
          id: newId,
          type: 'image',
          props: {
            src: 'https://images.unsplash.com/photo-1517701604599-bb29b565090c?auto=format&fit=crop&w=400&q=80',
            alt: 'Demo Image',
            height: 140,
            borderRadius: 10,
          },
        };
        break;
      case 'button':
        newComp = {
          id: newId,
          type: 'button',
          props: { text: 'Nút bấm mới', variant: 'primary' },
          events: { onClick: { type: 'native_action', action: 'navigation.close' } },
        };
        break;
      case 'container':
        newComp = {
          id: newId,
          type: 'container',
          props: { padding: 12, backgroundColor: '#1E293B', borderRadius: 12 },
          children: [],
        };
        break;
      case 'product_list':
        newComp = {
          id: newId,
          type: 'product_list',
          props: {
            items: [
              {
                id: 'p1',
                title: 'Sản phẩm mẫu A',
                price: 50000,
                desc: 'Mô tả ngắn gọn',
                image: 'https://images.unsplash.com/photo-1541167760496-1628856ab772?auto=format&fit=crop&w=150&q=80',
              },
            ],
          },
        };
        break;
      case 'input':
        newComp = {
          id: newId,
          type: 'input',
          props: { label: 'Họ và tên', placeholder: 'Nhập họ tên quý khách...' },
        };
        break;
      default:
        return;
    }

    const updatedComponents = [...activePage.components, newComp];
    updateActivePage({ ...activePage, components: updatedComponents });
    setSelectedCompId(newId);
  };

  const updateActivePage = (page: PageDefinition) => {
    const updatedPages = schema.pages.map((p) => (p.id === page.id ? page : p));
    updateSchema({ ...schema, pages: updatedPages });
  };

  const updateSchema = (newSchema: MiniAppSchema) => {
    onAppChange({
      ...currentApp,
      draftSchema: newSchema,
    });
  };

  // Update component recursively
  const updateComponentInTree = (
    list: ComponentDefinition[],
    updated: ComponentDefinition
  ): ComponentDefinition[] => {
    return list.map((c) => {
      if (c.id === updated.id) return updated;
      if (c.children) {
        return { ...c, children: updateComponentInTree(c.children, updated) };
      }
      return c;
    });
  };

  // Delete component recursively
  const deleteComponentFromTree = (
    list: ComponentDefinition[],
    id: string
  ): ComponentDefinition[] => {
    return list
      .filter((c) => c.id !== id)
      .map((c) => {
        if (c.children) {
          return { ...c, children: deleteComponentFromTree(c.children, id) };
        }
        return c;
      });
  };

  const handleUpdateComponent = (updated: ComponentDefinition) => {
    if (!activePage) return;
    const nextComponents = updateComponentInTree(activePage.components, updated);
    updateActivePage({ ...activePage, components: nextComponents });
  };

  const handleDeleteComponent = (id: string) => {
    if (!activePage) return;
    const nextComponents = deleteComponentFromTree(activePage.components, id);
    updateActivePage({ ...activePage, components: nextComponents });
    if (selectedCompId === id) setSelectedCompId(null);
  };

  const handleAddPage = () => {
    const pageNum = schema.pages.length + 1;
    const newPage: PageDefinition = {
      id: `page_${pageNum}`,
      title: `Trang Mới ${pageNum}`,
      components: [
        {
          id: `txt_${Date.now()}`,
          type: 'text',
          props: { value: `Nội dung trang ${pageNum}`, variant: 'h2' },
        },
      ],
    };
    updateSchema({ ...schema, pages: [...schema.pages, newPage] });
    setActivePageId(newPage.id);
  };

  const handleDeletePage = (pageId: string) => {
    if (schema.pages.length <= 1) {
      alert('Mini App phải có ít nhất 1 trang!');
      return;
    }
    const nextPages = schema.pages.filter((p) => p.id !== pageId);
    updateSchema({ ...schema, pages: nextPages });
    setActivePageId(nextPages[0].id);
  };

  const handleLoadCoffeeShopTemplate = () => {
    onAppChange({
      ...currentApp,
      name: defaultCoffeeShopApp.name,
      description: defaultCoffeeShopApp.description,
      icon: 'coffee',
      category: 'Food & Beverage',
      capabilities: defaultCoffeeShopApp.capabilities,
      draftSchema: coffeeShopSchema,
    });
    setActivePageId('home');
    setSelectedCompId(null);
  };

  const handleSave = async () => {
    try {
      setIsSaving(true);
      setErrorBanner(null);
      await onSaveDraft(currentApp);
      setSaveSuccess(true);
      setTimeout(() => setSaveSuccess(false), 2500);
    } catch (err: any) {
      setErrorBanner(err.message || 'Lỗi khi lưu bản thảo');
    } finally {
      setIsSaving(false);
    }
  };

  const handleSubmit = async () => {
    try {
      setIsSubmitting(true);
      setErrorBanner(null);
      await onSaveDraft(currentApp);
      await onUploadVersion(currentApp.id, submitVersion, submitNotes);
      setShowSubmitModal(false);
      setSaveSuccess(true);
      setTimeout(() => setSaveSuccess(false), 3000);
    } catch (err: any) {
      setErrorBanner(err.message || 'Lỗi khi upload phiên bản');
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="flex-1 flex flex-col h-full overflow-hidden bg-slate-950">
      {/* Top Action Bar */}
      <div className="h-14 border-b border-slate-800 bg-slate-900/90 px-6 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="w-8 h-8 rounded-lg bg-amber-500/10 border border-amber-500/30 flex items-center justify-center text-amber-400 font-bold">
            <Coffee className="w-4 h-4" />
          </div>
          <div>
            <div className="flex items-center gap-2">
              <h2 className="text-sm font-bold text-slate-100">{currentApp.name || 'Mini App Chưa Đặt Tên'}</h2>
              <span className="font-mono text-[11px] px-1.5 py-0.5 rounded bg-slate-800 text-slate-400 border border-slate-700">
                {currentApp.id}
              </span>
              <span
                className={`text-[10px] font-bold px-2 py-0.5 rounded-full uppercase ${
                  currentApp.status === 'PUBLISHED'
                    ? 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/30'
                    : currentApp.status === 'SUBMITTED'
                    ? 'bg-blue-500/10 text-blue-400 border border-blue-500/30'
                    : 'bg-amber-500/10 text-amber-400 border border-amber-500/30'
                }`}
              >
                {currentApp.status}
              </span>
            </div>
            <p className="text-[11px] text-slate-400 truncate max-w-sm">
              {currentApp.description || 'Chưa có mô tả'}
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2.5">
          <button
            onClick={handleLoadCoffeeShopTemplate}
            className="flex items-center gap-1.5 px-3 py-1.5 bg-slate-800 hover:bg-slate-700 text-amber-400 rounded-xl text-xs font-semibold border border-slate-700 transition-all"
            title="Nạp mẫu Coffee Shop đã thiết kế sẵn"
          >
            <Sparkles className="w-3.5 h-3.5" />
            <span>1-Click Coffee Shop Mẫu</span>
          </button>

          <button
            onClick={handleSave}
            disabled={isSaving}
            className="flex items-center gap-1.5 px-4 py-1.5 bg-slate-800 hover:bg-slate-700 text-slate-200 rounded-xl text-xs font-semibold border border-slate-700 transition-all shadow-sm"
          >
            {saveSuccess ? (
              <>
                <Check className="w-3.5 h-3.5 text-emerald-400" />
                <span className="text-emerald-400">Đã lưu nháp!</span>
              </>
            ) : (
              <>
                <Save className="w-3.5 h-3.5" />
                <span>{isSaving ? 'Đang lưu...' : 'Lưu Nháp'}</span>
              </>
            )}
          </button>

          <button
            onClick={() => {
              const parts = (currentApp.activePublishedVersion || '0.0.0').split('.').map(Number);
              setSubmitVersion(currentApp.activePublishedVersion ? `${parts[0]}.${parts[1]}.${parts[2] + 1}` : '1.0.0');
              setShowSubmitModal(true);
            }}
            className="flex items-center gap-1.5 px-4 py-1.5 bg-gradient-to-r from-amber-500 to-amber-600 hover:from-amber-400 hover:to-amber-500 text-slate-950 rounded-xl text-xs font-bold transition-all shadow-md active:scale-98"
          >
            <Send className="w-3.5 h-3.5" />
            <span>Upload phiên bản</span>
          </button>
        </div>
      </div>

      {errorBanner && (
        <div className="bg-red-500/10 border-b border-red-500/30 px-6 py-2 text-xs text-red-400 flex items-center gap-2">
          <AlertCircle className="w-4 h-4 flex-shrink-0" />
          <span>{errorBanner}</span>
        </div>
      )}

      {/* Main 3-Column Studio Layout */}
      <div className="flex-1 flex overflow-hidden">
        {/* Left Column: Metadata, Page Manager, Component Palette */}
        <div className="w-72 border-r border-slate-800 bg-slate-900/50 flex flex-col overflow-y-auto p-4 gap-5">
          {/* App Metadata Configuration */}
          <div className="space-y-3">
            <h3 className="text-xs font-bold text-slate-300 uppercase tracking-wider flex items-center gap-1.5">
              <FileCode className="w-3.5 h-3.5 text-amber-400" />
              Thông Tin Ứng Dụng
            </h3>

            <div className="space-y-2 text-xs">
              <div>
                <label className="text-slate-400 block mb-1">Mã App (ID Slug)</label>
                <input
                  type="text"
                  value={currentApp.id}
                  disabled={currentApp.status !== 'DRAFT'}
                  onChange={(e) =>
                    onAppChange({
                      ...currentApp,
                      id: e.target.value.toLowerCase().replace(/[^a-z0-9_]/g, '_'),
                    })
                  }
                  className={`w-full bg-slate-950 border rounded-lg px-2.5 py-1.5 font-mono ${
                    currentApp.status === 'DRAFT'
                      ? 'border-slate-700 text-slate-200 focus:border-amber-400'
                      : 'border-slate-800 text-slate-500'
                  }`}
                />
              </div>

              <div>
                <label className="text-slate-400 block mb-1">Tên Mini App</label>
                <input
                  type="text"
                  value={currentApp.name}
                  onChange={(e) => onAppChange({ ...currentApp, name: e.target.value })}
                  className="w-full bg-slate-950 border border-slate-700 rounded-lg px-2.5 py-1.5 text-slate-200 outline-none focus:border-amber-400"
                />
              </div>

              <div>
                <label className="text-slate-400 block mb-1">Biểu tượng (Icon)</label>
                <select
                  value={currentApp.icon || 'coffee'}
                  onChange={(e) => onAppChange({ ...currentApp, icon: e.target.value })}
                  className="w-full bg-slate-950 border border-slate-700 rounded-lg px-2.5 py-1.5 text-slate-200 outline-none"
                >
                  <option value="coffee">☕ Cà phê (coffee)</option>
                  <option value="storefront">🏪 Cửa hàng (storefront)</option>
                  <option value="shopping_bag">🛍️ Mua sắm (shopping_bag)</option>
                  <option value="utensils">🍽️ Ăn uống (utensils)</option>
                  <option value="sparkles">✨ Dịch vụ (sparkles)</option>
                  <option value="code">💻 Công nghệ (code)</option>
                </select>
              </div>

              <div>
                <label className="text-slate-400 block mb-1">Danh mục</label>
                <select
                  value={currentApp.category}
                  onChange={(e) => onAppChange({ ...currentApp, category: e.target.value })}
                  className="w-full bg-slate-950 border border-slate-700 rounded-lg px-2.5 py-1.5 text-slate-200 outline-none"
                >
                  <option value="Food & Beverage">Food & Beverage</option>
                  <option value="Shopping">Shopping / Thương Mại</option>
                  <option value="Services">Dịch Vụ Tiện Ích</option>
                  <option value="Entertainment">Giải Trí</option>
                  <option value="General">Chung</option>
                </select>
              </div>

              <div>
                <label className="text-slate-400 block mb-1">Mô tả ngắn</label>
                <textarea
                  rows={2}
                  value={currentApp.description}
                  onChange={(e) => onAppChange({ ...currentApp, description: e.target.value })}
                  className="w-full bg-slate-950 border border-slate-700 rounded-lg p-2 text-slate-200 outline-none resize-none"
                />
              </div>

              <div>
                <label className="text-slate-400 block mb-1.5 font-semibold">Quyền Hạn (Capabilities)</label>
                <div className="space-y-1.5 bg-slate-950 p-2.5 rounded-xl border border-slate-800">
                  {[
                    { key: 'payment.openCheckout', label: '💳 Thanh toán Native' },
                    { key: 'device.scanQRCode', label: '📷 Quét mã QR' },
                    { key: 'device.getLocation', label: '📍 Vị trí địa lý' },
                    { key: 'user.getProfile', label: '👤 Hồ sơ người dùng' },
                    { key: 'navigation.close', label: '🚪 Đóng Mini App' },
                  ].map((cap) => {
                    const isChecked = currentApp.capabilities?.includes(cap.key) ?? false;
                    return (
                      <label key={cap.key} className="flex items-center gap-2 cursor-pointer text-slate-300 hover:text-white">
                        <input
                          type="checkbox"
                          checked={isChecked}
                          onChange={(e) => {
                            const next = e.target.checked
                              ? [...(currentApp.capabilities || []), cap.key]
                              : (currentApp.capabilities || []).filter((c) => c !== cap.key);
                            onAppChange({ ...currentApp, capabilities: next });
                          }}
                          className="rounded border-slate-700 bg-slate-900 text-amber-500 focus:ring-0"
                        />
                        <span className="text-[11px]">{cap.label}</span>
                      </label>
                    );
                  })}
                </div>
              </div>
            </div>
          </div>

          {/* Page Manager */}
          <div className="space-y-2 pt-3 border-t border-slate-800">
            <div className="flex items-center justify-between">
              <h3 className="text-xs font-bold text-slate-300 uppercase tracking-wider flex items-center gap-1.5">
                <Layers className="w-3.5 h-3.5 text-amber-400" />
                Các Trang ({schema.pages.length})
              </h3>
              <button
                onClick={handleAddPage}
                className="p-1 hover:bg-slate-800 rounded text-amber-400 text-xs flex items-center gap-1"
                title="Thêm trang mới"
              >
                <Plus className="w-3.5 h-3.5" />
                <span>Thêm</span>
              </button>
            </div>

            <div className="space-y-1.5">
              {schema.pages.map((page) => (
                <div
                  key={page.id}
                  onClick={() => {
                    setActivePageId(page.id);
                    setSelectedCompId(null);
                  }}
                  className={`flex items-center justify-between px-3 py-2 rounded-xl text-xs cursor-pointer transition-all ${
                    page.id === activePageId
                      ? 'bg-amber-500/10 text-amber-300 border border-amber-500/40 font-semibold'
                      : 'bg-slate-950 text-slate-400 hover:text-slate-200 border border-slate-800/80'
                  }`}
                >
                  <span className="truncate">{page.title}</span>
                  {schema.pages.length > 1 && (
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        handleDeletePage(page.id);
                      }}
                      className="text-slate-600 hover:text-red-400 p-0.5"
                    >
                      <Trash2 className="w-3 h-3" />
                    </button>
                  )}
                </div>
              ))}
            </div>
          </div>

          {/* Component Palette */}
          <div className="space-y-2 pt-3 border-t border-slate-800">
            <h3 className="text-xs font-bold text-slate-300 uppercase tracking-wider">Thêm Component</h3>
            <div className="grid grid-cols-2 gap-2 text-xs">
              <button
                onClick={() => addComponent('text')}
                className="p-2.5 bg-slate-950 hover:bg-slate-800 border border-slate-800 rounded-xl text-slate-300 hover:text-amber-400 flex flex-col items-center gap-1.5 transition-all text-[11px]"
              >
                <span className="text-base font-bold">T</span>
                <span>Văn Bản</span>
              </button>

              <button
                onClick={() => addComponent('image')}
                className="p-2.5 bg-slate-950 hover:bg-slate-800 border border-slate-800 rounded-xl text-slate-300 hover:text-amber-400 flex flex-col items-center gap-1.5 transition-all text-[11px]"
              >
                <span className="text-base">🖼️</span>
                <span>Hình Ảnh</span>
              </button>

              <button
                onClick={() => addComponent('button')}
                className="p-2.5 bg-slate-950 hover:bg-slate-800 border border-slate-800 rounded-xl text-slate-300 hover:text-amber-400 flex flex-col items-center gap-1.5 transition-all text-[11px]"
              >
                <span className="text-base">🔘</span>
                <span>Nút Bấm</span>
              </button>

              <button
                onClick={() => addComponent('container')}
                className="p-2.5 bg-slate-950 hover:bg-slate-800 border border-slate-800 rounded-xl text-slate-300 hover:text-amber-400 flex flex-col items-center gap-1.5 transition-all text-[11px]"
              >
                <span className="text-base">📦</span>
                <span>Khối Hộp</span>
              </button>

              <button
                onClick={() => addComponent('product_list')}
                className="p-2.5 bg-slate-950 hover:bg-slate-800 border border-slate-800 rounded-xl text-slate-300 hover:text-amber-400 flex flex-col items-center gap-1.5 transition-all text-[11px]"
              >
                <span className="text-base">🛍️</span>
                <span>Sản Phẩm</span>
              </button>

              <button
                onClick={() => addComponent('input')}
                className="p-2.5 bg-slate-950 hover:bg-slate-800 border border-slate-800 rounded-xl text-slate-300 hover:text-amber-400 flex flex-col items-center gap-1.5 transition-all text-[11px]"
              >
                <span className="text-base">📝</span>
                <span>Ô Nhập Liệu</span>
              </button>
            </div>
          </div>
        </div>

        {/* Center Column: Live Mobile Viewport Frame */}
        <div className="flex-1 bg-slate-950 flex flex-col items-center justify-center p-6 overflow-y-auto relative">
          <div className="mb-3 flex items-center gap-2 text-xs text-slate-400">
            <Smartphone className="w-4 h-4 text-amber-400" />
            <span>Mô Phỏng Trực Tiếp (Live Phone Preview)</span>
          </div>

          <MobileSimulator
            schema={schema}
            appName={currentApp.name}
            selectedComponentId={selectedCompId}
            onSelectComponent={(id) => setSelectedCompId(id)}
          />
        </div>

        {/* Right Column: Property Inspector */}
        <div className="w-80 border-l border-slate-800 bg-slate-900/50 p-4 overflow-y-auto">
          <PropertyInspector
            selectedComponent={selectedComponent}
            activePage={activePage}
            schema={schema}
            onUpdateComponent={handleUpdateComponent}
            onDeleteComponent={handleDeleteComponent}
            onUpdatePage={updateActivePage}
            onUpdateSchema={updateSchema}
          />
        </div>
      </div>

      {/* Submit for Review Modal */}
      {showSubmitModal && (
        <div className="fixed inset-0 bg-slate-950/80 backdrop-blur-sm flex items-center justify-center p-4 z-50">
          <div className="bg-slate-900 border border-slate-700 rounded-2xl w-full max-w-md p-6 shadow-2xl space-y-4 text-xs">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-xl bg-amber-500/10 text-amber-400 flex items-center justify-center">
                <Send className="w-5 h-5" />
              </div>
              <div>
                <h3 className="text-base font-bold text-slate-100">Upload phiên bản Mini App</h3>
                <p className="text-slate-400 text-[11px]">Lưu nội dung hiện tại thành phiên bản mới</p>
              </div>
            </div>

            <div className="space-y-3">
              <div>
                <label className="text-slate-300 block mb-1 font-semibold">Phiên bản (Semantic Version)</label>
                <input
                  type="text"
                  value={submitVersion}
                  onChange={(e) => setSubmitVersion(e.target.value)}
                  placeholder="e.g. 1.0.0"
                  className="w-full bg-slate-950 border border-slate-700 rounded-lg px-3 py-2 text-slate-100 font-mono outline-none focus:border-amber-400"
                />
              </div>

              <div>
                <label className="text-slate-300 block mb-1 font-semibold">Ghi chú phát hành (Release Notes)</label>
                <textarea
                  rows={3}
                  value={submitNotes}
                  onChange={(e) => setSubmitNotes(e.target.value)}
                  placeholder="Mô tả các tính năng mới trong phiên bản này..."
                  className="w-full bg-slate-950 border border-slate-700 rounded-lg p-2.5 text-slate-100 outline-none resize-none focus:border-amber-400"
                />
              </div>

              <div className="p-3 bg-amber-500/10 rounded-xl border border-amber-500/20 text-amber-300 text-[11px] leading-relaxed">
                Phiên bản được dùng ngay và giữ nguyên trạng thái ẩn/hiện. Bật hiển thị trong trang Quản lý Mini App.
              </div>
            </div>

            <div className="flex items-center justify-end gap-2.5 pt-2">
              <button
                onClick={() => setShowSubmitModal(false)}
                className="px-4 py-2 rounded-xl bg-slate-800 text-slate-300 hover:bg-slate-700 font-semibold"
              >
                Hủy
              </button>
              <button
                onClick={handleSubmit}
                disabled={isSubmitting}
                className="px-5 py-2 rounded-xl bg-gradient-to-r from-amber-500 to-amber-600 text-slate-950 font-bold hover:from-amber-400 shadow-lg"
              >
                {isSubmitting ? 'Đang gửi...' : 'Xác nhận upload'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
