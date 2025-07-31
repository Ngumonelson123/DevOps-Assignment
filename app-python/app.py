from flask import Flask
import os
import psycopg2

app = Flask(__name__)

@app.route("/")
def hello():
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
        return "Hello,from Python + PostgreSQL connection successful!"
    except Exception as e:
        return f"Error connecting to the database: {e}"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)