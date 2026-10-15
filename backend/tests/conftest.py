import os

os.environ["APP_SECRET"] = "test-only-secret-not-for-real-use"
os.environ.setdefault("DATABASE_URL", "sqlite+aiosqlite:///:memory:")
