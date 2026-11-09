# MyMiniCloud

Hệ thống mô phỏng hạ tầng Cloud thu nhỏ sử dụng Docker Compose.

## Phạm vi công việc Thành viên 1 (TV1 - Nguyễn Xuân Bằng)

- **Web Frontend Server (`web-frontend-server`, `web-frontend-server-2`)**:
  - Xây dựng từ `nginx:1.30.6-alpine`.
  - Trang chủ liệt kê trực tiếp 3 bài blog công nghệ kèm hình minh họa SVG.
  - Phản hồi header `X-Served-By` và endpoint `/node` để kiểm chứng cân bằng tải.
- **API Gateway & Load Balancer (`api-gateway-proxy-server`)**:
  - Cân bằng tải **Round Robin** giữa 2 instance `web-frontend-server:80` và `web-frontend-server-2:80`.
  - Định tuyến `/api/*`, `/student`, `/students-db` tới `application-backend-server:5000` (Flask Backend của TV2).
  - Sử dụng Docker DNS (`127.0.0.11`) và xử lý lỗi `@backend_unavailable` giúp Gateway hoạt động độc lập ngay cả khi service của TV2 chưa khởi chạy.
- **Tích hợp Docker Compose & Mạng nội bộ `cloud-net`**.

## Bảng cổng & IP tĩnh dịch vụ (TV1, TV2 & TV3 trên mạng `cloud-net` `10.10.10.0/24`)

| Dịch vụ | Container Name | IP tĩnh (`cloud-net`) | Alias / DNS (`*.cloud.local`) | Cổng Host -> Container | Mô tả |
|---|---|---|---|---|---|
| API Gateway & Load Balancer | `api-gateway-proxy-server` | `10.10.10.60` | `proxy` | `80:80` | Cổng vào chính (`http://localhost/`) |
| Web Server Node 1 | `web-frontend-server` | `10.10.10.10` | `web`, `web-frontend-server1` | `8080:80` | Instance Web 1 (`http://localhost:8080/`) |
| Web Server Node 2 | `web-frontend-server-2` | `10.10.10.11` | `web2`, `web-frontend-server2` | `8082:80` | Instance Web 2 (Round Robin) |
| Application Backend Server | `application-backend-server` | `10.10.10.20` | `app-server`, `app-backend` | `8085:5000`, `5000:5000` | Flask RESTful API Backend |
| Relational Database Server | `relational-database-server` | `10.10.10.50` | `db` | `3306:3306` | MariaDB RDBMS (`minicloud` & `studentdb`) |
| Authentication Identity Server | `authentication-identity-server` | `10.10.10.40` | `keycloak` | `8081:8080` | Keycloak OIDC Server (`admin/admin`, RAM `1g`) |
| Object Storage Server | `object-storage-server` | `10.10.10.30` | `minio` | `9000:9000`, `9001:9001` | MinIO S3 API (`9000`) & Console (`9001`) |
| Internal DNS Server | `internal-dns-server` | `10.10.10.53` | `dns-server`, `ns` | `1053:53/udp`, `1053:53/tcp` | Bind9 DNS Server (Zone `cloud.local`) |

## Phạm vi công việc Thành viên 2 (TV2 - Bùi Huy Báu - MSSV: 52300181)

- **Application Backend Server (`application-backend-server`)**:
  - Xây dựng từ `python:3.11-alpine`.
  - Cung cấp API cơ bản: `GET /hello` và xác thực OIDC `GET /secure`.
  - **Mục mở rộng 2**: `GET /student` đọc danh sách 5 sinh viên từ file `students.json`.
  - **Mục mở rộng 3 & Nâng cao**: Kết nối CSDL MariaDB, cung cấp trọn bộ CRUD:
    - `GET /students-db`: Truy vấn danh sách sinh viên từ MariaDB (SELECT).
    - `POST /students-db`: Thêm mới sinh viên vào MariaDB (INSERT).
    - `PUT /students-db/<student_id>`: Cập nhật thông tin sinh viên (UPDATE).
    - `DELETE /students-db/<student_id>`: Xóa sinh viên khỏi MariaDB (DELETE).
- **Relational Database Server (`relational-database-server`)**:
  - Sử dụng `mariadb:11`.
  - Tự động nạp schema & data qua volume init: CSDL `minicloud` (bảng `notes`) và CSDL `studentdb` (bảng `students`).
  - Dữ liệu bền vững qua volume `mariadb_data`.

## Phạm vi công việc Thành viên 3 (TV3 - Nguyễn Hải Đăng)

