# final_projects
# Hệ thống quản lý đề tài sinh viên

Đồ án môn **Lập trình Web** — quản lý toàn bộ quy trình đăng ký, duyệt, phân công, phản biện và công bố kết quả đề tài trong khoa CNTT.

## 1. Công nghệ sử dụng

| Thành phần | Công nghệ |
|---|---|
| Backend | Java 21, Spring Boot 4.1.1 (Spring MVC, Spring Data JPA, Spring Security, Spring Validation) |
| Frontend | Thymeleaf (server-side rendering) + Bootstrap 5 + Bootstrap Icons |
| Cơ sở dữ liệu | MySQL 8.0 (yêu cầu tối thiểu 8.0.16 vì có dùng `CHECK` constraint) |
| Build tool | Maven (dùng qua `mvnw`, không cần cài Maven riêng) |

## 2. Yêu cầu môi trường trước khi bắt đầu

- **JDK 21 trở lên** (khuyến nghị 21 hoặc mới hơn). Kiểm tra: `java -version`
- **MySQL Server 8.0.16+** đã cài và biết mật khẩu `root`. Kiểm tra: `mysql --version`
- **Git** để lấy code từ repo chung của nhóm
- IDE: VS Code (extension **Extension Pack for Java** + **Spring Boot Extension Pack**) hoặc IntelliJ IDEA

## 3. Cài đặt lần đầu

### 3.1. Lấy code

```bash
git clone <link-repo-cua-nhom>
cd quanlydetai
```

### 3.2. Tạo database

Trong thư mục chứa 3 file SQL của nhóm (`01_schema_mysql.sql`, `02_logic_mysql.sql`, `03_views_seed_mysql.sql`), chạy **đúng thứ tự**:

```bash
mysql -u root -p --default-character-set=utf8mb4 -e "source 01_schema_mysql.sql"
mysql -u root -p --default-character-set=utf8mb4 -e "source 02_logic_mysql.sql"
mysql -u root -p --default-character-set=utf8mb4 -e "source 03_views_seed_mysql.sql"
```

Kiểm tra đã tạo đủ: **19 bảng, 4 view, 31 trigger**.

```bash
mysql -u root -p -e "SELECT (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='quanlydetai' AND table_type='BASE TABLE') AS bang, (SELECT COUNT(*) FROM information_schema.views WHERE table_schema='quanlydetai') AS view_count, (SELECT COUNT(*) FROM information_schema.triggers WHERE trigger_schema='quanlydetai') AS trigger_count;"
```

### 3.3. Tạo dữ liệu tối thiểu để chạy thử

Database mới tạo đang trống. Cần ít nhất 1 bộ môn, 1 GV, 1 Trưởng khoa để form "Tạo đợt" hoạt động:

```sql
INSERT INTO BO_MON (Ma_Bo_Mon, Ten_Bo_Mon) VALUES ('ATTT', 'An Toan Thong Tin');
INSERT INTO GV (Ma_GV, Ho_Ten, Email, Ma_Bo_Mon) VALUES ('GV01', 'Nguyen Van A', 'a@hcmute.edu.vn', 'ATTT');
INSERT INTO TRUONG_KHOA (Ma_GV) VALUES ('GV01');
```

### 3.4. Cấu hình kết nối database

Mở `src/main/resources/application.properties`, kiểm tra đúng nội dung:

```properties
spring.application.name=quanlydetai

spring.datasource.url=jdbc:mysql://localhost:3306/quanlydetai?useUnicode=true&characterEncoding=UTF-8&serverTimezone=Asia/Ho_Chi_Minh
spring.datasource.username=root
spring.datasource.password=${DB_PASSWORD}

spring.jpa.hibernate.ddl-auto=none
spring.jpa.open-in-view=false
spring.thymeleaf.cache=false
```

**Không đổi `ddl-auto` khác `none`.** Database do file SQL của nhóm quản lý (kèm trigger ràng buộc nghiệp vụ) — để Hibernate tự tạo/sửa bảng sẽ phá hỏng toàn bộ logic đó.

Mật khẩu MySQL lấy từ biến môi trường, **không ghi thẳng vào file** (file này nằm trong Git chung).

### 3.5. Chạy ứng dụng

Mỗi lần mở terminal mới, đặt biến mật khẩu trước khi chạy:

**Windows (PowerShell):**
```powershell
$env:DB_PASSWORD="mat_khau_root_cua_ban"
.\mvnw.cmd spring-boot:run
```

