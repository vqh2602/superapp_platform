import React, { useState } from 'react';
import { MiniAppSchema, ComponentDefinition, ComponentAction } from '../types';
import {
  Wifi,
  Battery,
  ChevronLeft,
  X,
  CreditCard,
  QrCode,
  MapPin,
  CheckCircle,
  ExternalLink,
} from 'lucide-react';

interface MobileSimulatorProps {
  schema: MiniAppSchema;
  appName: string;
  selectedComponentId?: string | null;
  onSelectComponent?: (id: string) => void;
}

export const MobileSimulator: React.FC<MobileSimulatorProps> = ({
  schema,
  appName,
  selectedComponentId,
  onSelectComponent,
}) => {
  const [activePageId, setActivePageId] = useState<string>(
    schema.pages[0]?.id || 'home'
  );
  const [toastMessage, setToastMessage] = useState<string | null>(null);

  // Keep active page valid if schema pages change
  const currentPage =
    schema.pages.find((p) => p.id === activePageId) || schema.pages[0];

  const showToast = (msg: string) => {
    setToastMessage(msg);
    setTimeout(() => setToastMessage(null), 3500);
  };

  const handleAction = (action?: ComponentAction) => {
    if (!action) return;

    if (action.type === 'navigate' && action.pageId) {
      setActivePageId(action.pageId);
      return;
    }

    if (action.type === 'native_action') {
      if (action.action === 'payment.openCheckout') {
        const amount = action.params?.amount?.toLocaleString('vi-VN') || '75.000';
        showToast(`💳 [Bridge Simulation] Thanh toán ${amount}đ: "${action.params?.description || 'Đơn hàng'}" thành công!`);
      } else if (action.action === 'device.scanQRCode') {
        showToast(`📷 [Bridge Simulation] Quét mã QR thành công: "PROMO_COFFEE_2026"`);
      } else if (action.action === 'navigation.close') {
        showToast(`🚪 [Bridge Simulation] Đóng Mini App -> Quay lại Master App Home`);
      } else {
        showToast(`⚡ [Bridge Simulation] Gọi Native Action: ${action.action}`);
      }
    }
  };

  const renderComponent = (comp: ComponentDefinition): React.ReactNode => {
    const isSelected = selectedComponentId === comp.id;
    const highlightClasses = isSelected
      ? 'ring-2 ring-amber-400 ring-offset-2 ring-offset-slate-900 rounded-lg'
      : '';

    const clickWrapper = (content: React.ReactNode) => (
      <div
        key={comp.id}
        onClick={(e) => {
          e.stopPropagation();
          onSelectComponent?.(comp.id);
        }}
        className={`relative transition-all cursor-pointer ${highlightClasses}`}
      >
        {isSelected && (
          <span className="absolute -top-2.5 right-2 bg-amber-500 text-slate-950 text-[10px] font-bold px-1.5 py-0.2 rounded shadow">
            {comp.type}
          </span>
        )}
        {content}
      </div>
    );

    switch (comp.type) {
      case 'text': {
        const variant = comp.props.variant || 'body';
        const color = comp.props.color || '#E2E8F0';
        let styleClass = 'text-sm';
        if (variant === 'h1') styleClass = 'text-xl font-bold tracking-tight';
        if (variant === 'h2') styleClass = 'text-lg font-bold';
        if (variant === 'h3') styleClass = 'text-base font-semibold';
        if (variant === 'subtitle') styleClass = 'text-xs text-slate-400';

        return clickWrapper(
          <p className={styleClass} style={{ color }}>
            {comp.props.value || 'Văn bản mẫu'}
          </p>
        );
      }

      case 'image': {
        return clickWrapper(
          <div
            className="w-full overflow-hidden shadow-sm"
            style={{
              height: `${comp.props.height || 140}px`,
              borderRadius: `${comp.props.borderRadius || 10}px`,
            }}
          >
            <img
              src={comp.props.src || 'https://via.placeholder.com/600x300'}
              alt={comp.props.alt || ''}
              className="w-full h-full object-cover"
            />
          </div>
        );
      }

      case 'button': {
        const variant = comp.props.variant || 'primary';
        let btnStyle =
          'bg-gradient-to-r from-amber-500 to-amber-600 text-slate-950 font-semibold shadow-md active:scale-98';
        if (variant === 'secondary') {
          btnStyle = 'bg-slate-700 hover:bg-slate-600 text-slate-100 font-medium';
        } else if (variant === 'outline') {
          btnStyle =
            'border border-amber-500/70 text-amber-400 hover:bg-amber-500/10 font-medium';
        }

        return clickWrapper(
          <button
            onClick={() => handleAction(comp.events?.onClick)}
            className={`w-full py-2.5 px-4 rounded-xl text-xs transition-all flex items-center justify-center gap-1.5 ${btnStyle}`}
          >
            {comp.props.text || 'Nhấn vào đây'}
          </button>
        );
      }

      case 'container': {
        return clickWrapper(
          <div
            className="flex flex-col gap-2.5 border border-slate-700/60"
            style={{
              padding: `${comp.props.padding || 12}px`,
              backgroundColor: comp.props.backgroundColor || '#1E293B',
              borderRadius: `${comp.props.borderRadius || 12}px`,
            }}
          >
            {comp.children?.map((child) => renderComponent(child))}
          </div>
        );
      }

      case 'product_list': {
        const items = comp.props.items || [];
        return clickWrapper(
          <div className="flex flex-col gap-2.5">
            {items.map((item: any, idx: number) => (
              <div
                key={item.id || idx}
                className="flex items-center gap-3 p-2.5 rounded-xl bg-slate-800/80 border border-slate-700/70 hover:border-amber-500/50 transition-all shadow-sm"
              >
                {item.image && (
                  <img
                    src={item.image}
                    alt={item.title}
                    className="w-16 h-16 rounded-lg object-cover flex-shrink-0"
                  />
                )}
                <div className="flex-1 min-w-0">
                  <h4 className="text-xs font-bold text-slate-100 truncate">
                    {item.title}
                  </h4>
                  <p className="text-[11px] text-slate-400 line-clamp-1 mt-0.5">
                    {item.desc}
                  </p>
                  <p className="text-xs font-semibold text-amber-400 mt-1">
                    {Number(item.price || 0).toLocaleString('vi-VN')} đ
                  </p>
                </div>
                <button
                  onClick={() =>
                    handleAction({
                      type: 'native_action',
                      action: 'payment.openCheckout',
                      params: {
                        amount: item.price,
                        description: `Mua: ${item.title}`,
                        currency: 'VND',
                      },
                    })
                  }
                  className="px-2.5 py-1.5 bg-amber-500/20 text-amber-400 hover:bg-amber-500 hover:text-slate-950 rounded-lg text-[11px] font-bold transition-all"
                >
                  Mua
                </button>
              </div>
            ))}
          </div>
        );
      }

      case 'input': {
        return clickWrapper(
          <div className="flex flex-col gap-1 text-left">
            {comp.props.label && (
              <label className="text-[11px] text-slate-400 font-medium">
                {comp.props.label}
              </label>
            )}
            <input
              type="text"
              placeholder={comp.props.placeholder || 'Nhập dữ liệu...'}
              readOnly
              className="w-full px-3 py-2 text-xs bg-slate-900 border border-slate-700 rounded-lg text-slate-200 placeholder:text-slate-600 focus:outline-none"
            />
          </div>
        );
      }

      default:
        return clickWrapper(
          <div className="p-3 bg-red-900/30 border border-red-500 rounded text-xs text-red-300">
            Unknown component: {comp.type}
          </div>
        );
    }
  };

  return (
    <div className="relative mx-auto w-[320px] h-[640px] bg-slate-950 rounded-[44px] p-3 shadow-2xl border-4 border-slate-700/80 ring-1 ring-slate-800 flex flex-col select-none">
      {/* Top Speaker / Dynamic Island */}
      <div className="absolute top-4 left-1/2 -translate-x-1/2 w-28 h-4 bg-slate-900 rounded-full flex items-center justify-center gap-1 z-30">
        <div className="w-2.5 h-2.5 rounded-full bg-slate-800 border border-slate-700"></div>
        <div className="w-2 h-2 rounded-full bg-blue-900/40"></div>
      </div>

      {/* Screen Container */}
      <div className="relative w-full h-full bg-slate-900 rounded-[34px] overflow-hidden flex flex-col border border-slate-800/80">
        {/* Status Bar */}
        <div className="flex items-center justify-between px-5 pt-3.5 pb-2 text-[11px] font-semibold text-slate-300">
          <span>09:41</span>
          <div className="flex items-center gap-1.5">
            <Wifi className="w-3 h-3 text-slate-400" />
            <Battery className="w-3.5 h-3.5 text-slate-400" />
          </div>
        </div>

        {/* Mini App Header (Flutter Master App Chrome) */}
        <div className="flex items-center justify-between px-3.5 py-2 bg-slate-800/90 backdrop-blur border-b border-slate-700/50">
          <div className="flex items-center gap-1.5">
            {activePageId !== schema.pages[0]?.id && (
              <button
                onClick={() => setActivePageId(schema.pages[0]?.id || 'home')}
                className="text-slate-400 hover:text-white"
              >
                <ChevronLeft className="w-4 h-4" />
              </button>
            )}
            <div>
              <h3 className="text-xs font-bold text-slate-100 truncate max-w-[170px]">
                {currentPage?.title || appName}
              </h3>
              <p className="text-[9px] text-amber-400 font-medium">Mini App Live Simulator</p>
            </div>
          </div>
          <button
            onClick={() => handleAction({ type: 'native_action', action: 'navigation.close' })}
            className="w-6 h-6 rounded-full bg-slate-700/80 hover:bg-slate-700 flex items-center justify-center text-slate-300"
          >
            <X className="w-3.5 h-3.5" />
          </button>
        </div>

        {/* Mini App Scrollable Viewport */}
        <div className="flex-1 overflow-y-auto p-3.5 space-y-3 bg-slate-900/95">
          {currentPage ? (
            currentPage.components.map((c) => renderComponent(c))
          ) : (
            <div className="text-center py-10 text-xs text-slate-500">
              Chưa có trang nào được chọn
            </div>
          )}
        </div>

        {/* Toast Notification Simulation */}
        {toastMessage && (
          <div className="absolute bottom-6 left-3 right-3 bg-amber-500 text-slate-950 p-2.5 rounded-xl shadow-lg text-[11px] font-semibold flex items-center gap-2 animate-bounce z-40">
            <CheckCircle className="w-4 h-4 flex-shrink-0" />
            <span className="flex-1 leading-snug">{toastMessage}</span>
          </div>
        )}

        {/* Bottom Home Indicator */}
        <div className="w-28 h-1 bg-slate-700 rounded-full mx-auto my-1.5 flex-shrink-0"></div>
      </div>
    </div>
  );
};
