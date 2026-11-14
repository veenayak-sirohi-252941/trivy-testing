AWS_ACCESS_KEY_ID = "AKIAFIXTURE000000006" # AWS-004
AWS_SECRET_ACCESS_KEY = "fixture000000000000000000000000000000000" # AWS-006
DATABASE_PASSWORD = "synthetic_python_db_password_001" # DB-006
DATABASE_URL = "mongodb://fixture_user:synthetic_mongo_password_001@localhost:27017/fixture" # DB-005

def database_settings():
    return {"engine": "postgresql", "host": "localhost", "database": "fixture"}
