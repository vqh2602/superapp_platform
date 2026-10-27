export const sampleSchemas: Record<
  string,
  {
    name: string;
    description: string;
    icon: string;
    category: string;
    capabilities: string[];
    schema: Record<string, any>;
  }
> = {
  coffee_shop: {
    name: 'The Coffee House',
    description: 'Cà phê nguyên chất rang mộc & giao nhanh 15 phút.',
    icon: 'coffee',
    category: 'Food & Beverage',
    capabilities: [
      'payment.createOrder',
      'payment.openCheckout',
      'device.scanQRCode',
      'navigation.close',
      'user.getProfile',
    ],
    schema: {
      schemaVersion: 1,
      theme: { primaryColor: '#D97706', backgroundColor: '#F8FAFC' },
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
                alt: 'Coffee Banner',
                height: 160,
                borderRadius: 14,
              },
            },
            {
              id: 'welcome',
              type: 'text',
              props: {
                value: 'The Coffee House - Cà Phê Rang Mộc',
                variant: 'h2',
                color: '#1E293B',
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
                    desc: 'Cà phê Robusta Đắk Lắk hảo hạng pha phin',
                    image: 'https://images.unsplash.com/photo-1517701604599-bb29b565090c?auto=format&fit=crop&w=150&q=80',
                  },
                  {
                    id: 'cf_02',
                    title: 'Bạc Xỉu Sữa Dừa 3 Tầng',
                    price: 42000,
                    desc: 'Hương vị ngọt béo bùi ngậy quyến rũ',
                    image: 'https://images.unsplash.com/photo-1541167760496-1628856ab772?auto=format&fit=crop&w=150&q=80',
                  },
                ],
              },
            },
            {
              id: 'actions',
              type: 'container',
              props: { padding: 12, backgroundColor: '#FFFFFF', borderRadius: 12 },
              children: [
                {
                  id: 'scan_btn',
                  type: 'button',
                  props: { label: 'Quét mã QR bàn thanh toán', variant: 'outline', icon: 'qr' },
                  events: { onClick: { type: 'native_action', action: 'device.scanQRCode' } },
                },
                {
                  id: 'checkout_btn',
                  type: 'button',
                  props: { label: 'Đặt Combo Cà Phê + Bánh (75.000 ₫)', variant: 'primary', icon: 'cart' },
                  events: {
                    onClick: {
                      type: 'native_action',
                      action: 'payment.openCheckout',
                      params: { amount: 75000, description: 'Combo Cà Phê Sáng' },
                    },
                  },
                },
              ],
            },
          ],
        },
      ],
    },
  },
  shopee: {
    name: 'Shopee: Mua Sắm Online',
    description: 'Sàn thương mại điện tử hàng đầu với triệu ưu đãi',
    icon: 'shopping',
    category: 'Shopping',
    capabilities: [
      'user.getBasicInfo',
      'navigation.close',
      'payment.createOrder',
      'payment.openCheckout',
      'device.scanQRCode',
    ],
    schema: {
      schemaVersion: 1,
      theme: { primaryColor: '#EE4D2D', backgroundColor: '#F8FAFC' },
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
              props: { padding: 12, backgroundColor: '#FFFFFF', borderRadius: 12 },
              children: [
                {
                  id: 'voucher_scan',
                  type: 'button',
                  props: { label: 'Quét QR Mã Giảm Giá Độc Quyền 50K', variant: 'outline', icon: 'qr' },
                  events: { onClick: { type: 'native_action', action: 'device.scanQRCode' } },
                },
                {
                  id: 'buy_combo_btn',
                  type: 'button',
                  props: { label: 'Mua Nhanh Bộ Sạc GaN Siêu Tốc (490.000 ₫)', variant: 'primary', icon: 'cart' },
                  events: {
                    onClick: {
                      type: 'native_action',
                      action: 'payment.openCheckout',
                      params: { amount: 490000, description: 'Shopee Mall - Sạc nhanh GaN 65W' },
                    },
                  },
                },
              ],
            },
          ],
        },
      ],
    },
  },
  tiktok: {
    name: 'TikTok-Global Video Community',
    description: 'Short-Form Video Platform & Creative Community',
    icon: 'video',
    category: 'Photo & Video',
    capabilities: [
      'user.getBasicInfo',
      'navigation.close',
      'payment.createOrder',
      'payment.openCheckout',
      'device.scanQRCode',
      'navigation.openNativePage',
    ],
    schema: {
      schemaVersion: 1,
      theme: { primaryColor: '#FE2C55', backgroundColor: '#0F172A' },
      pages: [
        {
          id: 'home',
          title: '🎵 TikTok Video & Live Hub',
          components: [
            {
              id: 'tiktok_banner',
              type: 'image',
              props: {
                src: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?auto=format&fit=crop&w=800&q=80',
                alt: 'TikTok Trending Live',
                height: 160,
                borderRadius: 14,
              },
            },
            {
              id: 'tt_title',
              type: 'text',
              props: { value: 'TikTok - Sáng Tạo & Xu Hướng Toàn Cầu', variant: 'h2', color: '#FFFFFF' },
            },
            {
              id: 'tt_products',
              type: 'product_list',
              props: {
                items: [
                  {
                    id: 'tt_01',
                    title: 'Micro Thu Âm Cài Áo Không Dây V2',
                    price: 590000,
                    desc: 'Khử tiếng ồn AI, khoảng cách thu 20m',
                    image: 'https://images.unsplash.com/photo-1590658268037-6bf12165a8df?auto=format&fit=crop&w=150&q=80',
                  },
                ],
              },
            },
            {
              id: 'tt_actions',
              type: 'container',
              props: { padding: 12, backgroundColor: '#1E293B', borderRadius: 12 },
              children: [
                {
                  id: 'donate_btn',
                  type: 'button',
                  props: { label: 'Tặng Quà Live Idol (50.000 ₫)', variant: 'primary', icon: 'cart' },
                  events: {
                    onClick: {
                      type: 'native_action',
                      action: 'payment.openCheckout',
                      params: { amount: 50000, description: 'TikTok Live - Quà tặng Kim Cương' },
                    },
                  },
                },
                {
                  id: 'scan_creator_btn',
                  type: 'button',
                  props: { label: 'Quét Mã QR Kết Bạn Thần Tượng', variant: 'outline', icon: 'qr' },
                  events: { onClick: { type: 'native_action', action: 'device.scanQRCode' } },
                },
              ],
            },
          ],
        },
      ],
    },
  },
  viettel_tammi: {
    name: 'Viettel Tammi',
    description: 'Dịch vụ viễn thông, số hoá tiện ích thông minh',
    icon: 'utilities',
    category: 'Utilities',
    capabilities: [
      'user.getBasicInfo',
      'user.getProfile',
      'navigation.close',
      'payment.createOrder',
      'payment.openCheckout',
      'device.scanQRCode',
    ],
    schema: {
      schemaVersion: 1,
      theme: { primaryColor: '#ED1C24', backgroundColor: '#F8FAFC' },
      pages: [
        {
          id: 'home',
          title: '📶 Viettel Tammi - Dịch Vụ Viễn Thông',
          components: [
            {
              id: 'vt_banner',
              type: 'image',
              props: {
                src: 'https://images.unsplash.com/photo-1544717305-2782549b5136?auto=format&fit=crop&w=800&q=80',
                alt: 'Viettel 5G',
                height: 150,
                borderRadius: 14,
              },
            },
            {
              id: 'vt_balance_card',
              type: 'container',
              props: { padding: 14, backgroundColor: '#FEF2F2', borderRadius: 12, border: true },
              children: [
                {
                  id: 'sim_info',
                  type: 'text',
                  props: { value: 'Thuê Bao: 0984.888.xxx (Chính chủ VIP)', variant: 'h3', color: '#991B1B' },
                },
                {
                  id: 'sim_balance',
                  type: 'text',
                  props: { value: 'Số dư: 145.000 ₫ • Data 4G: 18.2 GB', variant: 'body', color: '#DC2626' },
                },
              ],
            },
            {
              id: 'vt_actions',
              type: 'container',
              props: { padding: 12, backgroundColor: '#FFFFFF', borderRadius: 12 },
              children: [
                {
                  id: 'scan_card_btn',
                  type: 'button',
                  props: { label: 'Quét Mã QR Thẻ Cào Viettel', variant: 'outline', icon: 'qr' },
                  events: { onClick: { type: 'native_action', action: 'device.scanQRCode' } },
                },
                {
                  id: 'buy_st150k_btn',
                  type: 'button',
                  props: { label: 'Đăng Ký Gói ST150K (150.000 ₫)', variant: 'primary', icon: 'cart' },
                  events: {
                    onClick: {
                      type: 'native_action',
                      action: 'payment.openCheckout',
                      params: { amount: 150000, description: 'Viettel - Gói Data ST150K' },
                    },
                  },
                },
              ],
            },
          ],
        },
      ],
    },
  },
  free_fire: {
    name: 'Free Fire MAX',
    description: 'Game bắn súng sinh tồn chiến thuật thời gian thực',
    icon: 'games',
    category: 'Games',
    capabilities: [
      'user.getBasicInfo',
      'navigation.close',
      'payment.createOrder',
      'payment.openCheckout',
      'device.scanQRCode',
    ],
    schema: {
      schemaVersion: 1,
      theme: { primaryColor: '#F59E0B', backgroundColor: '#0F172A' },
      pages: [
        {
          id: 'home',
          title: '🎮 Garena Free Fire MAX',
          components: [
            {
              id: 'ff_banner',
              type: 'image',
              props: {
                src: 'https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&w=800&q=80',
                alt: 'Free Fire MAX',
                height: 160,
                borderRadius: 14,
              },
            },
            {
              id: 'ff_title',
              type: 'text',
              props: { value: 'Free Fire MAX - Đỉnh Cao Sinh Tồn', variant: 'h2', color: '#F59E0B' },
            },
            {
              id: 'ff_actions',
              type: 'container',
              props: { padding: 12, backgroundColor: '#1E293B', borderRadius: 12 },
              children: [
                {
                  id: 'topup_btn',
                  type: 'button',
                  props: { label: 'Nạp 530 Kim Cương (100.000 ₫)', variant: 'primary', icon: 'cart' },
                  events: {
                    onClick: {
                      type: 'native_action',
                      action: 'payment.openCheckout',
                      params: { amount: 100000, description: 'Free Fire - Nạp 530 Kim Cương' },
                    },
                  },
                },
                {
                  id: 'giftcode_btn',
                  type: 'button',
                  props: { label: 'Quét QR Nhận Giftcode Sự Kiện', variant: 'outline', icon: 'qr' },
                  events: { onClick: { type: 'native_action', action: 'device.scanQRCode' } },
                },
              ],
            },
          ],
        },
      ],
    },
  },
  capcut: {
    name: 'CapCut - Photo & Video Editor',
    description: 'Công cụ sáng tạo và chỉnh sửa video hiệu ứng đỉnh cao',
    icon: 'video',
    category: 'Photo & Video',
    capabilities: [
      'user.getBasicInfo',
      'navigation.close',
      'payment.createOrder',
      'payment.openCheckout',
      'device.pickImage',
    ],
    schema: {
      schemaVersion: 1,
      theme: { primaryColor: '#06B6D4', backgroundColor: '#18181B' },
      pages: [
        {
          id: 'home',
          title: '✂️ CapCut Creative Video Studio',
          components: [
            {
              id: 'cc_banner',
              type: 'image',
              props: {
                src: 'https://images.unsplash.com/photo-1574717024653-61fd2cf4d44d?auto=format&fit=crop&w=800&q=80',
                alt: 'CapCut Video',
                height: 160,
                borderRadius: 14,
              },
            },
            {
              id: 'cc_title',
              type: 'text',
              props: { value: 'CapCut - Sáng Tạo Video Chuyên Nghiệp', variant: 'h2', color: '#FFFFFF' },
            },
            {
              id: 'cc_actions',
              type: 'container',
              props: { padding: 12, backgroundColor: '#27272A', borderRadius: 12 },
              children: [
                {
                  id: 'pick_img_btn',
                  type: 'button',
                  props: { label: 'Chọn Ảnh Từ Thư Viện Để Tạo Clip Mẫu', variant: 'outline', icon: 'sparkles' },
                  events: { onClick: { type: 'native_action', action: 'device.pickImage' } },
                },
                {
                  id: 'buy_pro_btn',
                  type: 'button',
                  props: { label: 'Nâng Cấp CapCut Pro 1 Năm (599.000 ₫)', variant: 'primary', icon: 'cart' },
                  events: {
                    onClick: {
                      type: 'native_action',
                      action: 'payment.openCheckout',
                      params: { amount: 599000, description: 'CapCut Pro 1 Năm' },
                    },
                  },
                },
              ],
            },
          ],
        },
      ],
    },
  },
  messenger: {
    name: 'Messenger',
    description: 'Text, audio and video calls with friends and groups',
    icon: 'social',
    category: 'Social Network',
    capabilities: [
      'user.getBasicInfo',
      'navigation.close',
      'payment.createOrder',
      'payment.openCheckout',
      'navigation.openNativePage',
    ],
    schema: {
      schemaVersion: 1,
      theme: { primaryColor: '#0084FF', backgroundColor: '#F8FAFC' },
      pages: [
        {
          id: 'home',
          title: '💬 Messenger Community & Chat',
          components: [
            {
              id: 'msg_banner',
              type: 'image',
              props: {
                src: 'https://images.unsplash.com/photo-1577563908411-5077b6dc7624?auto=format&fit=crop&w=800&q=80',
                alt: 'Messenger Friends',
                height: 150,
                borderRadius: 14,
              },
            },
            {
              id: 'msg_title',
              type: 'text',
              props: { value: 'Messenger - Trò Chuyện & Chia Sẻ', variant: 'h2', color: '#0084FF' },
            },
            {
              id: 'msg_actions',
              type: 'container',
              props: { padding: 12, backgroundColor: '#FFFFFF', borderRadius: 12 },
              children: [
                {
                  id: 'lixi_btn',
                  type: 'button',
                  props: { label: 'Chuyển Tiền Lì Xì Bạn Bè (50.000 ₫)', variant: 'primary', icon: 'cart' },
                  events: {
                    onClick: {
                      type: 'native_action',
                      action: 'payment.openCheckout',
                      params: { amount: 50000, description: 'Messenger - Lì xì bạn bè' },
                    },
                  },
                },
                {
                  id: 'open_form_btn',
                  type: 'button',
                  props: { label: 'Mở Form Gửi Ý Kiến Đóng Góp', variant: 'outline', icon: 'message' },
                  events: {
                    onClick: {
                      type: 'native_action',
                      action: 'navigation.openNativePage',
                      params: { page: 'form' },
                    },
                  },
                },
              ],
            },
          ],
        },
      ],
    },
  },
};