**macOS/Linux:**
```bash
export DB_PASSWORD="mat_khau_root_cua_ban"
./mvnw spring-boot:run
```

Thấy dòng `Started QuanlydetaiApplication` là thành công. Mở trình duyệt: **http://localhost:8080**

## 4. Tài khoản để test

Hiện dùng tài khoản tạm trong bộ nhớ (chưa nối với bảng `TAI_KHOAN` thật), mật khẩu đều là `123456`:

| Tài khoản | Vai trò |
|---|---|
| `sv01` | Sinh viên |
| `gv01` | Giáo viên |
| `truongkhoa` | Giáo viên **kiêm** Trưởng khoa |
| `admin` | Quản trị hệ thống |

## 5. Cấu trúc thư mục

```
quanlydetai/
├── src/main/java/com/example/quanlydetai/
│   ├── config/          # SecurityConfig (đăng nhập, phân quyền)
│   ├── controller/      # Xử lý request, trả về template
│   ├── dto/             # Đối tượng nhận dữ liệu từ form
│   ├── entity/          # Ánh xạ JPA tới bảng/view trong DB
│   └── repository/      # Spring Data JPA repository
├── src/main/resources/
│   ├── templates/
│   │   ├── layout/      # base.html (khung chung) + fragments.html (sidebar, topbar)
│   │   ├── auth/        # Trang đăng nhập
│   │   ├── sv/, gv/, truongkhoa/, admin/   # Trang riêng theo vai trò
│   ├── static/css/      # CSS tùy chỉnh
│   └── application.properties
└── pom.xml
```

**Quy ước đường dẫn (bắt buộc tuân theo khi thêm trang mới):** mỗi controller đặt `@RequestMapping` theo đúng tiền tố vai trò — `/sv/**`, `/gv/**`, `/truong-khoa/**`, `/admin/**` — vì `SecurityConfig` phân quyền dựa trên các tiền tố này. Trang không theo đúng tiền tố sẽ không được chặn đúng vai trò.

## 6. Đã làm xong

- [x] Khung layout dùng chung (sidebar + topbar), menu tự ẩn/hiện theo vai trò
- [x] Đăng nhập/đăng xuất, phân quyền tầng backend theo `hasRole()` (không chỉ ẩn menu)
- [x] Trang **Danh sách đề tài đã công bố** (Sinh viên) — đọc dữ liệu thật qua view `VW_DE_TAI_DA_CONG_BO`
- [x] Trang **Quản lý đợt đăng ký** (Trưởng khoa) — form tạo đợt, validate đúng theo `CHECK constraint` của DB (khung giờ GV/SV, hạn GVPB, ngày báo cáo hội đồng theo loại đợt)

## 7. Chưa làm / cần làm tiếp

- [ ] Đăng nhập thật từ bảng `TAI_KHOAN` (hiện đang dùng tài khoản tạm trong bộ nhớ)
- [ ] Sinh viên: Nhóm của tôi, Nộp báo cáo, Xem kết quả
- [ ] Giáo viên: Đề xuất đề tài, Chấm điểm
- [ ] Trưởng khoa: Duyệt & công bố đề tài, Phân công GVPB/hội đồng, Công bố kết quả
- [ ] Admin: Quản lý tài khoản
- [ ] Thông báo hệ thống
- [ ] Mã đợt (`Ma_Dot`) nên tự sinh thay vì bắt nhập tay (tránh trùng/ghi đè)
- [ ] Bổ sung `@Valid` + annotation validate chuẩn của Spring (`@NotBlank`...) cho các form còn lại — phục vụ luôn nội dung Chương 2 báo cáo

## 8. Lưu ý khi code chung

- Backend trả lỗi nghiệp vụ qua `SIGNAL SQLSTATE '45000'` từ trigger MySQL (ví dụ: "Một nhóm tối đa 3 sinh viên"). Khi gặp `DataIntegrityViolationException`, lấy message gốc để hiển thị cho người dùng thay vì để lộ lỗi SQL thô.
- Các bảng có khóa chính ghép (`GVHD_DETAI`, `GVPB_DETAI`, `THANH_VIEN_NHOM`, `THANHVIEN_HOIDONG`, `HOI_DONG_DE_TAI`) cần dùng `@IdClass` hoặc `@EmbeddedId` khi tạo Entity.
- View chỉ đọc (`VW_...`) nên đánh dấu Entity bằng `@Immutable` (Hibernate) để tránh gọi nhầm `save()`.
