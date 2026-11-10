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
| Node Exporter | `monitoring-node-exporter-server` | `9100:9100` | Metric CPU/RAM/Network của máy chủ |
| cAdvisor | `monitoring-cadvisor-server` | `8083:8080` | Metric theo từng container |
| Prometheus | `monitoring-prometheus-server` | `9090:9090` | Thu thập & truy vấn metric |
| Grafana | `monitoring-grafana-dashboard-server` | `3000:3000` | Dashboard System Health |

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
curl http://localhost:8081/metrics      # endpoint /metrics của web

# Grafana: http://localhost:3000  (admin / admin) -> thư mục MyMiniCloud -> System Health of 52300183

# Mục 10: ping toàn bộ server trong cloud-net
./scripts/ping-test.sh | tee docs/evidence/tv4/ping-test.txt

# Tạo tải để xem dashboard biến động (20.000 request, 50 kết nối đồng thời)
./scripts/load-test.sh http://localhost:8080/ 20000 50

# Đổi MSSV trên dashboard (nếu cần)
./scripts/set-mssv.sh <MSSV> && docker restart monitoring-grafana-dashboard-server
```

Ghi chú: Node Exporter chạy trong container nên biểu đồ *Network Traffic* chỉ phản ánh card mạng của chính container đó;
lưu lượng của từng container (gateway, web...) xem ở biểu đồ **Container Network RX** (cAdvisor).

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

Minh chứng của TV4 (ping, load test, ảnh Prometheus/Grafana) được lưu tại: `docs/evidence/tv4/`
