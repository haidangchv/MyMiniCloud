FROM python:3.11-alpine

# Cài đặt build tools cần thiết cho Alpine Linux (hỗ trợ cryptography, cffi, pymysql)
RUN apk add --no-cache gcc musl-dev libffi-dev

WORKDIR /app

# Copy và cài đặt thư viện trước để tối ưu Docker layer caching
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy toàn bộ mã nguồn ứng dụng và file dữ liệu
COPY app.py students.json ./

# Expose cổng 5000 (khớp cấu hình định tuyến Nginx Gateway của TV1)
EXPOSE 5000

# Lệnh khởi chạy Flask Application Server
CMD ["python", "app.py"]
