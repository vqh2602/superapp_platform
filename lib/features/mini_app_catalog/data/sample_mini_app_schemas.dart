/// Sample No-Code Schema definitions for Schema Mini Apps
/// Rendered natively via schema_runtime universal engine.
class SampleMiniAppSchemas {
  static const Map<String, dynamic> shopeeSchema = {
    'schemaVersion': 1,
    'theme': {
      'primaryColor': '#EE4D2D',
      'backgroundColor': '#F8FAFC',
    },
    'pages': [
      {
        'id': 'home',
        'title': '🛍️ Shopee Super Mall',
        'components': [
          {
            'id': 'shopee_banner',
            'type': 'image',
            'props': {
              'src': 'https://images.unsplash.com/photo-1607082348824-0a96f2a4b9da?auto=format&fit=crop&w=800&q=80',
              'alt': 'Shopee Mega Sale',
              'height': 160,
              'borderRadius': 14,
            },
          },
          {
            'id': 'shopee_title',
            'type': 'text',
            'props': {
              'value': 'Shopee Mall - Hàng Chính Hãng 100%',
              'variant': 'h2',
              'color': '#EE4D2D',
            },
          },
          {
            'id': 'shopee_subtitle',
            'type': 'text',
            'props': {
              'value': 'Freeship đơn từ 0Đ • Giảm đến 50% hàng công nghệ & phụ kiện cao cấp.',
              'variant': 'subtitle',
            },
          },
          {
            'id': 'flash_sale_header',
            'type': 'text',
            'props': {
              'value': '🔥 FLASH SALE ĐANG DIỄN RA',
              'variant': 'h3',
              'color': '#EE4D2D',
            },
          },
          {
            'id': 'shopee_products',
            'type': 'product_list',
            'props': {
              'items': [
                {
                  'id': 'sp_01',
                  'title': 'Tai Nghe Không Dây Sony WH-1000XM5',
                  'price': 6890000,
                  'desc': 'Chống ồn chủ động đỉnh cao, pin 30 giờ',
                  'image': 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?auto=format&fit=crop&w=150&q=80',
                },
                {
                  'id': 'sp_02',
                  'title': 'Bàn Phím Cơ Không Dây RGB Gaming',
                  'price': 1850000,
                  'desc': 'Gateron Pro Switch, kết nối 3 chế độ',
                  'image': 'https://images.unsplash.com/photo-1587829741301-dc798b83add3?auto=format&fit=crop&w=150&q=80',
                },
                {
                  'id': 'sp_03',
                  'title': 'Củ Sạc Nhanh GaN 65W 3 Cổng Type-C',
                  'price': 490000,
                  'desc': 'Công nghệ GaN siêu nhỏ gọn, sạc Laptop & Phone',
                  'image': 'https://images.unsplash.com/photo-1583863788434-e58a36330cf0?auto=format&fit=crop&w=150&q=80',
                },
              ],
            },
          },
          {
            'id': 'shopee_actions',
            'type': 'container',
            'props': {
              'padding': 12,
              'backgroundColor': '#FFFFFF',
              'borderRadius': 12,
            },
            'children': [
              {
                'id': 'voucher_scan',
                'type': 'button',
                'props': {
                  'label': 'Quét QR Mã Giảm Giá Độc Quyền 50K',
                  'variant': 'outline',
                  'icon': 'qr',
                },
                'events': {
                  'onClick': {
                    'type': 'native_action',
                    'action': 'device.scanQRCode',
                  },
                },
              },
              {
                'id': 'buy_combo_btn',
                'type': 'button',
                'props': {
                  'label': 'Mua Nhanh Bộ Sạc GaN Siêu Tốc (490.000 ₫)',
                  'variant': 'primary',
                  'icon': 'cart',
                },
                'events': {
                  'onClick': {
                    'type': 'native_action',
                    'action': 'payment.openCheckout',
                    'params': {
                      'amount': 490000,
                      'description': 'Shopee Mall - Củ sạc nhanh GaN 65W 3 Cổng',
                      'currency': 'VND',
                    },
                  },
                },
              },
              {
                'id': 'nav_voucher_btn',
                'type': 'button',
                'props': {
                  'label': 'Xem Kho Voucher & Khuyến Mãi',
                  'variant': 'secondary',
                  'icon': 'arrow',
                },
                'events': {
                  'onClick': {
                    'type': 'navigate',
                    'targetPageId': 'voucher_page',
                  },
                },
              },
            ],
          },
        ],
      },
      {
        'id': 'voucher_page',
        'title': '🎟️ Kho Voucher Shopee',
        'components': [
          {
            'id': 'v_header',
            'type': 'text',
            'props': {
              'value': 'Kho Voucher Của Bạn',
              'variant': 'h2',
              'color': '#EE4D2D',
            },
          },
          {
            'id': 'v_desc',
            'type': 'text',
            'props': {
              'value': 'Mã giảm giá áp dụng tự động khi thanh toán qua SuperApp Native Pay.',
              'variant': 'subtitle',
            },
          },
          {
            'id': 'v_card_1',
            'type': 'container',
            'props': {
              'padding': 14,
              'backgroundColor': '#FFF7ED',
              'borderRadius': 12,
            },
            'children': [
              {
                'id': 'v1_title',
                'type': 'text',
                'props': {
                  'value': 'GIẢM 50.000 ₫ ĐƠN TỪ 200.000 ₫',
                  'variant': 'h3',
                  'color': '#C2410C',
                },
              },
              {
                'id': 'v1_exp',
                'type': 'text',
                'props': {
                  'value': 'Hạn dùng: Còn 3 ngày • Toàn sàn Shopee Mall',
                  'variant': 'subtitle',
                },
              },
            ],
          },
          {
            'id': 'back_btn',
            'type': 'button',
            'props': {
              'label': 'Quay lại Trang Mua Sắm',
              'variant': 'outline',
              'icon': 'arrow',
            },
            'events': {
              'onClick': {
                'type': 'navigate',
                'targetPageId': 'home',
              },
            },
          },
        ],
      },
    ],
  };

