import React, { useState, useEffect } from 'react';
import { MiniAppSchema } from './types';
import { SchemaRenderer } from './SchemaRenderer';
import { Loader2, AlertCircle } from 'lucide-react';

declare global {
  interface Window {
    __MINIAPP_SCHEMA__?: MiniAppSchema;
    __MINIAPP_APP_ID__?: string;
  }
}

const defaultCoffeeShopSchema: MiniAppSchema = {
  schemaVersion: 1,
  theme: {
    primaryColor: '#D97706',
    backgroundColor: '#F8FAFC',
  },
  pages: [
    {
      id: 'home',
      title: '☕ The Coffee House',
      components: [
        {
          id: 'banner',
          type: 'image',
          props: {
            src: 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?auto=format&fit=crop&w=800&q=80',
            alt: 'Coffee House Banner',
            height: 160,
            borderRadius: 14,
          },
        },
        {
          id: 'welcome',
          type: 'text',
          props: {
            value: 'Chào mừng quý khách đến với The Coffee House!',
            variant: 'h2',
            color: '#1E293B',
          },
        },
        {
          id: 'sub_text',
          type: 'text',
          props: {
            value: 'Thưởng thức hương vị cà phê rang xay nguyên chất mỗi ngày.',
            variant: 'subtitle',
          },
        },
        {
          id: 'menu_header',
          type: 'text',
          props: {
            value: 'MENU NỔI BẬT HÔM NAY',
            variant: 'h3',
            color: '#D97706',
          },
        },
        {
          id: 'products',
          type: 'product_list',
          props: {
            items: [
              {
                id: 'cf_01',
                title: 'Cà Phê Sữa Đá Đậm Đà',
                price: 35000,
                desc: 'Cà phê Robusta Đắk Lắk hảo hạng',
                image: 'https://images.unsplash.com/photo-1517701604599-bb29b565090c?auto=format&fit=crop&w=150&q=80',
              },
              {
                id: 'cf_02',
                title: 'Bạc Xỉu Sữa Tươi 3 Tầng',
                price: 42000,
                desc: 'Hương vị ngọt ngào quyến rũ',
                image: 'https://images.unsplash.com/photo-1541167760496-1628856ab772?auto=format&fit=crop&w=150&q=80',
              },
              {
                id: 'cf_03',
                title: 'Trà Oolong Sen Vàng',
                price: 49000,
                desc: 'Trà olong thanh mát hạt sen giòn',
                image: 'https://images.unsplash.com/photo-1576092768241-dec231879fc3?auto=format&fit=crop&w=150&q=80',
              },
            ],
          },
        },
        {
          id: 'btn_group',
          type: 'container',
          props: {
            padding: 12,
            backgroundColor: '#FFFFFF',
            borderRadius: 12,
          },
          children: [
            {
              id: 'scan_btn',
              type: 'button',
              props: {
                label: 'Quét mã QR bàn thanh toán',
                variant: 'outline',
                icon: 'qr',
              },
              events: {
                onClick: {
                  type: 'native_action',
                  action: 'device.scanQRCode',
                },
              },
            },
            {
              id: 'checkout_btn',
              type: 'button',
              props: {
                label: 'Đặt Combo Nhanh (75.000 ₫)',
                variant: 'primary',
                icon: 'cart',
              },
              events: {
                onClick: {
                  type: 'native_action',
                  action: 'payment.openCheckout',
                  params: {
                    amount: 75000,
                    description: 'Combo Cà Phê + Bánh Ngọt Sáng',
                    currency: 'VND',
                  },
                },
              },
            },
          ],
        },
      ],
    },
  ],
};

export const App: React.FC = () => {
  const [schema, setSchema] = useState<MiniAppSchema | null>(null);
  const [appId, setAppId] = useState<string>('coffee_shop');
  const [loading, setLoading] = useState<boolean>(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    // 1. Check window.__MINIAPP_SCHEMA__
    if (typeof window !== 'undefined' && window.__MINIAPP_SCHEMA__) {
      setSchema(window.__MINIAPP_SCHEMA__);
      if (window.__MINIAPP_APP_ID__) setAppId(window.__MINIAPP_APP_ID__);
      setLoading(false);
      return;
    }

    // 2. Listen to schema loaded event from Flutter Bridge
    const onSchemaEvent = (e: any) => {
      if (e.detail?.schema) {
        setSchema(e.detail.schema);
        if (e.detail.appId) setAppId(e.detail.appId);
        setLoading(false);
      }
    };
    window.addEventListener('miniapp.schema_loaded', onSchemaEvent);

    // 3. Check URL search param and fallback fetch
    const params = new URLSearchParams(window.location.search);
    const targetAppId = params.get('appId') || 'coffee_shop';
    setAppId(targetAppId);

    // Fetch schema from Catalog API
    const catalogBaseUrl = 'http://localhost:3000/api/v1/catalog';
    fetch(`${catalogBaseUrl}/apps/${targetAppId}`)
      .then(async (res) => {
        if (!res.ok) {
          throw new Error(`Catalog API returned HTTP ${res.status}`);
        }
        const data = await res.json();
        if (data.schema) {
          setSchema(data.schema);
        } else {
          setSchema(defaultCoffeeShopSchema);
        }
      })
      .catch((err) => {
        console.warn(`[SchemaRuntime] Failed to fetch remote schema, fallback to default: ${err.message}`);
        setSchema(defaultCoffeeShopSchema);
      })
      .finally(() => {
        setLoading(false);
      });
  }, []);

  if (loading) {
    return (
      <div
        style={{
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          height: '100vh',
          backgroundColor: '#F8FAFC',
          gap: '12px',
          color: '#64748B',
        }}
      >
        <Loader2 size={32} className="spin" color="#2563EB" />
        <p style={{ fontSize: '13px', fontWeight: 600 }}>Đang nạp Schema No-Code...</p>
      </div>
    );
  }

  if (error || !schema) {
    return (
      <div
        style={{
          padding: '30px',
          textAlign: 'center',
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          gap: '12px',
        }}
      >
        <AlertCircle size={40} color="#EF4444" />
        <h3 style={{ margin: 0 }}>Không thể tải Mini App</h3>
        <p style={{ color: '#64748B', fontSize: '13px' }}>{error || 'Dữ liệu schema không hợp lệ.'}</p>
      </div>
    );
  }

  return <SchemaRenderer schema={schema} appId={appId} />;
};