- **Authentication & Identity Server (`authentication-identity-server` - Keycloak)**:
  - Sử dụng `quay.io/keycloak/keycloak:latest` với cờ `start-dev --import-realm`, cổng `8081:8080` (tài khoản quản trị `admin` / `admin`).
  - **Mục mở rộng 4**: Tự động import Realm `realm_sv001` từ `authentication-identity-server/realm-export.json`, gồm:
    - 2 tài khoản người dùng: `sv01` (mật khẩu `sv01`) và `sv02` (mật khẩu `sv02`).
    - Public Client `flask-app` (bật Direct Access Grants) để lấy JWT Access Token từ Token Endpoint và gọi API bảo mật `/secure` (hoặc `/api/secure`) trên Flask Backend.
- **Object Storage Server (`object-storage-server` - MinIO)**:
  - Sử dụng `minio/minio:latest`, cổng API `9000:9000` và Console `9001:9001` (`minioadmin` / `minioadmin`).
  - **Mục 5 Cơ bản & Mở rộng**:
    - Bucket `demo` chứa file `index.html`.
    - Bucket `profile-pics` (public policy) chứa ảnh đại diện `avatar.jpg` truy cập trực tiếp qua URL `http://localhost:9000/profile-pics/avatar.jpg`.
    - Bucket `documents` chứa file báo cáo PDF `report-tv3.pdf`.
- **Internal DNS Server (`internal-dns-server` - Bind9)**:
  - Sử dụng `internetsystemsconsortium/bind9:9.18`, cổng `1053:53/udp` & `1053:53/tcp`.
  - **Mục 6 Cơ bản & Mở rộng**: Cấu hình zone `cloud.local` (`named.conf.options`, `named.conf.local`, `db.cloud.local`) phân giải:
    - `web-frontend-server.cloud.local` -> `10.10.10.10`
    - `app-backend.cloud.local` -> `10.10.10.20`
    - `minio.cloud.local` -> `10.10.10.30`
    - `keycloak.cloud.local` -> `10.10.10.40`

## Hướng dẫn chạy và kiểm thử nhanh (PowerShell)

### 1. Build và khởi chạy cụm dịch vụ TV1
```powershell
docker compose up -d --build
docker compose ps
```

### 2. Kiểm tra Web & Blog (trực tiếp cổng 8080 và qua Gateway cổng 80)
```powershell
curl.exe -I http://localhost:8080/
curl.exe -I http://localhost:8080/blog/
curl.exe -I http://localhost/
curl.exe -I http://localhost/blog/blog1.html
curl.exe -I http://localhost/blog/blog2.html
curl.exe -I http://localhost/blog/blog3.html
```

### 3. Kiểm chứng Load Balancing (Round Robin qua Gateway cổng 80)
Chạy lặp 6 lần liên tiếp để quan sát `web-frontend-server-1` và `web-frontend-server-2` luân phiên phản hồi:
```powershell
1..6 | ForEach-Object { curl.exe -s http://localhost/node }
```
Hoặc kiểm tra qua HTTP Response Header (`X-Served-By` và `X-Upstream-Addr`):
```powershell
1..4 | ForEach-Object { curl.exe -sI http://localhost/ | Select-String "X-Served-By|X-Upstream-Addr" }
```

### 4. Kiểm tra định tuyến API Gateway tới Backend (TV2)
```powershell
curl.exe -i http://localhost/gateway-health
curl.exe -i http://localhost/api/hello
curl.exe -i http://localhost/api/student
curl.exe -i http://localhost/student/
curl.exe -i http://localhost/api/students-db
```

### 5. Kiểm tra trực tiếp Flask Backend & MariaDB (TV2)
```powershell
# Gọi trực tiếp Flask Backend qua cổng host 5000 hoặc 8085
curl.exe http://localhost:5000/hello
curl.exe http://localhost:5000/student
curl.exe http://localhost:5000/students-db

# Kiểm tra dữ liệu trực tiếp trong MariaDB container
docker exec -it relational-database-server mariadb -uroot -proot -e "USE studentdb; SELECT * FROM students;"
```

### 6. Kiểm tra Keycloak, MinIO & Bind9 DNS (TV3 - Nguyễn Hải Đăng)
Chạy script tự động khởi tạo bucket MinIO, lấy JWT Token Keycloak gọi `/secure`, và truy vấn DNS `cloud.local`:
```powershell
powershell -ExecutionPolicy Bypass -File .\docs\evidence\tv3\verify-tv3.ps1
```
Hoặc kiểm tra từng lệnh thủ công:
```powershell
# Kiểm tra phân giải tên miền nội bộ Bind9 (Zone cloud.local)
docker exec internal-dns-server dig '@127.0.0.1' web-frontend-server.cloud.local +short
docker exec internal-dns-server dig '@127.0.0.1' app-backend.cloud.local +short
docker exec internal-dns-server dig '@127.0.0.1' minio.cloud.local +short
docker exec internal-dns-server dig '@127.0.0.1' keycloak.cloud.local +short
```

## Minh chứng (Evidence)
- Kết quả kiểm thử của TV1: `docs/evidence/tv1/`
- Script khởi tạo & kiểm thử của TV3: `docs/evidence/tv3/verify-tv3.ps1`
