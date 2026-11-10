# Báo cáo phần TV4 – Monitoring (Mục 7, Mục 8) + Mục 10 (Ping)

> Bản nháp để ghép vào báo cáo chung (Chương 3 & 4 phần Monitor, Chương 5, Phụ lục). Chỗ `[...]` là số liệu/ảnh cần điền sau khi chạy thật trên máy local và AWS EC2.

---

## Chương 3. Cấu hình & Dockerfile – phần Monitoring

Các service monitoring dùng image chính thức nên không cần Dockerfile riêng; cấu hình nằm trong `docker-compose.yml` (khối TV4) và các file trong `monitoring-*`. Cả 4 container nằm trong mạng `cloud-net`, có `restart: unless-stopped` và giới hạn `mem_limit`/`cpus`.

### 3.7 Monitoring Server – Node Exporter + cAdvisor + Prometheus (`monitoring-prometheus-server`)

| Thành phần | Container | Image | Cổng host |
|---|---|---|---|
| Node Exporter | monitoring-node-exporter-server | prom/node-exporter:v1.8.2 | 9100 |
| cAdvisor (bổ sung) | monitoring-cadvisor-server | gcr.io/cadvisor/cadvisor:v0.49.1 | 8083 |
| Prometheus | monitoring-prometheus-server | prom/prometheus:v2.54.1 | 9090 |

`monitoring-prometheus-server/prometheus.yml`:

```yaml
global:
  scrape_interval: 15s
scrape_configs:
  - job_name: 'node'                     # Mục 7 cơ bản
    static_configs:
      - targets: ['monitoring-node-exporter-server:9100']
  - job_name: 'web'                      # Mục 7 mở rộng
    static_configs:
      - targets: ['web-frontend-server:80']
  - job_name: 'cadvisor'                 # bổ sung: metric theo container
    static_configs:
      - targets: ['monitoring-cadvisor-server:8080']
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
```

Nginx tĩnh không có sẵn `/metrics`, nên đã thêm vào `web-frontend-server/conf.default`:

```nginx
location = /metrics {
    default_type text/plain;
    return 200 "# HELP web_up Web frontend is up\n# TYPE web_up gauge\nweb_up 1\n";
}
```

Endpoint này trả về một metric hợp lệ (`web_up 1`) để Prometheus xác nhận web-frontend-server còn sống (target **UP**).

### 3.8 Grafana Dashboard (`monitoring-grafana-dashboard-server`)

| Container | Image | Cổng |
|---|---|---|
| monitoring-grafana-dashboard-server | grafana/grafana:11.2.0 | 3000 |

- `provisioning/datasources/prometheus.yml`: tự khai báo datasource Prometheus (`http://monitoring-prometheus-server:9090`).
- `provisioning/dashboards/dashboards.yml` + `dashboards/system-health.json`: tự nạp dashboard **System Health of 52300183** vào thư mục *MyMiniCloud*.
- Dữ liệu Grafana và Prometheus được lưu bền qua volume `grafana_data`, `prometheus_data`.
- Đăng nhập mặc định `admin / admin` (đổi qua biến `GRAFANA_ADMIN_PASSWORD`).

---

## Chương 4. Demo & kiểm thử

Khởi động toàn hệ thống: `docker compose up -d --build` → `docker compose ps`.

### 4.7 Kiểm thử Prometheus
1. Mở `http://localhost:9090` → **Status → Targets**.
2. Kết quả mong đợi: job `node`, `web`, `cadvisor`, `prometheus` đều **UP**.
3. Tab **Graph**, truy vấn `node_cpu_seconds_total` hiển thị dữ liệu.

Ảnh: `[ảnh Targets UP]`, `[ảnh truy vấn node_cpu_seconds_total]`.

### 4.8 Kiểm thử Grafana
1. Mở `http://localhost:3000`, đăng nhập `admin / admin`.
2. Datasource Prometheus đã có sẵn (Connections → Data sources).
3. Mở dashboard **System Health of 52300183**:

| Biểu đồ | Metric |
|---|---|
| CPU Usage (%) | `node_cpu_seconds_total` |
| Memory Usage | `node_memory_MemAvailable_bytes` |
| Network Traffic | `node_network_receive_bytes_total` |
| Container CPU (%) – bổ sung | `container_cpu_usage_seconds_total` |
| Container Network RX – bổ sung | `container_network_receive_bytes_total` |

4. (Tùy chọn) Import dashboard "Node Exporter Full" (ID 1860 trên grafana.com).

Ảnh: `[ảnh dashboard System Health]`.

### 4.10 Kiểm tra thông mạng (Ping)
Lệnh: `./scripts/ping-test.sh | tee docs/evidence/tv4/ping-test.txt` – ping 3 gói tới từng container trong `cloud-net`, sau đó kiểm tra HTTP các cổng chính từ host.

