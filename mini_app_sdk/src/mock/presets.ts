import { MockUserProfile } from './types.js';

export const MOCK_USER_PRESETS: Record<string, MockUserProfile> = {
  standard: {
    id: 'user_std_001',
    name: 'Nguyễn Văn An',
    phone: '0901234567',
    email: 'an.nguyen@example.com',
    avatarUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150',
    role: 'CUSTOMER',
    isVerified: true,
    walletBalance: 2500000,
  },
  vip: {
    id: 'user_vip_888',
    name: 'Trần Thị Mai (VIP Diamond)',
    phone: '0988888888',
    email: 'mai.tran@superapp.vn',
    avatarUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150',
    role: 'VIP',
    isVerified: true,
    walletBalance: 50000000,
  },
  lowBalance: {
    id: 'user_low_002',
    name: 'Lê Hoàng Khang',
    phone: '0912345678',
    email: 'khang.le@example.com',
    avatarUrl: 'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?w=150',
    role: 'CUSTOMER',
    isVerified: true,
    walletBalance: 15000,
  },
  unverified: {
    id: 'user_guest_999',
    name: 'Khách Vãng Lai',
    phone: '',
    email: '',
    avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
    role: 'CUSTOMER',
    isVerified: false,
    walletBalance: 0,
  },
};
