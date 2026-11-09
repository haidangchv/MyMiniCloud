-- ========================================================
-- 001_init.sql - Khởi tạo CSDL mặc định minicloud (Server Cơ bản)
-- ========================================================

CREATE DATABASE IF NOT EXISTS minicloud;
USE minicloud;

CREATE TABLE IF NOT EXISTS notes (
  id INT AUTO_INCREMENT PRIMARY KEY,
  title VARCHAR(100) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO notes (title) VALUES 
('Hello from MariaDB!'),
('Relational Database Server initialized successfully for MyMiniCloud.');