  static const Map<String, dynamic> tiktokSchema = {
    'schemaVersion': 1,
    'theme': {
      'primaryColor': '#FE2C55',
      'backgroundColor': '#0F172A',
    },
    'pages': [
      {
        'id': 'home',
        'title': '🎵 TikTok Video & Live Hub',
        'components': [
          {
            'id': 'tiktok_banner',
            'type': 'image',
            'props': {
              'src': 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?auto=format&fit=crop&w=800&q=80',
              'alt': 'TikTok Trending Live',
              'height': 160,
              'borderRadius': 14,
            },
          },
          {
            'id': 'tt_title',
            'type': 'text',
            'props': {
              'value': 'TikTok - Sáng Tạo & Xu Hướng Toàn Cầu',
              'variant': 'h2',
              'color': '#FFFFFF',
            },
          },
          {
            'id': 'tt_subtitle',
            'type': 'text',
            'props': {
              'value': 'Khám phá video ngắn, livestream thần tượng và phụ kiện sáng tạo nội dung.',
              'variant': 'subtitle',
              'color': '#94A3B8',
            },
          },
          {
            'id': 'tt_shop_header',
            'type': 'text',
            'props': {
              'value': 'TIKTOK SHOP - THIẾT BỊ SÁNG TẠO HOT',
              'variant': 'h3',
              'color': '#FE2C55',
            },
          },
          {
            'id': 'tt_products',
            'type': 'product_list',
            'props': {
              'items': [
                {
                  'id': 'tt_01',
                  'title': 'Micro Thu Âm Cài Áo Không Dây V2',
                  'price': 590000,
                  'desc': 'Khử tiếng ồn AI, khoảng cách thu 20m',
                  'image': 'https://images.unsplash.com/photo-1590658268037-6bf12165a8df?auto=format&fit=crop&w=150&q=80',
                },
                {
                  'id': 'tt_02',
                  'title': 'Đèn Ring Light 12-inch RGB Chuyên Nghiệp',
                  'price': 349000,
                  'desc': '16 triệu màu, giá đỡ điện thoại 3 khớp xoay',
                  'image': 'https://images.unsplash.com/photo-1546776310-eef45dd6d63c?auto=format&fit=crop&w=150&q=80',
                },
                {
                  'id': 'tt_03',
                  'title': 'Gimbal Chống Rung Điện Thoại 3 Trục',
                  'price': 1290000,
                  'desc': 'Theo dõi khuôn mặt AI, quay TikTok siêu mượt',
                  'image': 'https://images.unsplash.com/photo-1579783900882-c0d3dad7b119?auto=format&fit=crop&w=150&q=80',
                },
              ],
            },
          },
          {
            'id': 'tt_actions',
            'type': 'container',
            'props': {
              'padding': 12,
              'backgroundColor': '#1E293B',
              'borderRadius': 12,
            },
            'children': [
              {
                'id': 'donate_btn',
                'type': 'button',
                'props': {
                  'label': 'Tặng Quà Live Idol (50.000 ₫)',
                  'variant': 'primary',
                  'icon': 'cart',
                },
                'events': {
                  'onClick': {
                    'type': 'native_action',
                    'action': 'payment.openCheckout',
                    'params': {
                      'amount': 50000,
                      'description': 'TikTok Live - Quà tặng Kim Cương Sư Tử Vàng',
                      'currency': 'VND',
                    },
                  },
                },
              },
              {
                'id': 'scan_creator_btn',
                'type': 'button',
                'props': {
                  'label': 'Quét Mã QR Kết Bạn Thần Tượng',
                  'variant': 'outline',
                  'icon': 'qr',
                },
                'events': {
                  'onClick': {
                    'type': 'native_action',
                    'action': 'device.scanQRCode',
                  },
                },
              },
              {
                'id': 'profile_btn',
                'type': 'button',
                'props': {
                  'label': 'Mở Trang Cá Nhân Native SuperApp',
                  'variant': 'secondary',
                  'icon': 'user',
                },
                'events': {
                  'onClick': {
                    'type': 'native_action',
                    'action': 'navigation.openNativePage',
                    'params': {'page': 'profile'},
                  },
                },
              },
            ],
          },
        ],
      },
    ],
  };

