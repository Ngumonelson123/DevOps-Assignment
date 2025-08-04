from flask import Flask, jsonify, Response
import os
import psycopg2
from datetime import datetime
import time

app = Flask(__name__)

@app.route("/")
def hello():
    return jsonify({
        "message": "Hello from Python Flask!",
        "timestamp": datetime.now().isoformat(),
        "service": "python-flask"
    })

@app.route("/health")
def health():
    return jsonify({"status": "healthy", "service": "python-flask"})

@app.route("/metrics")
def metrics():
    """Prometheus metrics endpoint"""
    metrics_data = f"""# HELP python_app_requests_total Total requests
# TYPE python_app_requests_total counter
python_app_requests_total {{method="GET",endpoint="/"}} {int(time.time()) % 1000}

# HELP python_app_up Application status
# TYPE python_app_up gauge
python_app_up 1

# HELP python_app_response_time_seconds Response time
# TYPE python_app_response_time_seconds histogram
python_app_response_time_seconds_bucket {{le="0.1"}} 1
python_app_response_time_seconds_bucket {{le="0.5"}} 1
python_app_response_time_seconds_bucket {{le="1.0"}} 1
python_app_response_time_seconds_bucket {{le="+Inf"}} 1
python_app_response_time_seconds_count 1
python_app_response_time_seconds_sum 0.1
"""
    return Response(metrics_data, mimetype='text/plain')

@app.route("/db")
def db_test():
    db_url = os.getenv("POSTGRES_HOST")
    db_user = os.getenv("POSTGRES_USER")
    db_password = os.getenv("POSTGRES_PASSWORD")
    db_name = os.getenv("POSTGRES_DB")
    
    if not all([db_url, db_user, db_password, db_name]):
        return jsonify({
            "error": "Database configuration missing",
            "timestamp": datetime.now().isoformat()
        }), 500

    try:
        conn = psycopg2.connect(
            host=db_url,
            user=db_user,
            password=db_password,
            dbname=db_name
        )
        conn.close()
        return jsonify({
            "message": "Database connection successful!",
            "database": db_name,
            "timestamp": datetime.now().isoformat()
        })
    except Exception as e:
        return jsonify({
            "error": f"Database connection failed: {str(e)}",
            "timestamp": datetime.now().isoformat()
        }), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)