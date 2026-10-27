import { MiniAppEntity, MiniAppSchema } from '../types';

export const shopeeSchema: MiniAppSchema = {
  schemaVersion: 1,
  theme: {
    primaryColor: '#EE4D2D',
    backgroundColor: '#F8FAFC',
  },
  pages: [
    {
      id: 'home',
      title: '🛍️ Shopee Super Mall',
      components: [
        {
          id: 'shopee_banner',
          type: 'image',
          props: {
            src: 'https://images.unsplash.com/photo-1607082348824-0a96f2a4b9da?auto=format&fit=crop&w=800&q=80',
            alt: 'Shopee Mega Sale',
            height: 160,
            borderRadius: 14,
          },
        },
        {
          id: 'shopee_title',
          type: 'text',
          props: {
            value: 'Shopee Mall - Hàng Chính Hãng 100%',
            variant: 'h2',
            color: '#EE4D2D',
          },
        },
        {
          id: 'shopee_subtitle',
          type: 'text',
          props: {
            value: 'Freeship đơn từ 0Đ • Giảm đến 50% hàng công nghệ & phụ kiện cao cấp.',
            variant: 'subtitle',
          },
        },
        {
          id: 'flash_sale_header',
          type: 'text',
          props: {
            value: '🔥 FLASH SALE ĐANG DIỄN RA',
            variant: 'h3',
            color: '#EE4D2D',
          },
        },
        {
          id: 'shopee_products',
          type: 'product_list',
          props: {
            items: [
              {
                id: 'sp_01',
                title: 'Tai Nghe Không Dây Sony WH-1000XM5',
                price: 6890000,
                desc: 'Chống ồn chủ động đỉnh cao, pin 30 giờ',
                image: 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?auto=format&fit=crop&w=150&q=80',
              },
              {
                id: 'sp_02',
                title: 'Bàn Phím Cơ Không Dây RGB Gaming',
                price: 1850000,
                desc: 'Gateron Pro Switch, kết nối 3 chế độ',
                image: 'https://images.unsplash.com/photo-1587829741301-dc798b83add3?auto=format&fit=crop&w=150&q=80',
              },
              {
                id: 'sp_03',
                title: 'Củ Sạc Nhanh GaN 65W 3 Cổng Type-C',
                price: 490000,
                desc: 'Công nghệ GaN siêu nhỏ gọn, sạc Laptop & Phone',
                image: 'https://images.unsplash.com/photo-1583863788434-e58a36330cf0?auto=format&fit=crop&w=150&q=80',
              },
            ],
          },
        },
        {
          id: 'shopee_actions',
          type: 'container',
          props: {
            padding: 12,
            backgroundColor: '#FFFFFF',
            borderRadius: 12,
          },
          children: [
            {
              id: 'voucher_scan',
              type: 'button',
              props: {
                label: 'Quét QR Mã Giảm Giá Độc Quyền 50K',
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
              id: 'buy_combo_btn',
              type: 'button',
              props: {
                label: 'Mua Nhanh Bộ Sạc GaN Siêu Tốc (490.000 ₫)',
                variant: 'primary',
                icon: 'cart',
              },
              events: {
                onClick: {
                  type: 'native_action',
                  action: 'payment.openCheckout',
                  params: {
                    amount: 490000,
                    description: 'Shopee Mall - Củ sạc nhanh GaN 65W 3 Cổng',
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

export const defaultShopeeApp: Omit<MiniAppEntity, 'createdAt' | 'updatedAt'> = {
  id: 'shopee',
  name: 'Shopee: Mua Sắm Online',
  description: 'Sàn thương mại điện tử hàng đầu với triệu ưu đãi',
  icon: 'shopping',
  category: 'Shopping',
  tenantId: 'tenant_shopee',
  runtimeType: 'schema',
  status: 'DRAFT',
  activePublishedVersion: null,
  entryUrl: null,
  isAsset: false,
  capabilities: [
    'user.getBasicInfo',
    'navigation.close',
    'payment.createOrder',
    'payment.openCheckout',
    'device.scanQRCode',
  ],
  draftSchema: shopeeSchema,
};
