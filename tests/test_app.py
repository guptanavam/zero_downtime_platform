import os
import sys
# Add project root directory to Python's import path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import pytest
from app import app

@pytest.fixture
def client():
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client

def test_home_endpoint(client):
    """Test that the root route returns HTTP 200 and a welcome message"""
    response = client.get('/')
    assert response.status_code == 200
    data = response.get_json()
    assert "message" in data
    assert data["message"] == "Welcome to the Zero-Downtime Platform API"

def test_version_endpoint(client):
    """Test that /version returns HTTP 200 and a version string"""
    response = client.get('/version')
    assert response.status_code == 200
    data = response.get_json()
    assert "version" in data
    assert data["version"] == "1.0.0"