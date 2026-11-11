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

## Bảng cổng và IP trên cloud-net

| Dịch vụ | Container | IP | Alias | Host → Container |
|---|---|---|---|---|
| Gateway | api-gateway-proxy-server | 10.10.10.60 | proxy | 80:80 |
| Web 1 | web-frontend-server | 10.10.10.10 | web, web-frontend-server1 | 8080:80 |
| Web 2 | web-frontend-server-2 | 10.10.10.11 | web2, web-frontend-server2 | 8082:80 |
| Flask | application-backend-server | 10.10.10.20 | app-server, app-backend | 8085:5000, 5000:5000 |
| MariaDB | relational-database-server | 10.10.10.50 | db | 3306:3306 |
| Keycloak | authentication-identity-server | 10.10.10.40 | keycloak | 8081:8080 |
| MinIO | object-storage-server | 10.10.10.30 | minio | 9000:9000, 9001:9001 |
| Bind9 | internal-dns-server | 10.10.10.53 | dns-server, ns | 1053:53/udp, 1053:53/tcp |

Subnet Docker là `10.10.10.0/24`. Tám dịch vụ trên bind `127.0.0.1` khi chạy local. Đặt `GATEWAY_HTTP_BIND=0.0.0.0` khi truy cập Gateway qua IP public EC2, đồng thời đặt `PUBLIC_BASE_URL` theo origin thực tế. Keycloak dùng realm `myminicloud` và client `myminicloud-app` hiện có của nhóm, admin qua `http://127.0.0.1:8081/auth/admin/`.

Monitoring của nhóm vẫn gồm Node Exporter `9100`, cAdvisor `8083`, Prometheus `9090` và Grafana `3000`. Các dịch vụ này nhận IP từ dải `10.10.10.128/25`.

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

## Phạm vi công việc Thành viên 4 (TV4 - MSSV: 52300183)

- **Monitoring Server (`monitoring-prometheus-server`, `monitoring-node-exporter-server`, `monitoring-cadvisor-server`)**:
  - Prometheus `v2.54.1` scrape 4 job: `node`, `web`, `cadvisor`, `prometheus` (cấu hình tại `monitoring-prometheus-server/prometheus.yml`).
  - **Mục mở rộng 7**: target `web-frontend-server:80` (job `web`) đã UP nhờ endpoint `/metrics` thêm vào `web-frontend-server/conf.default`.
- **Grafana Dashboard (`monitoring-grafana-dashboard-server`)**:
  - Datasource Prometheus và dashboard được nạp tự động (provisioning), không cần cấu hình tay.
  - **Mục mở rộng 8**: dashboard **System Health of 52300183** gồm CPU Usage (%), Memory Usage, Network Traffic (+ 2 biểu đồ theo container từ cAdvisor).
  - Đăng nhập mặc định `admin / admin` (đổi qua biến `GRAFANA_ADMIN_PASSWORD`).
- **Mục 10 - Ping thông mạng** và **kiểm thử tải** bằng ApacheBench: thư mục `scripts/`.
- **Báo cáo & kịch bản video**: `docs/tv4-report-monitoring.md`, `docs/tv4-video-demo-script.md`.

### Kiểm thử phần TV4 (Git Bash / WSL / Linux)
```bash
docker compose up -d --build

# Prometheus: Status -> Targets, 4 target phải UP
#   http://localhost:9090/targets      (truy vấn thử: node_cpu_seconds_total)
curl http://localhost:8080/metrics      # endpoint /metrics của web

# Grafana: http://localhost:3000  (admin / admin) -> thư mục MyMiniCloud -> System Health of 52300183

# Mục 10: ping toàn bộ server trong cloud-net
./scripts/ping-test.sh | tee docs/evidence/tv4/ping-test.txt

# Tạo tải để xem dashboard biến động (20.000 request, 50 kết nối đồng thời)
./scripts/load-test.sh http://localhost/ 20000 50

# Đổi MSSV trên dashboard (nếu cần)
./scripts/set-mssv.sh <MSSV> && docker restart monitoring-grafana-dashboard-server
```

