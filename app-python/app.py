from flask import Flask, jsonify, Response, request
import os
import psycopg2
from datetime import datetime
import time
import logging
import json

# Configure structured logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Request counter for metrics
request_count = 0
db_connections = 0

@app.route("/")
def hello():
    global request_count
    request_count += 1
    
    logger.info(json.dumps({
        'event': 'request',
        'endpoint': '/',
        'method': request.method,
        'ip': request.remote_addr,
        'timestamp': datetime.now().isoformat()
    }))
    
    return jsonify({
        "message": "Hello from Python Flask!",
        "timestamp": datetime.now().isoformat(),
        "service": "python-flask"
    })

@app.route("/health")
def health():
    logger.info(json.dumps({
        'event': 'health_check',
        'status': 'healthy',
        'timestamp': datetime.now().isoformat()
    }))
    
    return jsonify({"status": "healthy", "service": "python-flask"})

@app.route("/metrics")
def metrics():
    """Prometheus metrics endpoint"""
    metrics_data = f"""# HELP python_app_requests_total Total requests
# TYPE python_app_requests_total counter
python_app_requests_total {request_count}

# HELP python_app_up Application status
# TYPE python_app_up gauge
python_app_up 1

# HELP python_app_db_connections Database connections
# TYPE python_app_db_connections gauge
python_app_db_connections {db_connections}

# HELP python_app_info Application info
# TYPE python_app_info gauge
python_app_info{{version="1.0",service="python-flask"}} 1
"""
    return Response(metrics_data, mimetype='text/plain')

@app.route("/db")
def db_test():
    global db_connections
    db_url = os.getenv("POSTGRES_HOST")
    db_user = os.getenv("POSTGRES_USER")
    db_password = os.getenv("POSTGRES_PASSWORD")
    db_name = os.getenv("POSTGRES_DB")
    
    logger.info(json.dumps({
        'event': 'db_connection_attempt',
        'database': db_name,
        'timestamp': datetime.now().isoformat()
    }))
    
    if not all([db_url, db_user, db_password, db_name]):
        logger.error(json.dumps({
            'event': 'db_config_missing',
            'timestamp': datetime.now().isoformat()
        }))
        return jsonify({
            "error": "Database configuration missing",
            "timestamp": datetime.now().isoformat()
        }), 500

    try:
        db_connections += 1
        conn = psycopg2.connect(
            host=db_url,
            user=db_user,
            password=db_password,
            dbname=db_name
        )
        conn.close()
        db_connections -= 1
        
        logger.info(json.dumps({
            'event': 'db_connection_success',
            'database': db_name,
            'timestamp': datetime.now().isoformat()
        }))
        
        return jsonify({
            "message": "Database connection successful!",
            "database": db_name,
            "timestamp": datetime.now().isoformat()
        })
    except Exception as e:
        db_connections -= 1
        logger.error(json.dumps({
            'event': 'db_connection_failed',
            'error': str(e),
            'timestamp': datetime.now().isoformat()
        }))
        return jsonify({
            "error": f"Database connection failed: {str(e)}",
            "timestamp": datetime.now().isoformat()
        }), 500

if __name__ == "__main__":
    logger.info(json.dumps({
        'event': 'app_startup',
        'service': 'python-flask',
        'timestamp': datetime.now().isoformat()
    }))
    app.run(host="0.0.0.0", port=5000)