  static const Map<String, dynamic> youtubeSchema = {
    'schemaVersion': 1,
    'theme': {
      'primaryColor': '#FF0000',
      'backgroundColor': '#0F0F0F',
    },
    'pages': [
      {
        'id': 'home',
        'title': '🎬 YouTube Streaming & Media',
        'components': [
          {
            'id': 'yt_banner',
            'type': 'image',
            'props': {
              'src': 'https://images.unsplash.com/photo-1518770660439-4636190af475?auto=format&fit=crop&w=800&q=80',
              'alt': 'YouTube Media Player',
              'height': 160,
              'borderRadius': 14,
            },
          },
          {
            'id': 'yt_title',
            'type': 'text',
            'props': {
              'value': 'YouTube - Thế Giới Video Sống Động',
              'variant': 'h2',
              'color': '#FFFFFF',
            },
          },
          {
            'id': 'yt_subtitle',
            'type': 'text',
            'props': {
              'value': 'Nghe nhạc nền tắt màn hình, xem video 4K HDR mượt mà không quảng cáo.',
              'variant': 'subtitle',
              'color': '#A1A1AA',
            },
          },
          {
            'id': 'yt_plans_header',
            'type': 'text',
            'props': {
              'value': 'GÓI ĐĂNG KÝ YOUTUBE PREMIUM',
              'variant': 'h3',
              'color': '#EF4444',
            },
          },
          {
            'id': 'yt_products',
            'type': 'product_list',
            'props': {
              'items': [
                {
                  'id': 'yt_01',
                  'title': 'YouTube Premium Cá Nhân (1 Tháng)',
                  'price': 79000,
                  'desc': 'Xem không quảng cáo, tải offline, YouTube Music',
                  'image': 'https://images.unsplash.com/photo-1611162617213-7d7a39e9b1d7?auto=format&fit=crop&w=150&q=80',
                },
                {
                  'id': 'yt_02',
                  'title': 'YouTube Premium Gia Đình (1 Tháng)',
                  'price': 149000,
                  'desc': 'Chia sẻ đến 5 thành viên trong gia đình',
                  'image': 'https://images.unsplash.com/photo-1522869635100-9f4c5e86aa37?auto=format&fit=crop&w=150&q=80',
                },
                {
                  'id': 'yt_03',
                  'title': 'SuperChat Ủng Hộ Kênh Sáng Tạo',
                  'price': 50000,
                  'desc': 'Ghim bình luận nổi bật trên khung chat trực tiếp',
                  'image': 'https://images.unsplash.com/photo-1534447677768-be436bb09401?auto=format&fit=crop&w=150&q=80',
                },
              ],
            },
          },
          {
            'id': 'yt_actions',
            'type': 'container',
            'props': {
              'padding': 12,
              'backgroundColor': '#18181B',
              'borderRadius': 12,
            },
            'children': [
              {
                'id': 'subscribe_btn',
                'type': 'button',
                'props': {
                  'label': 'Nâng Cấp YouTube Premium (79.000 ₫)',
                  'variant': 'primary',
                  'icon': 'play',
                },
                'events': {
                  'onClick': {
                    'type': 'native_action',
                    'action': 'payment.openCheckout',
                    'params': {
                      'amount': 79000,
                      'description': 'YouTube Premium Cá Nhân 1 Tháng',
                      'currency': 'VND',
                    },
                  },
                },
              },
              {
                'id': 'user_info_btn',
                'type': 'button',
                'props': {
                  'label': 'Đồng Bộ Tài Khoản Google SuperApp',
                  'variant': 'outline',
                  'icon': 'user',
                },
                'events': {
                  'onClick': {
                    'type': 'native_action',
                    'action': 'user.getBasicInfo',
                  },
                },
              },
            ],
          },
        ],
      },
    ],
  };

