import os
import json
import time
import requests
from flask import Flask, jsonify, request
from jose import jwt
import pymysql

app = Flask(__name__)

# ==========================================
# CẤU HÌNH KEYCLOAK OIDC
# ==========================================
ISSUER = os.getenv("OIDC_ISSUER", "http://authentication-identity-server:8080/realms/master")
AUDIENCE = os.getenv("OIDC_AUDIENCE", "myapp")
KEYCLOAK_INTERNAL_URL = os.getenv("KEYCLOAK_INTERNAL_URL", "http://authentication-identity-server:8080")
_JWKS_CACHE = {}

def get_jwks(token=None):
    """Lấy JWKS từ Keycloak, tự động nhận diện realm trong token (master hoặc realm_sv...)"""
    realm = "master"
    if token:
        try:
            unverified = jwt.get_unverified_claims(token)
            iss = unverified.get("iss", "")
            if "/realms/" in iss:
                realm = iss.split("/realms/", 1)[1].strip("/")
        except Exception:
            pass

    now = time.time()
    cached = _JWKS_CACHE.get(realm)
    if cached and (now - cached["ts"] <= 600):
        return cached["jwks"]

    jwks_url = f"{KEYCLOAK_INTERNAL_URL}/realms/{realm}/protocol/openid-connect/certs"
    try:
        res = requests.get(jwks_url, timeout=5)
        if res.status_code == 200:
            jwks = res.json()
            _JWKS_CACHE[realm] = {"jwks": jwks, "ts": now}
            return jwks
    except Exception as e:
        print(f"[WARN] Cannot fetch JWKS from {jwks_url}: {e}")
    return cached["jwks"] if cached else None

# ==========================================
# CẤU HÌNH KẾT NỐI MARIADB
# ==========================================
DB_HOST = os.getenv("DB_HOST", "relational-database-server")
DB_USER = os.getenv("DB_USER", "root")
DB_PASS = os.getenv("DB_PASS", "root")
DB_NAME = os.getenv("DB_NAME", "studentdb")
DB_PORT = int(os.getenv("DB_PORT", 3306))

def get_db_connection():
    return pymysql.connect(
        host=DB_HOST,
        user=DB_USER,
        password=DB_PASS,
        database=DB_NAME,
        port=DB_PORT,
        charset="utf8mb4",
        cursorclass=pymysql.cursors.DictCursor,
        connect_timeout=5
    )

# ==========================================
# CÁC ROUTE API
# ==========================================

@app.get("/")
def index():
    """Trang thông tin tổng quan các endpoint của Application Backend Server"""
    return jsonify({
        "service": "Application Backend Server (Flask)",
        "status": "Running",
        "author": "TV 2 - Bui Huy Bau (MSSV: 52300181)",
        "endpoints": {
            "GET /hello": "API kiểm tra cơ bản (trả về JSON)",
            "GET /secure": "API xác thực OIDC Bearer Token qua Keycloak",
            "GET /student": "Mục mở rộng 2: Lấy danh sách 5 sinh viên từ students.json",
            "GET /students-db": "Mục mở rộng 3: Lấy danh sách sinh viên trực tiếp từ MariaDB (SELECT)",
            "POST /students-db": "Mục mở rộng 3 nâng cao: Thêm sinh viên mới vào MariaDB (INSERT)",
            "PUT /students-db/<student_id>": "Mục mở rộng 3 nâng cao: Cập nhật thông tin sinh viên (UPDATE)",
            "DELETE /students-db/<student_id>": "Mục mở rộng 3 nâng cao: Xóa sinh viên khỏi MariaDB (DELETE)"
        }
    })

# 1. API Cơ bản
@app.get("/hello")
@app.get("/hello/")
def hello():
    return jsonify(message="Hello from App Server!")

# 2. API Cơ bản bảo mật bằng Keycloak Token (OIDC)
@app.get("/secure")
@app.get("/secure/")
def secure():
    auth = request.headers.get("Authorization", "")
    if not auth.startswith("Bearer "):
        return jsonify(error="Missing Bearer token"), 401
    
    token = auth.split(" ", 1)[1]
    jwks = get_jwks(token)
    if not jwks:
        return jsonify(error="Authentication server JWKS unavailable"), 503

    try:
        payload = jwt.decode(
            token,
            jwks,
            algorithms=["RS256"],
            options={"verify_aud": False, "verify_iss": False},
        )
        return jsonify(
            message="Secure resource OK",
            preferred_username=payload.get("preferred_username", "unknown"),
            client_id=payload.get("azp", payload.get("client_id", AUDIENCE)),
            issuer=payload.get("iss", ISSUER),
            roles=payload.get("realm_access", {}).get("roles", [])
        )
    except Exception as e:
        return jsonify(error=str(e)), 401

