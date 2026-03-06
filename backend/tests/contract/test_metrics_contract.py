"""Contract tests for /metrics and /metrics/json endpoints."""
import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_metrics_prometheus_format(client: AsyncClient):
    """GET /metrics returns Prometheus text format."""
    response = await client.get("/metrics")
    assert response.status_code == 200
    assert "text/plain" in response.headers["content-type"]

    text = response.text
    # Must contain required metric names
    assert "http_requests_total" in text
    assert "http_errors_total" in text
    assert "http_request_duration_ms_avg" in text
    assert "http_error_rate" in text
    assert "http_request_duration_ms_bucket" in text
    assert "http_request_duration_ms_count" in text
    assert "http_request_duration_ms_sum" in text


@pytest.mark.asyncio
async def test_metrics_json_format(client: AsyncClient):
    """GET /metrics/json returns structured JSON."""
    response = await client.get("/metrics/json")
    assert response.status_code == 200

    data = response.json()
    assert "requests_total" in data
    assert "errors_total" in data
    assert "error_rate" in data
    assert "average_latency_ms" in data
    assert "latency_histogram_ms" in data
    assert "endpoints" in data

    # Types validation
    assert isinstance(data["requests_total"], int)
    assert isinstance(data["errors_total"], int)
    assert isinstance(data["error_rate"], float)
    assert isinstance(data["average_latency_ms"], float)
    assert isinstance(data["latency_histogram_ms"], dict)
    assert isinstance(data["endpoints"], dict)


@pytest.mark.asyncio
async def test_metrics_records_requests(client: AsyncClient):
    """Verify metrics are updated after making requests."""
    # Get initial count
    before = await client.get("/metrics/json")
    before_count = before.json()["requests_total"]

    # Make a few requests
    await client.get("/health")
    await client.get("/health")

    # Check count increased
    after = await client.get("/metrics/json")
    after_count = after.json()["requests_total"]

    # At least the 2 health requests should be tracked (+ the /metrics calls may vary)
    assert after_count >= before_count + 2


@pytest.mark.asyncio
async def test_metrics_tracks_error_rate(client: AsyncClient):
    """Verify error rate tracking works."""
    # Make a request to a non-existent endpoint
    await client.get("/nonexistent-endpoint-404")

    response = await client.get("/metrics/json")
    data = response.json()

    # Error rate should be > 0 (we had at least one 404)
    assert data["errors_total"] >= 1
    assert data["error_rate"] >= 0.0
    assert data["error_rate"] <= 1.0


@pytest.mark.asyncio
async def test_metrics_latency_histogram_buckets(client: AsyncClient):
    """Verify latency histogram has expected buckets."""
    response = await client.get("/metrics/json")
    data = response.json()

    histogram = data["latency_histogram_ms"]
    expected_buckets = ["10", "50", "100", "250", "500", "1000", "2500", "5000", "10000", "inf"]
    for bucket in expected_buckets:
        assert bucket in histogram, f"Missing histogram bucket: {bucket}"
        assert isinstance(histogram[bucket], int)
