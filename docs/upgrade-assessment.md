# Upgrade Assessment & Codebase Audit: Super App to Dynamic Mini App Publishing Platform

**Date:** 2026-10-26  
**Architect:** Senior Software Architect  
**Project:** Super App Platform (`superapp_platform`)  
**Scope:** Phase 0 (Codebase Audit) & Phase 1 (Dynamic Registry + Catalog Architecture)

---

## 1. Executive Summary

Hệ thống Super App hiện tại đã được triển khai hoàn chỉnh luồng end-to-end với Flutter Master App (FVM 3.41.9, Dart 3.11.5, Riverpod 2.6.1, GoRouter 14.8.1, webview_flutter 4.14.1) và 2 Mini App Web (SDK Playground với React 18 + TypeScript + Vite 5, và Highland Coffee Sample Store). Hệ thống đã đạt 100% test pass (22/22 tests) và 0 analyzer warning/error.

Mục tiêu của giai đoạn nâng cấp này là chuyển đổi Super App từ cấu hình Mini App tĩnh sang nền tảng **Dynamic Mini App Registry & Publishing Platform** (tương tự kiến trúc Zalo Mini App, WeChat Mini Program), kết hợp **No-Code App Builder** cho phép đối tác/khách hàng tự thiết kế giao diện dạng Schema-driven, nộp duyệt, phê duyệt và tự động hiển thị trên Master App mà **không cần sửa mã nguồn Flutter hay rebuild ứng dụng mẹ**.

---

## 2. Existing Modules (Source Code Thực tế)

| Module / Layer | Đường dẫn | Công nghệ / Thư viện | Trạng thái hiện tại |
|---|---|---|---|
| **Master App Bootstrap & Router** | `lib/app/bootstrap/`, `lib/app/router/` | Flutter, GoRouter | Định tuyến Splash -> Login -> Home -> MiniApp -> Profile -> Form -> Debug |
| **Bridge Protocol Core** | `lib/core/bridge_protocol/` | Dart models, JSON serialization | `BridgeRequest`, `BridgeResponse`, `BridgeEvent`, `BridgeEnvelope` |
| **Bridge Error Handling** | `lib/core/errors/` | Dart Exceptions | `BridgeError` với 8 mã chuẩn (`AUTH_REQUIRED`, `PERMISSION_DENIED`, v.v.) |
| **Mock Authentication** | `lib/features/authentication/` | Riverpod, StateNotifier | Quản lý User A / User B, phiên đăng nhập, access token, refresh token |
| **Auth Code & Token Service** | `lib/features/authentication/data/` | In-memory Mock Services | Auth code 60s single-use, mini app token issuance và refresh |
| **Mini App Catalog (Static)** | `lib/features/mini_app_catalog/` | `MiniAppRepository`, `MiniAppManifest` | Danh mục tĩnh với 2 app: `sdk_playground` và `sample_store` |
| **WebView Runtime & Host** | `lib/features/mini_app_runtime/` | `webview_flutter` | Host Mini App Web, quản lý lifecycle (resume/paused) |
| **JavaScript Bridge** | `lib/features/mini_app_bridge/` | JavaScriptChannel, JS Injection | Kênh `FlutterBridge`, polyfill `window.SuperAppBridge`, dispatchResponse |
| **Native Action Dispatcher** | `lib/features/native_actions/` | Chain of Responsibility / Command | 5 lớp kiểm soát: Session, App Identity, Origin, Allowlist, Permissions |
| **Native Handlers** | `lib/features/native_actions/handlers/` | Handlers riêng biệt | Auth, User, Navigation, Device, Payment, Permission, Debug |
| **Permissions System** | `lib/features/permissions/` | `MockPermissionRepository` | Quản lý capabilities, `PermissionPromptDialog` (Allow/Deny) |
| **Device Adapters** | `lib/features/device/` | `MockDeviceAdapter` | Mock QR, Mock GPS, Mock Image Picker, toggle Real Device Mode |
| **Payment Flow** | `lib/features/payment/` | `MockOrderRepository` | `createOrder`, `openCheckout`, `NativeCheckoutScreen` (Success/Fail/Cancel) |
| **Debug Center** | `lib/features/debug_center/` | `DebugLogRepository` | Ghi log 2 chiều, mask token, mô phỏng lỗi (timeout, unauthorized, v.v.) |
| **React Mini App (SDK Playground)** | `mini_apps/sdk_playground/` | React 18, TypeScript, Vite 5 | Feature Catalog A..H, Runner Modal, Event Logger, Debug Center |
| **Mini App JS SDK** | `mini_apps/sdk_playground/src/sdk/` | TypeScript, BridgeTransport | `superApp.*`, `mockAuthBackend.*`, Fallback Browser Simulator |
| **Sample Store Mini App** | `mini_apps/sample_store/` | HTML5, Vanilla JS, CSS3 | Mini App thứ 2 demo chuyển đổi chéo qua lại |

