"""`uvicorn app.asgi:app` -- builds the app from the environment."""
from .main import create_app

app = create_app()
