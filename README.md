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

## Bảng cổng dịch vụ (TV1 & TV2)

| Dịch vụ | Container Name | Cổng Host -> Container | Mô tả |
|---|---|---|---|
| API Gateway & Load Balancer | `api-gateway-proxy-server` | `80:80`, `8080:80` | Cổng vào chính cho Web & API |
| Web Server Node 1 | `web-frontend-server` | `8081:80` | Instance Web 1 (Round Robin) |
| Web Server Node 2 | `web-frontend-server-2` | `8082:80` | Instance Web 2 (Round Robin) |
| Application Backend Server | `application-backend-server` | `5000:5000`, `8085:5000` | Flask RESTful API Backend |
| Relational Database Server | `relational-database-server` | `3306:3306` | MariaDB RDBMS |

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

## Hướng dẫn chạy và kiểm thử nhanh (PowerShell)

### 1. Build và khởi chạy cụm dịch vụ TV1
```powershell
docker compose up -d --build
docker compose ps
```

### 2. Kiểm tra Web & Blog qua API Gateway
```powershell
curl.exe -I http://localhost:8080/
curl.exe -I http://localhost:8080/blog/
curl.exe -I http://localhost:8080/blog/blog1.html
curl.exe -I http://localhost:8080/blog/blog2.html
curl.exe -I http://localhost:8080/blog/blog3.html
```

### 3. Kiểm chứng Load Balancing (Round Robin)
Chạy lặp 6 lần liên tiếp để quan sát `web-frontend-server-1` và `web-frontend-server-2` luân phiên phản hồi:
```powershell
1..6 | ForEach-Object { curl.exe -s http://localhost:8080/node }
```
Hoặc kiểm tra qua HTTP Response Header (`X-Served-By` và `X-Upstream-Addr`):
```powershell
1..4 | ForEach-Object { curl.exe -sI http://localhost:8080/ | Select-String "X-Served-By|X-Upstream-Addr" }
```

### 4. Kiểm tra định tuyến API Gateway tới Backend (TV2)
```powershell
curl.exe -i http://localhost:8080/gateway-health
curl.exe -i http://localhost:8080/api/hello
curl.exe -i http://localhost:8080/api/student
curl.exe -i http://localhost:8080/api/students-db
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

## Minh chứng (Evidence)
Kết quả kiểm thử và ảnh chụp màn hình của TV1 được lưu tại: `docs/evidence/tv1/`