| Đích | Kết quả | RTT trung bình |
|---|---|---|
| api-gateway-proxy-server | [OK/FAIL] | [... ms] |
| web-frontend-server | [...] | [...] |
| web-frontend-server-2 | [...] | [...] |
| application-backend-server | [...] | [...] |
| relational-database-server | [...] | [...] |
| authentication-identity-server | [...] | [...] |
| object-storage-server | [...] | [...] |
| internal-dns-server | [...] | [...] |
| monitoring-node-exporter-server | [...] | [...] |
| monitoring-cadvisor-server | [...] | [...] |
| monitoring-prometheus-server | [...] | [...] |
| monitoring-grafana-dashboard-server | [...] | [...] |

### 4.11 Kiểm thử tải (bổ sung)
Lệnh: `./scripts/load-test.sh http://localhost:8080/ 20000 50` (ApacheBench: 20.000 request, 50 kết nối đồng thời qua API Gateway – Round Robin tới 2 web), vừa chạy vừa quan sát dashboard. Log lưu tại `docs/evidence/tv4/load-test-*.txt`.

| Chỉ số | Khi rảnh | Khi có tải |
|---|---|---|
| CPU host (%) | [...] | [...] |
| Network receive của gateway (bytes/s) | [...] | [...] |
| Memory available | [...] | [...] |
| Requests/giây (ab) | – | [...] |
| Request lỗi | – | [...] |

Nhận xét (điền theo số liệu thật): `[...]`

### Kết quả phần mở rộng (theo yêu cầu "ghi rõ đã làm được bao nhiêu")

| Mục | Yêu cầu mở rộng | Trạng thái | Điểm |
|---|---|---|---|
| 7 – Prometheus | Thêm target `web-frontend-server:80`, target UP | [Hoàn thành / Chưa] | 0,5 |
| 8 – Grafana | Dashboard "System Health of MSSV" ≥ 3 biểu đồ (CPU, Memory, Network), lưu và chụp ảnh | [Hoàn thành / Chưa] | 0,5 |

---

## Chương 5. Đánh giá & phân tích (phần Monitoring)

**Ưu điểm**
- Triển khai nhanh bằng Compose; datasource và dashboard nạp tự động, chạy lại là có sẵn, dữ liệu bền qua volume.
- Thấy được CPU, RAM, mạng của máy chủ và của từng container theo thời gian thực, tiện kiểm chứng khả năng chịu tải và Round Robin.

**Khó khăn**
- Nginx tĩnh không có endpoint `/metrics`, nên target `web` báo DOWN (404) cho đến khi thêm `location = /metrics`.
- Node Exporter chạy trong container nên *Network Traffic* chỉ phản ánh card mạng của chính container này, không thấy lưu lượng của gateway/web khi tạo tải. Giải pháp: thêm cAdvisor để xem network/CPU theo từng container.
- Trên Docker Desktop (Windows/Mac), số liệu host là của máy ảo Linux bên trong Docker. `[bổ sung khó khăn thực tế]`
- Khi chưa chạy hệ thống, `load-test.sh` không kết nối được; script đã được sửa để báo lỗi sớm thay vì ghi file kết quả rỗng.

**Hướng mở rộng**
- Thêm Alertmanager để cảnh báo; exporter cho MariaDB và Nginx (stub_status) thay cho endpoint `/metrics` giả lập.
- Loki + Promtail cho log tập trung.
- Bảo mật: HTTPS, đổi mật khẩu Grafana, đăng nhập Grafana qua Keycloak.

---

## Phụ lục (phần TV4)

- **Link Docker Hub**: `[do TV1 cung cấp]`
- **Link video demo**: `[dán link]`
- **Log kết quả**: `docs/evidence/tv4/ping-test.txt`, `docs/evidence/tv4/load-test-*.txt`
- **File cấu hình**: `docker-compose.yml` (khối TV4), `monitoring-prometheus-server/prometheus.yml`, `monitoring-grafana-dashboard-server/dashboards/system-health.json`, `web-frontend-server/conf.default` (endpoint `/metrics`)
- **Script**: `scripts/ping-test.sh`, `scripts/load-test.sh`, `scripts/set-mssv.sh`
- **Truy vấn PromQL**:
  - CPU: `100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[1m])) * 100)`
  - Memory: `(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100`
  - Network: `sum(rate(node_network_receive_bytes_total{device!="lo"}[1m]))`
  - Container CPU: `sum by (name) (rate(container_cpu_usage_seconds_total{name=~".+"}[1m])) * 100`
  - Container Network: `sum by (name) (rate(container_network_receive_bytes_total{name=~".+"}[1m]))`