---

## 3. Reusable Modules (Tái sử dụng 100%)

Các module sau đây được giữ nguyên thiết kế và chỉ mở rộng theo nguyên tắc **Open-Closed Principle (OCP)** và **Strangler Fig Pattern**:

1. **`lib/core/bridge_protocol/`**: Giao thức Request/Response/Event giữ nguyên cấu trúc JSON.
2. **`lib/core/errors/`**: Giữ nguyên hệ thống mã lỗi `BridgeError`.
3. **`lib/features/mini_app_bridge/`**: Giữ nguyên kênh giao tiếp `FlutterBridge` và cơ chế JS evaluation.
4. **`lib/features/native_actions/`**: `NativeActionDispatcher` và 7 action handlers hiện hữu tiếp tục phụ trách toàn bộ lời gọi từ Mini App.
5. **`lib/features/authentication/`**: Toàn bộ luồng đăng nhập, Riverpod session state và mã xác thực 60s tiếp tục hoạt động.
6. **`lib/features/permissions/`**, **`lib/features/device/`**, **`lib/features/payment/`**: Hoàn toàn tái sử dụng không cần sửa đổi.
7. **`mini_apps/sdk_playground/`**: Giữ nguyên làm Mini App chuẩn mẫu và công cụ kiểm thử SDK.
8. **`lib/features/mini_app_runtime/`**: Tái sử dụng WebView Host để nạp cả Web Mini App và No-Code Schema Mini App (thông qua Shared Schema Engine).

---

## 4. Modules Cần Bổ Sung

Theo kiến trúc mới, các module mới sẽ được bổ sung:

### A. Backend Services (`backend/` - NestJS Modular Monolith)
1. **`MiniAppRegistryModule`**: Quản lý metadata Mini App của đối tác, lưu trữ Draft và các phiên bản lịch sử.
2. **`MiniAppVersionsModule`**: Quản lý các Version Snapshot (bất biến sau khi submit).
3. **`MiniAppReviewModule`**: Quy trình xét duyệt trực tuyến (Admin Preview, Approve, Reject kèm lý do).
4. **`MiniAppPublishingModule`**: Cơ chế Publish phiên bản đã duyệt, Unpublish tức thì, Rollback về phiên bản trước, Suspend.
5. **`MiniAppCatalogModule`**: REST API phục vụ cho Flutter Master App (chỉ trả các Mini App có trạng thái `PUBLISHED`, hỗ trợ tìm kiếm, phân loại category, phân trang).
6. **`MiniAppCapabilitiesModule`**: Khai báo và đối chiếu capabilities hợp lệ.
7. **`MiniAppSeedModule`**: Khởi tạo sẵn 2 Mini App hiện có (`sdk_playground` và `sample_store`) ở trạng thái `PUBLISHED` để đảm bảo hệ thống luôn sẵn sàng ngay cả khi vừa khởi chạy backend.

### B. Flutter Dynamic Catalog Client (`lib/features/mini_app_catalog/`)
1. **`DynamicMiniAppRepository`**: Kế thừa hoặc thay thế adapter tĩnh để truy vấn từ Catalog API, có bộ đệm in-memory và fallback offline về Seed Assets nếu mất kết nối mạng.
2. **`CatalogNotifier` / Riverpod Providers**: Quản lý trạng thái danh mục động (loading, loaded, error, pull-to-refresh, search filter).

### C. No-Code Schema Engine & Builder (Các giai đoạn tiếp theo)
1. **Shared Schema Runtime**: Bộ renderer React gọn nhẹ chuyển đổi JSON Schema thành component cây giao diện trong Mini App.
2. **No-Code Builder Web**: Giao diện drag/drop & property editor cho khách hàng tự dựng app.

