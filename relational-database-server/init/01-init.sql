CREATE DATABASE IF NOT EXISTS myminicloud_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE myminicloud_db;

CREATE TABLE IF NOT EXISTS students (
    id INT AUTO_INCREMENT PRIMARY KEY,
    student_code VARCHAR(20) NOT NULL UNIQUE,
    full_name VARCHAR(100) NOT NULL,
    role_code VARCHAR(10) NOT NULL,
    responsibility VARCHAR(255) NOT NULL,
    email VARCHAR(120) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO students (student_code, full_name, role_code, responsibility, email) VALUES
('SV001', 'Nguyễn Xuân Bằng', 'TV1', 'Web Server, Blog, Nginx API Gateway, Load Balancing, Docker Hub & AWS EC2', 'bang.nx@myminicloud.local'),
('SV002', 'Thành viên 2', 'TV2', 'Flask Application Backend API & MariaDB Relational Database', 'tv2@myminicloud.local'),
('SV003', 'Thành viên 3', 'TV3', 'Keycloak IAM, MinIO Object Storage & Bind9 Internal DNS', 'tv3@myminicloud.local'),
('SV004', 'Thành viên 4', 'TV4', 'Prometheus Monitoring, Node Exporter & Grafana Dashboard', 'tv4@myminicloud.local')
ON DUPLICATE KEY UPDATE
    full_name = VALUES(full_name),
    responsibility = VALUES(responsibility);