  static const Map<String, dynamic> viettelTammiSchema = {
    'schemaVersion': 1,
    'theme': {
      'primaryColor': '#ED1C24',
      'backgroundColor': '#F8FAFC',
    },
    'pages': [
      {
        'id': 'home',
        'title': '📶 Viettel Tammi - Dịch Vụ Viễn Thông',
        'components': [
          {
            'id': 'vt_banner',
            'type': 'image',
            'props': {
              'src': 'https://images.unsplash.com/photo-1544717305-2782549b5136?auto=format&fit=crop&w=800&q=80',
              'alt': 'Viettel 5G',
              'height': 150,
              'borderRadius': 14,
            },
          },
          {
            'id': 'vt_balance_card',
            'type': 'container',
            'props': {
              'padding': 14,
              'backgroundColor': '#FEF2F2',
              'borderRadius': 12,
              'border': true,
            },
            'children': [
              {
                'id': 'sim_info',
                'type': 'text',
                'props': {
                  'value': 'Thuê Bao: 0984.888.xxx (Chính chủ VIP)',
                  'variant': 'h3',
                  'color': '#991B1B',
                },
              },
              {
                'id': 'sim_balance',
                'type': 'text',
                'props': {
                  'value': 'Số dư tài khoản: 145.000 ₫ • Data 4G còn lại: 18.2 GB',
                  'variant': 'body',
                  'color': '#DC2626',
                },
              },
            ],
          },
          {
            'id': 'vt_plans_title',
            'type': 'text',
            'props': {
              'value': 'GÓI CƯỚC DATA 4G/5G TỐC ĐỘ CAO',
              'variant': 'h3',
              'color': '#B91C1C',
            },
          },
          {
            'id': 'vt_products',
            'type': 'product_list',
            'props': {
              'items': [
                {
                  'id': 'vt_01',
                  'title': 'Gói Cước ST150K (30 Ngày)',
                  'price': 150000,
                  'desc': '3GB Data/ngày (90GB/tháng) + Miễn phí xem phim',
                  'image': 'https://images.unsplash.com/photo-1563770660941-20978e870e26?auto=format&fit=crop&w=150&q=80',
                },
                {
                  'id': 'vt_02',
                  'title': 'Gói Cước V200C Siêu Ưu Đãi',
                  'price': 200000,
                  'desc': '4GB/ngày + Miễn phí gọi nội mạng < 20 phút',
                  'image': 'https://images.unsplash.com/photo-1533227268428-f9ed0900fb3b?auto=format&fit=crop&w=150&q=80',
                },
                {
                  'id': 'vt_03',
                  'title': 'Nạp Thẻ Viettel 100K Chiết Khấu 5%',
                  'price': 95000,
                  'desc': 'Cộng tiền tài khoản gốc tức thì trong 10 giây',
                  'image': 'https://images.unsplash.com/photo-1559526324-4b87b5e36e44?auto=format&fit=crop&w=150&q=80',
                },
              ],
            },
          },
          {
            'id': 'vt_actions',
            'type': 'container',
            'props': {
              'padding': 12,
              'backgroundColor': '#FFFFFF',
              'borderRadius': 12,
            },
            'children': [
              {
                'id': 'scan_card_btn',
                'type': 'button',
                'props': {
                  'label': 'Quét Mã QR Thẻ Cào Viettel',
                  'variant': 'outline',
                  'icon': 'qr',
                },
                'events': {
                  'onClick': {
                    'type': 'native_action',
                    'action': 'device.scanQRCode',
                  },
                },
              },
              {
                'id': 'buy_st150k_btn',
                'type': 'button',
                'props': {
                  'label': 'Đăng Ký Gói ST150K (150.000 ₫)',
                  'variant': 'primary',
                  'icon': 'cart',
                },
                'events': {
                  'onClick': {
                    'type': 'native_action',
                    'action': 'payment.openCheckout',
                    'params': {
                      'amount': 150000,
                      'description': 'Viettel Tammi - Đăng ký gói Data ST150K',
                      'currency': 'VND',
                    },
                  },
                },
              },
              {
                'id': 'sub_profile_btn',
                'type': 'button',
                'props': {
                  'label': 'Tra Cứu Thông Tin Chủ Thuê Bao',
                  'variant': 'secondary',
                  'icon': 'user',
                },
                'events': {
                  'onClick': {
                    'type': 'native_action',
                    'action': 'user.getProfile',
                  },
                },
              },
            ],
          },
        ],
      },
    ],
  };