# 3. Yêu cầu mở rộng Mục 2: API đọc danh sách sinh viên từ file students.json
@app.get("/student")
@app.get("/student/")
def student():
    try:
        json_path = os.path.join(os.path.dirname(__file__), "students.json")
        with open(json_path, "r", encoding="utf-8") as f:
            data = json.load(f)
        return jsonify({
            "status": "success",
            "source": "students.json (Static JSON File)",
            "count": len(data),
            "data": data
        })
    except Exception as e:
        return jsonify({"status": "error", "message": f"Cannot load students.json: {str(e)}"}), 500

# 4. Yêu cầu mở rộng Mục 3: API đọc danh sách sinh viên từ CSDL MariaDB (studentdb)
@app.get("/students-db")
@app.get("/students-db/")
def students_db_get():
    try:
        conn = get_db_connection()
        with conn.cursor() as cursor:
            sql = "SELECT id, student_id, fullname, DATE_FORMAT(dob, '%Y-%m-%d') AS dob, major FROM students ORDER BY id ASC;"
            cursor.execute(sql)
            results = cursor.fetchall()
        conn.close()
        return jsonify({
            "status": "success",
            "source": f"MariaDB ({DB_HOST}:{DB_PORT}/{DB_NAME})",
            "count": len(results),
            "data": results
        })
    except Exception as e:
        return jsonify({
            "status": "error",
            "message": f"Database connection/query error: {str(e)}"
        }), 500

# 5. Yêu cầu mở rộng Mục 3 nâng cao: Thêm sinh viên mới vào MariaDB
@app.post("/students-db")
def students_db_create():
    payload = request.get_json(silent=True)
    if not payload:
        return jsonify({"status": "error", "message": "Invalid JSON body"}), 400

    student_id = payload.get("student_id")
    fullname = payload.get("fullname")
    dob = payload.get("dob")
    major = payload.get("major")

    if not all([student_id, fullname, dob, major]):
        return jsonify({
            "status": "error",
            "message": "Missing required fields: student_id, fullname, dob, major"
        }), 400

    try:
        conn = get_db_connection()
        with conn.cursor() as cursor:
            sql = "INSERT INTO students (student_id, fullname, dob, major) VALUES (%s, %s, %s, %s);"
            cursor.execute(sql, (student_id, fullname, dob, major))
            conn.commit()
            new_id = cursor.lastrowid
        conn.close()
        return jsonify({
            "status": "success",
            "message": "Student created successfully",
            "created_id": new_id
        }), 201
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

# 6. Yêu cầu mở rộng Mục 3 nâng cao: Cập nhật thông tin sinh viên (UPDATE)
@app.put("/students-db/<student_id>")
def students_db_update(student_id):
    payload = request.get_json(silent=True)
    if not payload:
        return jsonify({"status": "error", "message": "Invalid JSON body"}), 400

    fields = []
    values = []
    for col in ["fullname", "dob", "major"]:
        if col in payload:
            fields.append(f"{col} = %s")
            values.append(payload[col])

    if not fields:
        return jsonify({"status": "error", "message": "No valid fields to update (fullname, dob, major)"}), 400

    values.append(student_id)
    try:
        conn = get_db_connection()
        with conn.cursor() as cursor:
            sql = f"UPDATE students SET {', '.join(fields)} WHERE student_id = %s;"
            affected = cursor.execute(sql, tuple(values))
            conn.commit()
        conn.close()
        if affected == 0:
            return jsonify({"status": "error", "message": f"Student {student_id} not found or no change made"}), 404
        return jsonify({
            "status": "success",
            "message": f"Student {student_id} updated successfully"
        })
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

# 7. Yêu cầu mở rộng Mục 3 nâng cao: Xóa sinh viên khỏi MariaDB (DELETE)
@app.delete("/students-db/<student_id>")
def students_db_delete(student_id):
    try:
        conn = get_db_connection()
        with conn.cursor() as cursor:
            sql = "DELETE FROM students WHERE student_id = %s;"
            affected = cursor.execute(sql, (student_id,))
            conn.commit()
        conn.close()
        if affected == 0:
            return jsonify({"status": "error", "message": f"Student {student_id} not found"}), 404
        return jsonify({
            "status": "success",
            "message": f"Student {student_id} deleted successfully"
        })
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

if __name__ == "__main__":
    # Đọc cổng từ biến môi trường PORT (mặc định 5000 theo cấu hình API Gateway của TV1)
    port = int(os.getenv("PORT", 5000))
    app.run(host="0.0.0.0", port=port, debug=False)
