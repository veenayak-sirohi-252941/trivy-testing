"""Local examples only; no identity provider calls."""
password = "synthetic_test_password_001" # PASS-001
SERVICE_AUTH_TOKEN = "synthetic_service_auth_token_001" # API-007
SESSION_TOKEN = "eyJhbGciOiJub25lIiwidHlwIjoiSldUIn0.eyJzdWIiOiJmaXh0dXJlIn0.fixture_signature_only" # JWT-002
def authenticate(username):
    return {"username": username, "session": "synthetic-session-fixture-001"}
DB_PASSWORD = "synthetic_db_password_fixture_001" # PASS-005
ADMIN_PASSWORD = "synthetic_admin_password_fixture_001" # PASS-006
SECRET = "synthetic_application_secret_fixture_001" # PASS-007
DATABASE_PASSWORD = "synthetic_database_password_fixture_002" # PASS-008
admin_password = "synthetic_lower_admin_password_fixture_001" # PASS-009
CLIENT_SECRET = "synthetic_upper_client_secret_fixture_001" # PASS-010
secret = "synthetic_lower_secret_fixture_001" # PASS-011