  static const Map<String, dynamic> freeFireSchema = {
    'schemaVersion': 1,
    'theme': {
      'primaryColor': '#F59E0B',
      'backgroundColor': '#0F172A',
    },
    'pages': [
      {
        'id': 'home',
        'title': '🎮 Garena Free Fire MAX',
        'components': [
          {
            'id': 'ff_banner',
            'type': 'image',
            'props': {
              'src': 'https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&w=800&q=80',
              'alt': 'Free Fire MAX',
              'height': 160,
              'borderRadius': 14,
            },
          },
          {
            'id': 'ff_title',
            'type': 'text',
            'props': {
              'value': 'Free Fire MAX - Đỉnh Cao Sinh Tồn',
              'variant': 'h2',
              'color': '#F59E0B',
            },
          },
          {
            'id': 'ff_subtitle',
            'type': 'text',
            'props': {
              'value': 'Mùa giải Booyah Pass mới! Nạp kim cương trực tiếp nhận ngay Skin AK Rồng Xanh.',
              'variant': 'subtitle',
              'color': '#94A3B8',
            },
          },
          {
            'id': 'ff_store_header',
            'type': 'text',
            'props': {
              'value': '💎 NẠP KIM CƯƠNG GIÁ GỐC GARENA',
              'variant': 'h3',
              'color': '#F59E0B',
            },
          },
          {
            'id': 'ff_products',
            'type': 'product_list',
            'props': {
              'items': [
                {
                  'id': 'ff_01',
                  'title': '530 Kim Cương (+53 Kim Cương Thưởng)',
                  'price': 100000,
                  'desc': 'Nạp trực tiếp vào ID game trong 5 giây',
                  'image': 'https://images.unsplash.com/photo-1614680376593-902f749f7ffc?auto=format&fit=crop&w=150&q=80',
                },
                {
                  'id': 'ff_02',
                  'title': 'Thẻ Vô Cực Booyah Pass Mùa Mới',
                  'price': 180000,
                  'desc': 'Mở khóa toàn bộ 100 cấp phần thưởng độc quyền',
                  'image': 'https://images.unsplash.com/photo-1550745165-9bc0b252726f?auto=format&fit=crop&w=150&q=80',
                },
                {
                  'id': 'ff_03',
                  'title': 'Thẻ Thành Viên Tuần (450 Kim Cương)',
                  'price': 50000,
                  'desc': 'Nhận 60 Kim Cương mỗi ngày khi đăng nhập',
                  'image': 'https://images.unsplash.com/photo-1538481199705-c710c4e965fc?auto=format&fit=crop&w=150&q=80',
                },
              ],
            },
          },
          {
            'id': 'ff_actions',
            'type': 'container',
            'props': {
              'padding': 12,
              'backgroundColor': '#1E293B',
              'borderRadius': 12,
            },
            'children': [
              {
                'id': 'topup_btn',
                'type': 'button',
                'props': {
                  'label': 'Nạp 530 Kim Cương Ngay (100.000 ₫)',
                  'variant': 'primary',
                  'icon': 'cart',
                },
                'events': {
                  'onClick': {
                    'type': 'native_action',
                    'action': 'payment.openCheckout',
                    'params': {
                      'amount': 100000,
                      'description': 'Free Fire - Gói 530 Kim Cương Siêu Tốc',
                      'currency': 'VND',
                    },
                  },
                },
              },
              {
                'id': 'giftcode_btn',
                'type': 'button',
                'props': {
                  'label': 'Quét Mã QR Nhận Giftcode Giải Đấu',
                  'variant': 'outline',
                  'icon': 'qr',
                },
                'events': {
                  'onClick': {
                    'type': 'native_action',
                    'action': 'device.scanQRCode',
                  },
                },
              },
            ],
          },
        ],
      },
    ],
  };

