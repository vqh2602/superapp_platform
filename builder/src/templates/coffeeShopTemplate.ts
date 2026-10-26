import { MiniAppEntity, MiniAppSchema } from '../types';

export const coffeeShopSchema: MiniAppSchema = {
  schemaVersion: 1,
  theme: {
    primaryColor: '#D97706',
    backgroundColor: '#0F172A',
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
            height: 150,
            borderRadius: 14,
          },
        },
        {
          id: 'welcome',
          type: 'text',
          props: {
            value: 'The Coffee House - Cà Phê Nguyên Bản',
            variant: 'h2',
            color: '#F8FAFC',
          },
        },
        {
          id: 'sub_text',
          type: 'text',
          props: {
            value: 'Hạt Arabica & Robusta rang mộc thơm lừng, giao nhanh 15 phút.',
            variant: 'subtitle',
            color: '#94A3B8',
          },
        },
        {
          id: 'menu_header',
          type: 'text',
          props: {
            value: 'MENU ĐỒ UỐNG ĐẶC BIỆT',
            variant: 'h3',
            color: '#F59E0B',
          },
        },
        {
          id: 'products',
          type: 'product_list',
          props: {
            items: [
              {
                id: 'cf_01',
                title: 'Cà Phê Sữa Đá Sài Gòn',
                price: 35000,
                desc: 'Đậm đà phong vị Việt Nam',
                image: 'https://images.unsplash.com/photo-1517701604599-bb29b565090c?auto=format&fit=crop&w=150&q=80',
              },
              {
                id: 'cf_02',
                title: 'Bạc Xỉu Sữa Dừa Tuyết',
                price: 45000,
                desc: 'Béo ngậy thơm ngọt mát lạnh',
                image: 'https://images.unsplash.com/photo-1541167760496-1628856ab772?auto=format&fit=crop&w=150&q=80',
              },
              {
                id: 'cf_03',
                title: 'Trà Oolong Đào Cam Sả',
                price: 52000,
                desc: 'Thanh lọc cơ thể, miếng đào giòn tan',
                image: 'https://images.unsplash.com/photo-1576092768241-dec231879fc3?auto=format&fit=crop&w=150&q=80',
              },
            ],
          },
        },
        {
          id: 'actions_container',
          type: 'container',
          props: {
            padding: 12,
            backgroundColor: '#1E293B',
            borderRadius: 12,
          },
          children: [
            {
              id: 'scan_qr_btn',
              type: 'button',
              props: {
                text: '📷 Quét QR Nhận Voucher 20%',
                variant: 'outline',
              },
              events: {
                onClick: {
                  type: 'native_action',
                  action: 'device.scanQRCode',
                  params: {},
                },
              },
            },
            {
              id: 'fast_checkout_btn',
              type: 'button',
              props: {
                text: '⚡ Đặt Nhanh Combo Sáng (75.000đ)',
                variant: 'primary',
              },
              events: {
                onClick: {
                  type: 'native_action',
                  action: 'payment.openCheckout',
                  params: {
                    amount: 75000,
                    description: 'Combo Cà Phê + Bánh Croissant Sáng',
                    currency: 'VND',
                  },
                },
              },
            },
            {
              id: 'about_btn',
              type: 'button',
              props: {
                text: '📖 Tìm Hiểu Câu Chuyện Quán',
                variant: 'secondary',
              },
              events: {
                onClick: {
                  type: 'navigate',
                  pageId: 'about',
                },
              },
            },
          ],
        },
      ],
    },
    {
      id: 'about',
      title: 'Giới Thiệu Quán',
      components: [
        {
          id: 'about_title',
          type: 'text',
          props: {
            value: 'Hành Trình Tách Cà Phê Đậm Vị',
            variant: 'h2',
            color: '#F59E0B',
          },
        },
        {
          id: 'about_story',
          type: 'text',
          props: {
            value:
              'Khởi đầu từ những đồi cà phê bạt ngàn tại Cầu Đất (Đà Lạt), The Coffee House cam kết chỉ sử dụng hạt cà phê hái chín 100% kết hợp bí quyết rang mộc thủ công nhằm giữ trọn vẹn hương hoa cỏ tự nhiên và hậu vị ngọt sâu.',
            variant: 'body',
            color: '#E2E8F0',
          },
        },
        {
          id: 'back_home_btn',
          type: 'button',
          props: {
            text: '⬅️ Quay lại Menu',
            variant: 'outline',
          },
          events: {
            onClick: {
              type: 'navigate',
              pageId: 'home',
            },
          },
        },
      ],
    },
  ],
};

export const defaultCoffeeShopApp: Omit<MiniAppEntity, 'createdAt' | 'updatedAt'> = {
  id: 'coffee_shop',
  name: 'The Coffee House',
  description: 'Đặt cà phê nguyên chất rang mộc & nhận ưu đãi giao nhanh trong 15 phút.',
  icon: 'coffee',
  category: 'Food & Beverage',
  tenantId: 'tenant_001',
  runtimeType: 'schema',
  status: 'DRAFT',
  activePublishedVersion: null,
  entryUrl: null,
  isAsset: false,
  capabilities: [
    'payment.openCheckout',
    'device.scanQRCode',
    'device.getLocation',
    'navigation.close',
    'user.getProfile',
  ],
  draftSchema: coffeeShopSchema,
};
