# Kịch bản quay Video Demo (TV4)

Thời lượng đề xuất: 5–7 phút. Quay màn hình + thu giọng (OBS Studio / Zoom). Nên quay trên AWS EC2 thật (có thể mở đầu bằng local).

## Chuẩn bị trước khi quay
- [ ] Dashboard đã mang tên MSSV (mặc định 52300183; đổi bằng `./scripts/set-mssv.sh <MSSV>` rồi `docker restart monitoring-grafana-dashboard-server`)
- [ ] Chạy hệ thống: `docker compose up -d --build` (endpoint `/metrics` của web đã có sẵn trong `web-frontend-server/conf.default`)
- [ ] Mở sẵn tab: web (`:8080`), Prometheus (`:9090/targets`), Grafana (`:3000`), terminal
- [ ] EC2 Security Group mở cổng 80, 8080, 9090, 3000

## Cảnh quay

| # | Thời gian | Nội dung | Lệnh / thao tác | Lời thoại gợi ý |
|---|-----------|----------|-----------------|-----------------|
| 1 | 0:00–0:30 | Giới thiệu | Sơ đồ kiến trúc | "MyMiniCloud gồm 9 loại server chạy trong cloud-net, có thêm cAdvisor để giám sát container." |
| 2 | 0:30–1:15 | Container đang chạy | `docker compose ps` | "Tất cả service đang chạy." |
| 3 | 1:15–2:15 | Ping thông mạng (Mục 10) | `./scripts/ping-test.sh` | "Các container ping được nhau theo tên, packet loss 0%." |
| 4 | 2:15–3:15 | Prometheus (Mục 7) | `:9090/targets`, truy vấn `node_cpu_seconds_total` | "Các target node, web, cadvisor đều UP, metric hiển thị." |
| 5 | 3:15–4:15 | Grafana (Mục 8) | Mở dashboard System Health of MSSV | "3 biểu đồ CPU, Memory, Network lấy dữ liệu từ Prometheus, kèm 2 biểu đồ theo container." |
| 6 | 4:15–6:00 | Tạo tải | `./scripts/load-test.sh http://localhost:8080/ 20000 50` song song với dashboard | "Khi có tải, CPU của host và của container gateway/web, cùng traffic mạng container tăng rõ rệt." |
| 7 | 6:00–7:00 | Kết luận | – | "Hệ thống giám sát giúp quan sát và đánh giá khả năng chịu tải." |

## Mẹo
- Phóng to chữ terminal; Grafana auto-refresh 5s, time range 15 phút.
- Chụp ảnh cảnh 3, 4, 5, 6 lưu vào `docs/evidence/tv4/`.