  static const Map<String, dynamic> capcutSchema = {
    'schemaVersion': 1,
    'theme': {
      'primaryColor': '#06B6D4',
      'backgroundColor': '#18181B',
    },
    'pages': [
      {
        'id': 'home',
        'title': '✂️ CapCut Creative Video Studio',
        'components': [
          {
            'id': 'cc_banner',
            'type': 'image',
            'props': {
              'src': 'https://images.unsplash.com/photo-1574717024653-61fd2cf4d44d?auto=format&fit=crop&w=800&q=80',
              'alt': 'CapCut Video Studio',
              'height': 160,
              'borderRadius': 14,
            },
          },
          {
            'id': 'cc_title',
            'type': 'text',
            'props': {
              'value': 'CapCut - Sáng Tạo Video Chuyên Nghiệp',
              'variant': 'h2',
              'color': '#FFFFFF',
            },
          },
          {
            'id': 'cc_subtitle',
            'type': 'text',
            'props': {
              'value': 'Hàng ngàn mẫu giật giật, hiệu ứng âm thanh hot trend và công cụ cắt ghép AI thông minh.',
              'variant': 'subtitle',
              'color': '#A1A1AA',
            },
          },
          {
            'id': 'cc_templates_header',
            'type': 'text',
            'props': {
              'value': 'GÓI CAPCUT PRO & TÀI NGUYÊN PREMIUM',
              'variant': 'h3',
              'color': '#06B6D4',
            },
          },
          {
            'id': 'cc_products',
            'type': 'product_list',
            'props': {
              'items': [
                {
                  'id': 'cc_01',
                  'title': 'CapCut Pro 1 Năm (Không Giới Hạn)',
                  'price': 599000,
                  'desc': 'Xuất video 4K 60fps, xóa phông nền AI 1 chạm',
                  'image': 'https://images.unsplash.com/photo-1536240478700-b869070f9279?auto=format&fit=crop&w=150&q=80',
                },
                {
                  'id': 'cc_02',
                  'title': 'Bộ Preset Màu Điện Ảnh Hollywood LUTs',
                  'price': 79000,
                  'desc': '45 bộ màu phong cách Cyberpunk, Vintage, Film',
                  'image': 'https://images.unsplash.com/photo-1492691527719-9d1e07e534b4?auto=format&fit=crop&w=150&q=80',
                },
                {
                  'id': 'cc_03',
                  'title': 'CapCut Pro 1 Tháng Trải Nghiệm',
                  'price': 79000,
                  'desc': 'Toàn bộ hiệu ứng VIP không watermark',
                  'image': 'https://images.unsplash.com/photo-1579202673506-ca3ce28943ef?auto=format&fit=crop&w=150&q=80',
                },
              ],
            },
          },
          {
            'id': 'cc_actions',
            'type': 'container',
            'props': {
              'padding': 12,
              'backgroundColor': '#27272A',
              'borderRadius': 12,
            },
            'children': [
              {
                'id': 'pick_img_btn',
                'type': 'button',
                'props': {
                  'label': 'Chọn Ảnh Từ Thư Viện Để Tạo Clip Mẫu',
                  'variant': 'outline',
                  'icon': 'sparkles',
                },
                'events': {
                  'onClick': {
                    'type': 'native_action',
                    'action': 'device.pickImage',
                  },
                },
              },
              {
                'id': 'buy_pro_btn',
                'type': 'button',
                'props': {
                  'label': 'Nâng Cấp CapCut Pro 1 Năm (599.000 ₫)',
                  'variant': 'primary',
                  'icon': 'cart',
                },
                'events': {
                  'onClick': {
                    'type': 'native_action',
                    'action': 'payment.openCheckout',
                    'params': {
                      'amount': 599000,
                      'description': 'CapCut Pro 1 Năm Không Giới Hạn',
                      'currency': 'VND',
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

  static const Map<String, dynamic> messengerSchema = {
    'schemaVersion': 1,
    'theme': {
      'primaryColor': '#0084FF',
      'backgroundColor': '#F8FAFC',
    },
    'pages': [
      {
        'id': 'home',
        'title': '💬 Messenger Community & Chat',
        'components': [
          {
            'id': 'msg_banner',
            'type': 'image',
            'props': {
              'src': 'https://images.unsplash.com/photo-1577563908411-5077b6dc7624?auto=format&fit=crop&w=800&q=80',
              'alt': 'Messenger Friends',
              'height': 150,
              'borderRadius': 14,
            },
          },
          {
            'id': 'msg_title',
            'type': 'text',
            'props': {
              'value': 'Messenger - Trò Chuyện & Chia Sẻ',
              'variant': 'h2',
              'color': '#0084FF',
            },
          },
          {
            'id': 'msg_subtitle',
            'type': 'text',
            'props': {
              'value': 'Kết nối tức thì với bạn bè, gửi thông báo và chuyển tiền lì xì nhanh chóng.',
              'variant': 'subtitle',
            },
          },
          {
            'id': 'msg_group_header',
            'type': 'text',
            'props': {
              'value': 'NHÓM & TIỆN ÍCH TRÒ CHUYỆN',
              'variant': 'h3',
              'color': '#0084FF',
            },
          },
          {
            'id': 'msg_products',
            'type': 'product_list',
            'props': {
              'items': [
                {
                  'id': 'msg_01',
                  'title': 'Gói Nhãn Dán Động Capybara Vui Nhộn',
                  'price': 19000,
                  'desc': '30 sticker hiệu ứng âm thanh độc quyền',
                  'image': 'https://images.unsplash.com/photo-1563245372-f21724e3856d?auto=format&fit=crop&w=150&q=80',
                },
                {
                  'id': 'msg_02',
                  'title': 'Huy Hiệu Trưởng Nhóm Messenger VIP',
                  'price': 49000,
                  'desc': 'Tùy chỉnh màu chat và ghim tin nhắn tự động',
                  'image': 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?auto=format&fit=crop&w=150&q=80',
                },
              ],
            },
          },
          {
            'id': 'msg_actions',
            'type': 'container',
            'props': {
              'padding': 12,
              'backgroundColor': '#FFFFFF',
              'borderRadius': 12,
            },
            'children': [
              {
                'id': 'lixi_btn',
                'type': 'button',
                'props': {
                  'label': 'Chuyển Tiền Lì Xì Bạn Bè (50.000 ₫)',
                  'variant': 'primary',
                  'icon': 'cart',
                },
                'events': {
                  'onClick': {
                    'type': 'native_action',
                    'action': 'payment.openCheckout',
                    'params': {
                      'amount': 50000,
                      'description': 'Messenger - Tiền lì xì chúc mừng bạn bè',
                      'currency': 'VND',
                    },
                  },
                },
              },
              {
                'id': 'open_form_btn',
                'type': 'button',
                'props': {
                  'label': 'Mở Form Gửi Ý Kiến Đóng Góp (Native Form)',
                  'variant': 'outline',
                  'icon': 'message',
                },
                'events': {
                  'onClick': {
                    'type': 'native_action',
                    'action': 'navigation.openNativePage',
                    'params': {'page': 'form'},
                  },
                },
              },
              {
                'id': 'close_app_btn',
                'type': 'button',
                'props': {
                  'label': 'Đóng Mini App',
                  'variant': 'secondary',
                  'icon': 'close',
                },
                'events': {
                  'onClick': {
                    'type': 'native_action',
                    'action': 'navigation.close',
                  },
                },
              },
            ],
          },
        ],
      },
    ],
  };

  static const Map<String, dynamic> facebookSchema = {
    'schemaVersion': 1,
    'theme': {
      'primaryColor': '#1877F2',
      'backgroundColor': '#F0F2F5',
    },
    'pages': [
      {
        'id': 'home',
        'title': '🌐 Facebook Community',
        'components': [
          {
            'id': 'fb_banner',
            'type': 'image',
            'props': {
              'src': 'https://images.unsplash.com/photo-1522071820081-009f0129c71c?auto=format&fit=crop&w=800&q=80',
              'alt': 'Facebook Community Connect',
              'height': 150,
              'borderRadius': 14,
            },
          },
          {
            'id': 'fb_title',
            'type': 'text',
            'props': {
              'value': 'Facebook - Khám Phá & Kết Nối Cộng Đồng',
              'variant': 'h2',
              'color': '#1877F2',
            },
          },
          {
            'id': 'fb_subtitle',
            'type': 'text',
            'props': {
              'value': 'Tham gia nhóm sở thích, khám phá chợ Marketplace và giao lưu cùng bạn bè.',
              'variant': 'subtitle',
            },
          },
          {
            'id': 'fb_products',
            'type': 'product_list',
            'props': {
              'items': [
                {
                  'id': 'fb_01',
                  'title': 'Huy Hiệu Fan Cứng & Ngôi Sao Ủng Hộ (100 Stars)',
                  'price': 25000,
                  'desc': 'Gửi tặng ngôi sao cho các nhà sáng tạo nội dung',
                  'image': 'https://images.unsplash.com/photo-1579208575657-c595a05383b7?auto=format&fit=crop&w=150&q=80',
                },
                {
                  'id': 'fb_02',
                  'title': 'Gói Quảng Cáo Bài Viết Fanpage Tự Động',
                  'price': 100000,
                  'desc': 'Tiếp cận 10.000 khách hàng tiềm năng quanh khu vực',
                  'image': 'https://images.unsplash.com/photo-1460925895917-afdab827c52f?auto=format&fit=crop&w=150&q=80',
                },
              ],
            },
          },
          {
            'id': 'fb_actions',
            'type': 'container',
            'props': {
              'padding': 12,
              'backgroundColor': '#FFFFFF',
              'borderRadius': 12,
            },
            'children': [
              {
                'id': 'fb_stars_btn',
                'type': 'button',
                'props': {
                  'label': 'Mua 100 Ngôi Sao Tặng Creator (25.000 ₫)',
                  'variant': 'primary',
                  'icon': 'cart',
                },
                'events': {
                  'onClick': {
                    'type': 'native_action',
                    'action': 'payment.openCheckout',
                    'params': {
                      'amount': 25000,
                      'description': 'Facebook Stars - 100 Ngôi Sao',
                      'currency': 'VND',
                    },
                  },
                },
              },
              {
                'id': 'fb_profile_btn',
                'type': 'button',
                'props': {
                  'label': 'Xem Trang Cá Nhân Native',
                  'variant': 'secondary',
                  'icon': 'user',
                },
                'events': {
                  'onClick': {
                    'type': 'native_action',
                    'action': 'navigation.openNativePage',
                    'params': {'page': 'profile'},
                  },
                },
              },
            ],
          },
        ],
      },
    ],
  };

  static const Map<String, dynamic> zaloSchema = {
    'schemaVersion': 1,
    'theme': {
      'primaryColor': '#0068FF',
      'backgroundColor': '#F8FAFC',
    },
    'pages': [
      {
        'id': 'home',
        'title': '💬 Zalo Dịch Vụ Công & Tiện Ích',
        'components': [
          {
            'id': 'zalo_banner',
            'type': 'image',
            'props': {
              'src': 'https://images.unsplash.com/photo-1451187580459-43490279c0fa?auto=format&fit=crop&w=800&q=80',
              'alt': 'Zalo Smart Services',
              'height': 150,
              'borderRadius': 14,
            },
          },
          {
            'id': 'zalo_title',
            'type': 'text',
            'props': {
              'value': 'Zalo - Tiện Ích Đời Sống & Dịch Vụ Số',
              'variant': 'h2',
              'color': '#0068FF',
            },
          },
          {
            'id': 'zalo_subtitle',
            'type': 'text',
            'props': {
              'value': 'Tra cứu hóa đơn điện nước, nạp tiền điện thoại và kết nối cơ quan hành chính.',
              'variant': 'subtitle',
            },
          },
          {
            'id': 'zalo_products',
            'type': 'product_list',
            'props': {
              'items': [
                {
                  'id': 'zl_01',
                  'title': 'Hóa Đơn Tiền Điện EVN Tháng Này',
                  'price': 485000,
                  'desc': 'Mã khách hàng: PE01000293848 • EVN Hà Nội',
                  'image': 'https://images.unsplash.com/photo-1473341304170-971dccb5ac1e?auto=format&fit=crop&w=150&q=80',
                },
                {
                  'id': 'zl_02',
                  'title': 'Hóa Đơn Nước Sinh Hoạt Sạch',
                  'price': 120000,
                  'desc': 'Mã đồng hồ: WA-99238 • Công ty cấp nước Sài Gòn',
                  'image': 'https://images.unsplash.com/photo-1548839140-29a749e1bc4e?auto=format&fit=crop&w=150&q=80',
                },
              ],
            },
          },
          {
            'id': 'zalo_actions',
            'type': 'container',
            'props': {
              'padding': 12,
              'backgroundColor': '#FFFFFF',
              'borderRadius': 12,
            },
            'children': [
              {
                'id': 'zl_pay_electric_btn',
                'type': 'button',
                'props': {
                  'label': 'Thanh Toán Tiền Điện EVN (485.000 ₫)',
                  'variant': 'primary',
                  'icon': 'cart',
                },
                'events': {
                  'onClick': {
                    'type': 'native_action',
                    'action': 'payment.openCheckout',
                    'params': {
                      'amount': 485000,
                      'description': 'Zalo Pay - Thanh toán tiền điện EVN',
                      'currency': 'VND',
                    },
                  },
                },
              },
              {
                'id': 'zl_scan_bill_btn',
                'type': 'button',
                'props': {
                  'label': 'Quét QR Hóa Đơn Dịch Vụ',
                  'variant': 'outline',
                  'icon': 'qr',
                },
                'events': {
                  'onClick': {
                    'type': 'native_action',
                    'action': 'device.scanQRCode',
                  },
                },
              },
            ],
          },
        ],
      },
    ],
  };

  static const Map<String, dynamic> fcMobileSchema = {
    'schemaVersion': 1,
    'theme': {
      'primaryColor': '#10B981',
      'backgroundColor': '#064E3B',
    },
    'pages': [
      {
        'id': 'home',
        'title': '⚽ EA Sports FC Mobile VN',
        'components': [
          {
            'id': 'fcm_banner',
            'type': 'image',
            'props': {
              'src': 'https://images.unsplash.com/photo-1508098682722-e99c43a406b2?auto=format&fit=crop&w=800&q=80',
              'alt': 'FC Mobile Football Stadium',
              'height': 160,
              'borderRadius': 14,
            },
          },
          {
            'id': 'fcm_title',
            'type': 'text',
            'props': {
              'value': 'FC Mobile VN - Sân Cỏ Huyền Thoại',
              'variant': 'h2',
              'color': '#10B981',
            },
          },
          {
            'id': 'fcm_subtitle',
            'type': 'text',
            'props': {
              'value': 'Mở gói cầu thủ ICON OVR 105+, nâng cấp sân vận động và tham gia giải đấu Cup C1.',
              'variant': 'subtitle',
              'color': '#A7F3D0',
            },
          },
          {
            'id': 'fcm_products',
            'type': 'product_list',
            'props': {
              'items': [
                {
                  'id': 'fcm_01',
                  'title': 'Gói Cầu Thủ TOTY Siêu Sao Đảm Bảo',
                  'price': 199000,
                  'desc': 'Nhận ngẫu nhiên 1 cầu thủ OVR từ 102 đến 107',
                  'image': 'https://images.unsplash.com/photo-1579952363873-27f3bade9f55?auto=format&fit=crop&w=150&q=80',
                },
                {
                  'id': 'fcm_02',
                  'title': 'Nạp 1.200 FC Points Khuyến Mãi',
                  'price': 100000,
                  'desc': 'Nhận thêm 300 FC Points thưởng sự kiện cuối tuần',
                  'image': 'https://images.unsplash.com/photo-1518091043644-c1d4457512c6?auto=format&fit=crop&w=150&q=80',
                },
              ],
            },
          },
          {
            'id': 'fcm_actions',
            'type': 'container',
            'props': {
              'padding': 12,
              'backgroundColor': '#065F46',
              'borderRadius': 12,
            },
            'children': [
              {
                'id': 'buy_pack_btn',
                'type': 'button',
                'props': {
                  'label': 'Mở Gói TOTY Ngay (199.000 ₫)',
                  'variant': 'primary',
                  'icon': 'cart',
                  'backgroundColor': '#10B981',
                },
                'events': {
                  'onClick': {
                    'type': 'native_action',
                    'action': 'payment.openCheckout',
                    'params': {
                      'amount': 199000,
                      'description': 'FC Mobile - Gói cầu thủ TOTY Siêu Sao',
                      'currency': 'VND',
                    },
                  },
                },
              },
              {
                'id': 'fcm_qr_btn',
                'type': 'button',
                'props': {
                  'label': 'Quét QR Nhận Vé Tham Dự Giải Đấu',
                  'variant': 'outline',
                  'icon': 'qr',
                  'color': '#A7F3D0',
                },
                'events': {
                  'onClick': {
                    'type': 'native_action',
                    'action': 'device.scanQRCode',
                  },
                },
              },
            ],
          },
        ],
      },
    ],
  };

  /// Returns map of all built-in schemas indexed by app ID
  static Map<String, Map<String, dynamic>> get allSchemas => {
    'shopee': shopeeSchema,
    'tiktok': tiktokSchema,
    'youtube': youtubeSchema,
    'viettel_tammi': viettelTammiSchema,
    'free_fire': freeFireSchema,
    'capcut': capcutSchema,
    'messenger': messengerSchema,
    'facebook': facebookSchema,
    'zalo': zaloSchema,
    'fc_mobile': fcMobileSchema,
  };
}
