import { Command } from 'commander';
import { buildProject } from './commands/build.js';
import { createProject } from './commands/create.js';
import { devServer } from './commands/dev.js';
import { runDoctor } from './commands/doctor.js';
import { runSimulator } from './commands/simulator.js';
import { uploadProject } from './commands/upload.js';

const program = new Command();

program
  .name('miniapp')
  .description('SuperApp Mini App Developer CLI: Create, Dev, Build, and Upload')
  .version('1.0.4');

program
  .command('create <project-name>')
  .description('Khởi tạo một dự án Mini App mới từ mẫu chuẩn SuperApp')
  .option('-t, --template <template>', 'Mẫu giao diện (react | vanilla-ts)', 'vanilla-ts')
  .action((projectName, options) => {
    createProject(projectName, options);
  });

program
  .command('dev')
  .description('Khởi chạy Development Server và mở Browser Simulator')
  .option('-p, --port <port>', 'Cổng Vite dev server', '3000')
  .option('-s, --simulator-port <port>', 'Cổng Browser Simulator', '5175')
  .option('--open', 'Tự động mở trình duyệt')
  .option('--no-simulator', 'Không khởi chạy Browser Simulator kèm theo')
  .action((options) => {
    devServer(options);
  });

program
  .command('simulator')
  .description('Khởi chạy Browser Simulator & DevTools độc lập')
  .option('-p, --port <port>', 'Cổng Browser Simulator', '5175')
  .option('-u, --app-url <url>', 'Địa chỉ Mini App đang chạy để kết nối', 'http://localhost:3000')
  .action((options) => {
    runSimulator(options);
  });

program
  .command('build')
  .description('Đóng gói Mini App thành bundle sẵn sàng xuất bản')
  .option('-o, --out-dir <dir>', 'Thư mục xuất kết quả build', 'dist')
  .action((options) => {
    buildProject(options);
  });

program
  .command('upload')
  .description('Tải lên bản nháp hoặc gửi xét duyệt Mini App lên Dynamic Registry Backend')
  .option('-r, --registry <url>', 'Địa chỉ backend registry API', 'http://localhost:3000')
  .option('-t, --tenant-id <tenantId>', 'Mã định danh Tenant', 'tenant_001')
  .option('-a, --actor-id <actorId>', 'Mã người thực hiện tải lên', 'dev_partner_001')
  .option('--submit', 'Gửi trực tiếp vào hàng đợi xét duyệt (SUBMITTED)')
  .option('-n, --notes <notes>', 'Ghi chú thay đổi (changelog)')
  .action((options) => {
    uploadProject(options);
  });

program
  .command('doctor')
  .description('Kiểm tra môi trường phát triển và kết nối dịch vụ SuperApp')
  .action(() => {
    runDoctor();
  });

program.parse(process.argv);