---

## 5. Files Cần Chỉnh Sửa & Độ Rủi Ro (Impact Analysis)

| File | Nội dung thay đổi | Mức độ rủi ro | Giải pháp giảm thiểu |
|---|---|---|---|
| `lib/features/mini_app_catalog/domain/mini_app_manifest.dart` | Bổ sung các trường tùy chọn: `runtimeType` ('web' \| 'schema'), `category`, `status`, `schemaUrl`, `schemaVersion`. | **RẤT THẤP** | Đặt giá trị mặc định cho tất cả trường mới (`runtimeType: 'web'`, `status: 'PUBLISHED'`), giữ nguyên constructor cũ. |
| `lib/features/mini_app_catalog/data/mini_app_repository.dart` | Bổ sung phương thức `getPublishedMiniApps()`, `searchMiniApps()`, `getMiniAppsByCategory()`, kết nối Catalog API với fallback in-memory. | **THẤP** | Giữ nguyên các hàm `getAllApps()` và `getAppById()` đang có để không ảnh hưởng các test cũ. |
| `lib/core/config/app_config.dart` | Bổ sung URL của Catalog API (mặc định `http://localhost:3000/api/v1` hoặc `http://10.0.2.2:3000/api/v1`). | **KHÔNG CÓ** | Thêm hằng số mới. |

---

## 6. Migration Strategy (Strangler Pattern)

```
[Phase 0: Audit]
       │
[Phase 1: Dynamic Registry + Catalog API (NestJS + PostgreSQL)]
  ├── Seed sẵn 2 ứng dụng cũ: sdk_playground (v1.0.0, web) & sample_store (v1.0.0, web)
  ├── Expose Public Catalog API: GET /api/v1/catalog/apps
  └── Update MiniAppManifest & MiniAppRepository hỗ trợ dynamic + fallback offline
       │
[Phase 2: Flutter Dynamic Home Integration]
  ├── Pull-to-refresh, tìm kiếm theo tên, lọc theo category
  └── Widget test kiểm tra backward compatibility
       │
[Phase 3: No-Code Schema Runtime]
  └── React Shared Schema Engine thông dịch JSON thành giao diện Native Bridge
       │
[Phase 4: No-Code Builder MVP]
  └── Giao diện web thiết kế App, quản lý Pages, Palette, Properties, Preview, Save Draft
       │
[Phase 5: Review & Publishing Workflow]
  └── Submit for review -> Admin Review (Approve/Reject) -> Publish / Rollback / Suspend
       │
[Phase 6: End-to-End Integration]
  └── Kịch bản mẫu Coffee Shop hoàn chỉnh
       │
[Phase 7: Regression Testing & Hoàn tất]
```

---

## 7. Testing Strategy

1. **Backend Tests (Jest)**:
   - Test tạo Draft Mini App.
   - Test Submit review (bảo đảm snapshot version bất biến).
   - Test Admin Approve / Reject.
   - Test Publish cập nhật `activePublishedVersion` atomic.
   - Test Unpublish & Suspend (chặn cả listing và direct launch).
   - Test Catalog API (chỉ trả app Published, lọc category, tìm kiếm).
2. **Flutter Analyzer & Tests**:
   - Chạy `fvm flutter analyze` đảm bảo 0 issues.
   - Chạy toàn bộ 22 widget & unit tests cũ đảm bảo không bị regression.
   - Bổ sung unit tests cho `DynamicMiniAppRepository` và `MiniAppManifest` mở rộng.
3. **Mini App Tests**:
   - `npm run build` của SDK Playground tiếp tục thành công không lỗi type.

---

## 8. Kết luận Bước Zero

Hệ thống hiện tại có cấu trúc module phân tách sạch sẽ, decoupling qua Riverpod và Bridge Protocol trừu tượng. Việc nâng cấp lên mô hình Registry & No-Code hoàn toàn khả thi theo hướng **mở rộng bổ sung (additive-only)** mà không phải sửa lại hay phá vỡ bất kỳ thành phần nào đang hoạt động.
Sẵn sàng bước vào **PHASE 1: Dynamic Registry + Catalog**.
