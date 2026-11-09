-- ========================================================
-- 002_studentdb.sql - Yêu cầu mở rộng Mục 3: CSDL studentdb
-- Phụ trách: TV 2 - Bui Huy Bau (MSSV: 52300181)
-- ========================================================

CREATE DATABASE IF NOT EXISTS studentdb CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE studentdb;

-- 1. Tạo bảng students theo đúng yêu cầu đề bài
CREATE TABLE IF NOT EXISTS students (
  id INT AUTO_INCREMENT PRIMARY KEY,
  student_id VARCHAR(10) NOT NULL UNIQUE,
  fullname VARCHAR(100) NOT NULL,
  dob DATE NOT NULL,
  major VARCHAR(50) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. Chèn dữ liệu mẫu (ít nhất 5 sinh viên thực tế)
INSERT INTO students (student_id, fullname, dob, major) VALUES
('52300181', 'Bui Huy Bau', '2003-01-01', 'Cloud Computing'),
('SV002', 'Nguyen Van A', '2003-05-15', 'Computer Science'),
('SV003', 'Tran Thi B', '2003-08-20', 'Information Technology'),
('SV004', 'Le Van C', '2002-12-10', 'Cyber Security'),
('SV005', 'Pham Minh D', '2003-03-25', 'Software Engineering');

-- 3. Cấp quyền truy cập từ các container khác trong mạng cloud-net
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY 'root' WITH GRANT OPTION;
FLUSH PRIVILEGES;