Ghi chú: Node Exporter chạy trong container nên biểu đồ *Network Traffic* chỉ phản ánh card mạng của chính container đó;
lưu lượng của từng container (gateway, web...) xem ở biểu đồ **Container Network RX** (cAdvisor).

## Hướng dẫn chạy và kiểm thử nhanh (PowerShell)

### 1. Cấu hình và khởi chạy

Sao chép `.env.example` thành `.env`, điền `MARIADB_ROOT_PASSWORD`, `KEYCLOAK_ADMIN_PASSWORD` và `MINIO_ROOT_PASSWORD`. Khi dùng lại volume, điền đúng mật khẩu của volume đó. Keycloak dùng tài khoản demo và realm từ file export hiện có của nhóm.

### Build và khởi chạy toàn bộ cụm
```powershell
docker compose up -d --build
docker compose ps
```

### 2. Kiểm tra Web & Blog qua API Gateway
```powershell
curl.exe -I http://localhost/
curl.exe -I http://localhost/blog/
curl.exe -I http://localhost/blog/blog1.html
curl.exe -I http://localhost/blog/blog2.html
curl.exe -I http://localhost/blog/blog3.html
```

### 3. Kiểm chứng Load Balancing (Round Robin)
Chạy lặp 6 lần liên tiếp để quan sát `web-frontend-server1` và `web-frontend-server2` luân phiên phản hồi:
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
curl.exe -i http://localhost/api/students-db
```

### 5. Kiểm tra trực tiếp Flask Backend & MariaDB (TV2)
```powershell
# Gọi trực tiếp Flask Backend qua cổng host 5000 hoặc 8085
curl.exe http://localhost:5000/hello
curl.exe http://localhost:5000/student
curl.exe http://localhost:5000/students-db

# Kiểm tra dữ liệu trực tiếp trong MariaDB container
docker compose exec relational-database-server sh -c 'MYSQL_PWD="$MARIADB_ROOT_PASSWORD" mariadb -uroot -e "USE studentdb; SELECT * FROM students;"'
```

## Minh chứng (Evidence)
Kết quả kiểm thử và ảnh chụp màn hình của TV1 được lưu tại: `docs/evidence/tv1/`

Minh chứng của TV4 (ping, load test, ảnh Prometheus/Grafana) được lưu tại: `docs/evidence/tv4/`

## Kiểm thử TV1

Trang chủ có ba bài DTN kèm ba SVG. Các bài giữ ảnh NASA và liên kết về trang chủ. Nginx Gateway dùng `api-gateway-proxy-server/conf.default`, được COPY bởi Dockerfile của Gateway.

Chạy bộ kiểm thử Web, nội dung, API sinh viên và tám lượt Round Robin từ PowerShell.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/tv1/verify-tv1.ps1 -BaseUrl http://127.0.0.1 -OutputDirectory .local/tv1-http
```

Dùng thư mục output mới cho mỗi lượt để giữ bằng chứng cũ. Kết quả bắt buộc phải PASS. Kiểm tra thêm DNS và hai node trực tiếp.

```powershell
docker compose exec -T internal-dns-server dig '@127.0.0.1' web-frontend-server.cloud.local +short
docker compose exec -T internal-dns-server dig +tcp '@127.0.0.1' app-backend.cloud.local +short
curl.exe http://127.0.0.1:8080/node
curl.exe http://127.0.0.1:8082/node
```

Trong buổi kiểm thử có thể tạm dừng Flask, khởi động lại Gateway và kiểm tra trang chủ trả HTTP 200, các đường `/api/hello`, `/student`, `/student/`, `/students-db` trả HTTP 503 với JSON `backend_unavailable`. Bật lại Flask và kiểm tra các tuyến API trở về HTTP 200.

Đề bài còn yêu cầu publish ít nhất một image tùy chỉnh lên Docker Hub và deploy toàn bộ cụm lên EC2 Ubuntu. Hai bước đó cần URL và bằng chứng thực thi riêng trong phụ lục.
