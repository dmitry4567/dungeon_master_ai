from __future__ import annotations

from contextlib import asynccontextmanager
from typing import BinaryIO

import boto3
from botocore.config import Config
from botocore.exceptions import ClientError

from src.core.config import get_settings

settings = get_settings()

_s3_client = None


def get_s3_client():
    """Get S3/R2 client instance."""
    global _s3_client
    if _s3_client is None and settings.s3_endpoint:
        _s3_client = boto3.client(
            "s3",
            endpoint_url=settings.s3_endpoint,
            aws_access_key_id=settings.s3_access_key,
            aws_secret_access_key=settings.s3_secret_key,
            region_name=settings.s3_region,
            config=Config(
                signature_version="s3v4",
                retries={"max_attempts": 3, "mode": "standard"},
            ),
        )
    return _s3_client


@asynccontextmanager
async def s3_context():
    """Context manager for S3 operations."""
    client = get_s3_client()
    try:
        yield client
    finally:
        pass


class StorageService:
    """Service for S3/R2 storage operations."""

    def __init__(self, client=None, bucket: str | None = None):
        self.client = client or get_s3_client()
        self.bucket = bucket or settings.s3_bucket

    def upload_file(
        self,
        file_obj: BinaryIO,
        key: str,
        content_type: str = "application/octet-stream",
    ) -> str:
        """Upload file to S3/R2 and return the key."""
        if self.client is None:
            raise RuntimeError("S3 client not configured")

        self.client.upload_fileobj(
            file_obj,
            self.bucket,
            key,
            ExtraArgs={"ContentType": content_type},
        )
        return key

    def download_file(self, key: str) -> bytes:
        """Download file from S3/R2."""
        if self.client is None:
            raise RuntimeError("S3 client not configured")

        from io import BytesIO

        buffer = BytesIO()
        self.client.download_fileobj(self.bucket, key, buffer)
        buffer.seek(0)
        return buffer.read()

    def delete_file(self, key: str) -> bool:
        """Delete file from S3/R2."""
        if self.client is None:
            raise RuntimeError("S3 client not configured")

        try:
            self.client.delete_object(Bucket=self.bucket, Key=key)
            return True
        except ClientError:
            return False

    def get_presigned_url(
        self,
        key: str,
        expires_in: int = 3600,
        http_method: str = "GET",
    ) -> str:
        """Generate presigned URL for file access."""
        if self.client is None:
            raise RuntimeError("S3 client not configured")

        client_method = "get_object" if http_method == "GET" else "put_object"
        return self.client.generate_presigned_url(
            ClientMethod=client_method,
            Params={"Bucket": self.bucket, "Key": key},
            ExpiresIn=expires_in,
        )

    def file_exists(self, key: str) -> bool:
        """Check if file exists in S3/R2."""
        if self.client is None:
            raise RuntimeError("S3 client not configured")

        try:
            self.client.head_object(Bucket=self.bucket, Key=key)
            return True
        except ClientError:
            return False


def get_storage_service() -> StorageService:
    """Get storage service instance."""
    return StorageService()
