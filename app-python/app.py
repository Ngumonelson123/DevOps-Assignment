from flask import Flask, jsonify
import os
import psycopg2
from datetime import datetime

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

@app.route("/db")
def db_test():
    db_url = os.getenv("POSTGRES_HOST", "localhost")
    db_user = os.getenv("POSTGRES_USER", "devops")
    db_password = os.getenv("POSTGRES_PASSWORD", "secret")
    db_name = os.getenv("POSTGRES_DB", "devopsdb")

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