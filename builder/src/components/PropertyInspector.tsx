import React from 'react';
import { ComponentDefinition, PageDefinition, MiniAppSchema } from '../types';
import { Trash2, Copy, Sliders, Type, Image, Square, Layout, ShoppingBag, Terminal } from 'lucide-react';

interface PropertyInspectorProps {
  selectedComponent: ComponentDefinition | null;
  activePage: PageDefinition | null;
  schema: MiniAppSchema;
  onUpdateComponent: (updated: ComponentDefinition) => void;
  onDeleteComponent: (id: string) => void;
  onUpdatePage: (updated: PageDefinition) => void;
  onUpdateSchema: (updated: MiniAppSchema) => void;
}

export const PropertyInspector: React.FC<PropertyInspectorProps> = ({
  selectedComponent,
  activePage,
  schema,
  onUpdateComponent,
  onDeleteComponent,
  onUpdatePage,
  onUpdateSchema,
}) => {
  if (!selectedComponent) {
    // Show Page & Theme Properties
    return (
      <div className="bg-slate-900 border border-slate-800 rounded-2xl p-4 h-full flex flex-col gap-4 text-xs">
        <div className="flex items-center gap-2 pb-3 border-b border-slate-800 text-slate-300 font-bold">
          <Sliders className="w-4 h-4 text-amber-400" />
          <span>Thuộc Tính Trang & Giao Diện</span>
        </div>

        {activePage && (
          <div className="space-y-3">
            <h4 className="text-[11px] font-bold text-slate-400 uppercase tracking-wider">Trang Hiện Tại</h4>
            <div>
              <label className="text-slate-400 block mb-1">Mã Trang (Page ID)</label>
              <input
                type="text"
                value={activePage.id}
                disabled
                className="w-full bg-slate-950 border border-slate-800 rounded-lg px-2.5 py-1.5 text-slate-500 font-mono"
              />
            </div>
            <div>
              <label className="text-slate-400 block mb-1">Tiêu Đề Trang</label>
              <input
                type="text"
                value={activePage.title}
                onChange={(e) => onUpdatePage({ ...activePage, title: e.target.value })}
                className="w-full bg-slate-950 border border-slate-700 rounded-lg px-2.5 py-1.5 text-slate-200 focus:border-amber-400 outline-none"
              />
            </div>
          </div>
        )}

        <div className="space-y-3 pt-3 border-t border-slate-800">
          <h4 className="text-[11px] font-bold text-slate-400 uppercase tracking-wider">Cấu Hình Màu Sắc (Theme)</h4>
          <div>
            <label className="text-slate-400 block mb-1">Màu Chủ Đạo (Primary Color)</label>
            <div className="flex items-center gap-2">
              <input
                type="color"
                value={schema.theme?.primaryColor || '#D97706'}
                onChange={(e) =>
                  onUpdateSchema({
                    ...schema,
                    theme: { ...schema.theme, primaryColor: e.target.value },
                  })
                }
                className="w-8 h-8 rounded border-none cursor-pointer bg-transparent"
              />
              <span className="font-mono text-slate-300">{schema.theme?.primaryColor || '#D97706'}</span>
            </div>
          </div>
        </div>

        <div className="mt-auto p-3 bg-slate-950/60 rounded-xl border border-slate-800/80 text-slate-400 text-[11px] leading-relaxed">
          💡 Nhấp vào bất kỳ component nào trong màn hình điện thoại hoặc danh sách bên trái để chỉnh sửa chi tiết.
        </div>
      </div>
    );
  }

  const props = selectedComponent.props;
  const updateProp = (key: string, value: any) => {
    onUpdateComponent({
      ...selectedComponent,
      props: {
        ...props,
        [key]: value,
      },
    });
  };

  const updateAction = (type: 'navigate' | 'native_action', actionOrPageId: string, params?: any) => {
    if (type === 'navigate') {
      onUpdateComponent({
        ...selectedComponent,
        events: {
          onClick: {
            type: 'navigate',
            pageId: actionOrPageId,
          },
        },
      });
    } else {
      onUpdateComponent({
        ...selectedComponent,
        events: {
          onClick: {
            type: 'native_action',
            action: actionOrPageId,
            params: params || {},
          },
        },
      });
    }
  };

  return (
    <div className="bg-slate-900 border border-slate-800 rounded-2xl p-4 h-full flex flex-col gap-4 text-xs overflow-y-auto">
      {/* Header */}
      <div className="flex items-center justify-between pb-3 border-b border-slate-800">
        <div className="flex items-center gap-2">
          <span className="p-1 rounded bg-amber-500/10 text-amber-400 font-mono font-bold text-[11px] uppercase">
            {selectedComponent.type}
          </span>
          <span className="text-slate-400 font-mono text-[11px] truncate max-w-[120px]">
            #{selectedComponent.id}
          </span>
        </div>
        <button
          onClick={() => onDeleteComponent(selectedComponent.id)}
          className="p-1.5 text-red-400 hover:bg-red-500/10 rounded-lg transition-all"
          title="Xoá component"
        >
          <Trash2 className="w-3.5 h-3.5" />
        </button>
      </div>

      {/* Component Specific Props */}
      {selectedComponent.type === 'text' && (
        <div className="space-y-3">
          <div>
            <label className="text-slate-400 block mb-1">Nội dung văn bản</label>
            <textarea
              rows={3}
              value={props.value || ''}
              onChange={(e) => updateProp('value', e.target.value)}
              className="w-full bg-slate-950 border border-slate-700 rounded-lg p-2 text-slate-200 focus:border-amber-400 outline-none resize-none"
            />
          </div>
          <div>
            <label className="text-slate-400 block mb-1">Kiểu chữ (Variant)</label>
            <select
              value={props.variant || 'body'}
              onChange={(e) => updateProp('variant', e.target.value)}
              className="w-full bg-slate-950 border border-slate-700 rounded-lg px-2.5 py-1.5 text-slate-200 outline-none"
            >
              <option value="h1">H1 - Tiêu đề lớn (24px)</option>
              <option value="h2">H2 - Tiêu đề vừa (20px)</option>
              <option value="h3">H3 - Tiêu đề nhỏ (16px)</option>
              <option value="body">Body - Văn bản thường (14px)</option>
              <option value="subtitle">Subtitle - Chú thích mờ (12px)</option>
            </select>
          </div>
          <div>
            <label className="text-slate-400 block mb-1">Màu chữ</label>
            <div className="flex items-center gap-2">
              <input
                type="color"
                value={props.color || '#E2E8F0'}
                onChange={(e) => updateProp('color', e.target.value)}
                className="w-7 h-7 rounded border-none cursor-pointer bg-transparent"
              />
              <span className="font-mono text-slate-300">{props.color || '#E2E8F0'}</span>
            </div>
          </div>
        </div>
      )}

      {selectedComponent.type === 'image' && (
        <div className="space-y-3">
          <div>
            <label className="text-slate-400 block mb-1">Đường dẫn ảnh (URL)</label>
            <input
              type="text"
              value={props.src || ''}
              onChange={(e) => updateProp('src', e.target.value)}
              className="w-full bg-slate-950 border border-slate-700 rounded-lg px-2.5 py-1.5 text-slate-200 outline-none"
            />
          </div>
          <div>
            <label className="text-slate-400 block mb-1">Chiều cao ảnh (px)</label>
            <input
              type="number"
              value={props.height || 140}
              onChange={(e) => updateProp('height', Number(e.target.value))}
              className="w-full bg-slate-950 border border-slate-700 rounded-lg px-2.5 py-1.5 text-slate-200 outline-none"
            />
          </div>
          <div>
            <label className="text-slate-400 block mb-1">Bo góc (px)</label>
            <input
              type="number"
              value={props.borderRadius || 10}
              onChange={(e) => updateProp('borderRadius', Number(e.target.value))}
              className="w-full bg-slate-950 border border-slate-700 rounded-lg px-2.5 py-1.5 text-slate-200 outline-none"
            />
          </div>
        </div>
      )}

      {selectedComponent.type === 'button' && (
        <div className="space-y-3">
          <div>
            <label className="text-slate-400 block mb-1">Nhãn nút (Text)</label>
            <input
              type="text"
              value={props.text || ''}
              onChange={(e) => updateProp('text', e.target.value)}
              className="w-full bg-slate-950 border border-slate-700 rounded-lg px-2.5 py-1.5 text-slate-200 outline-none"
            />
          </div>
          <div>
            <label className="text-slate-400 block mb-1">Kiểu dáng (Variant)</label>
            <select
              value={props.variant || 'primary'}
              onChange={(e) => updateProp('variant', e.target.value)}
              className="w-full bg-slate-950 border border-slate-700 rounded-lg px-2.5 py-1.5 text-slate-200 outline-none"
            >
              <option value="primary">Primary (Vàng nổi bật)</option>
              <option value="secondary">Secondary (Xám đen)</option>
              <option value="outline">Outline (Viền vàng)</option>
            </select>
          </div>

          <div className="pt-2 border-t border-slate-800">
            <label className="text-amber-400 font-bold block mb-1">Hành động khi nhấn (Event Action)</label>
            <select
              value={
                selectedComponent.events?.onClick?.type === 'navigate'
                  ? 'navigate'
                  : selectedComponent.events?.onClick?.action || 'none'
              }
              onChange={(e) => {
                const val = e.target.value;
                if (val === 'none') {
                  const { onClick, ...rest } = selectedComponent.events || {};
                  onUpdateComponent({ ...selectedComponent, events: rest });
                } else if (val === 'navigate') {
                  updateAction('navigate', schema.pages[0]?.id || 'home');
                } else if (val === 'payment.openCheckout') {
                  updateAction('native_action', 'payment.openCheckout', {
                    amount: 75000,
                    description: 'Thanh toán đơn hàng',
                    currency: 'VND',
                  });
                } else {
                  updateAction('native_action', val, {});
                }
              }}
              className="w-full bg-slate-950 border border-slate-700 rounded-lg px-2.5 py-1.5 text-slate-200 outline-none"
            >
              <option value="none">Không có hành động</option>
              <option value="navigate">🧭 Chuyển trang (Page Navigation)</option>
              <option value="payment.openCheckout">💳 Thanh toán Native (Mock Checkout)</option>
              <option value="device.scanQRCode">📷 Quét mã QR (Device API)</option>
              <option value="navigation.close">🚪 Đóng Mini App (SuperApp Bridge)</option>
            </select>
          </div>

          {selectedComponent.events?.onClick?.type === 'navigate' && (
            <div>
              <label className="text-slate-400 block mb-1">Chọn trang đích</label>
              <select
                value={selectedComponent.events.onClick.pageId || ''}
                onChange={(e) => updateAction('navigate', e.target.value)}
                className="w-full bg-slate-950 border border-slate-700 rounded-lg px-2.5 py-1.5 text-slate-200 outline-none"
              >
                {schema.pages.map((p) => (
                  <option key={p.id} value={p.id}>
                    {p.title} ({p.id})
                  </option>
                ))}
              </select>
            </div>
          )}

          {selectedComponent.events?.onClick?.action === 'payment.openCheckout' && (
            <div className="space-y-2 p-2.5 bg-slate-950 rounded-xl border border-slate-800">
              <span className="text-[10px] text-amber-400 font-semibold block uppercase">Cấu hình Đơn Hàng</span>
              <div>
                <label className="text-slate-400 block text-[11px] mb-0.5">Số tiền (VND)</label>
                <input
                  type="number"
                  value={selectedComponent.events.onClick.params?.amount || 75000}
                  onChange={(e) =>
                    updateAction('native_action', 'payment.openCheckout', {
                      ...selectedComponent.events?.onClick?.params,
                      amount: Number(e.target.value),
                    })
                  }
                  className="w-full bg-slate-900 border border-slate-700 rounded px-2 py-1 text-slate-200 outline-none"
                />
              </div>
              <div>
                <label className="text-slate-400 block text-[11px] mb-0.5">Mô tả thanh toán</label>
                <input
                  type="text"
                  value={selectedComponent.events.onClick.params?.description || ''}
                  onChange={(e) =>
                    updateAction('native_action', 'payment.openCheckout', {
                      ...selectedComponent.events?.onClick?.params,
                      description: e.target.value,
                    })
                  }
                  className="w-full bg-slate-900 border border-slate-700 rounded px-2 py-1 text-slate-200 outline-none"
                />
              </div>
            </div>
          )}
        </div>
      )}

      {selectedComponent.type === 'container' && (
        <div className="space-y-3">
          <div>
            <label className="text-slate-400 block mb-1">Padding viền (px)</label>
            <input
              type="number"
              value={props.padding || 12}
              onChange={(e) => updateProp('padding', Number(e.target.value))}
              className="w-full bg-slate-950 border border-slate-700 rounded-lg px-2.5 py-1.5 text-slate-200 outline-none"
            />
          </div>
          <div>
            <label className="text-slate-400 block mb-1">Màu nền khối</label>
            <div className="flex items-center gap-2">
              <input
                type="color"
                value={props.backgroundColor || '#1E293B'}
                onChange={(e) => updateProp('backgroundColor', e.target.value)}
                className="w-7 h-7 rounded border-none cursor-pointer bg-transparent"
              />
              <span className="font-mono text-slate-300">{props.backgroundColor || '#1E293B'}</span>
            </div>
          </div>
          <div>
            <label className="text-slate-400 block mb-1">Bo góc (px)</label>
            <input
              type="number"
              value={props.borderRadius || 12}
              onChange={(e) => updateProp('borderRadius', Number(e.target.value))}
              className="w-full bg-slate-950 border border-slate-700 rounded-lg px-2.5 py-1.5 text-slate-200 outline-none"
            />
          </div>
        </div>
      )}

      {selectedComponent.type === 'product_list' && (
        <div className="space-y-2">
          <label className="text-slate-400 block font-semibold">Danh sách sản phẩm ({props.items?.length || 0})</label>
          <div className="space-y-2 max-h-52 overflow-y-auto pr-1">
            {props.items?.map((item: any, idx: number) => (
              <div key={idx} className="p-2 bg-slate-950 rounded-lg border border-slate-800 text-[11px] space-y-1">
                <input
                  type="text"
                  value={item.title}
                  onChange={(e) => {
                    const next = [...props.items];
                    next[idx].title = e.target.value;
                    updateProp('items', next);
                  }}
                  placeholder="Tên sản phẩm"
                  className="w-full bg-slate-900 border border-slate-700 rounded px-1.5 py-1 text-slate-200"
                />
                <input
                  type="number"
                  value={item.price}
                  onChange={(e) => {
                    const next = [...props.items];
                    next[idx].price = Number(e.target.value);
                    updateProp('items', next);
                  }}
                  placeholder="Giá bán"
                  className="w-full bg-slate-900 border border-slate-700 rounded px-1.5 py-1 text-amber-400"
                />
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
};
