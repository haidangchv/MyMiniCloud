import os
from flask import Flask, jsonify, Response
import json
import pymysql

app = Flask(__name__)

DB_HOST = os.getenv("DB_HOST", "relational-database-server")
DB_PORT = int(os.getenv("DB_PORT", "3306"))
DB_USER = os.getenv("DB_USER", "minicloud_user")
DB_PASSWORD = os.getenv("DB_PASSWORD", "minicloud_pass")
DB_NAME = os.getenv("DB_NAME", "myminicloud_db")


def json_utf8(data, status=200):
    return Response(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n",
        status=status,
        mimetype="application/json; charset=utf-8",
    )


@app.route("/health", methods=["GET"])
def health():
    return json_utf8({"status": "healthy", "service": "application-backend-server"})


@app.route("/student", methods=["GET"])
@app.route("/api/student", methods=["GET"])
def get_student_static():
    students = [
        {
            "student_code": "SV001",
            "full_name": "Nguyễn Xuân Bằng",
            "role": "TV1",
            "task": "Web Server, Blog, API Gateway, Load Balancing, Docker Hub, AWS EC2",
        },
        {
            "student_code": "SV002",
            "full_name": "Thành viên 2",
            "role": "TV2",
            "task": "Flask Application Backend & MariaDB Database",
        },
        {
            "student_code": "SV003",
            "full_name": "Thành viên 3",
            "role": "TV3",
            "task": "Keycloak Identity, MinIO Storage & Bind9 DNS",
        },
        {
            "student_code": "SV004",
            "full_name": "Thành viên 4",
            "role": "TV4",
            "task": "Prometheus Monitoring, Node Exporter & Grafana Dashboard",
        },
    ]
    return json_utf8(
        {
            "source": "application-backend-server (static)",
            "count": len(students),
            "students": students,
        }
    )


@app.route("/students-db", methods=["GET"])
@app.route("/api/students-db", methods=["GET"])
def get_students_from_db():
    try:
        conn = pymysql.connect(
            host=DB_HOST,
            port=DB_PORT,
            user=DB_USER,
            password=DB_PASSWORD,
            database=DB_NAME,
            charset="utf8mb4",
            cursorclass=pymysql.cursors.DictCursor,
            connect_timeout=5,
        )
        with conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    "SELECT id, student_code, full_name, role_code, responsibility, email, "
                    "CAST(created_at AS CHAR) AS created_at FROM students ORDER BY id ASC;"
                )
                rows = cursor.fetchall()
        return json_utf8(
            {
                "source": f"MariaDB ({DB_HOST}:{DB_PORT}/{DB_NAME})",
                "count": len(rows),
                "students": rows,
            }
        )
    except Exception as exc:
        return json_utf8(
            {
                "status": "error",
                "source": f"MariaDB ({DB_HOST}:{DB_PORT}/{DB_NAME})",
                "message": str(exc),
            },
            status=500,
        )


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
