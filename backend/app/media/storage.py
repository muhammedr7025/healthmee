import uuid

import boto3
from flask import current_app


def _client():
    """Server-to-storage calls (upload_bytes, download_bytes) — uses the
    internal endpoint (e.g. Docker Compose's `http://minio:9000`), which is
    only reachable from other containers on the same network.
    """
    cfg = current_app.config
    return boto3.client(
        "s3",
        endpoint_url=cfg["S3_ENDPOINT_URL"],
        aws_access_key_id=cfg["S3_ACCESS_KEY"],
        aws_secret_access_key=cfg["S3_SECRET_KEY"],
        region_name=cfg["S3_REGION"],
    )


def _public_client():
    """Presigned URLs handed to the Flutter app must be signed against the
    host the *client* can reach — a mobile simulator/device/browser can't
    resolve the `minio` container hostname, only the host-mapped port
    (S3_PUBLIC_ENDPOINT_URL, e.g. http://localhost:9000). Falls back to the
    internal endpoint when no public one is configured (e.g. local dev
    without Docker, where they're the same host).
    """
    cfg = current_app.config
    return boto3.client(
        "s3",
        endpoint_url=cfg.get("S3_PUBLIC_ENDPOINT_URL") or cfg["S3_ENDPOINT_URL"],
        aws_access_key_id=cfg["S3_ACCESS_KEY"],
        aws_secret_access_key=cfg["S3_SECRET_KEY"],
        region_name=cfg["S3_REGION"],
    )


def presign_upload(user_id: str, content_type: str, kind: str, expires_in: int = 900) -> dict:
    """Returns a signed PUT URL + the storage key the client should upload to
    directly — the Flask API never proxies the file bytes itself.
    """
    ext = (content_type.split("/")[-1] if content_type else "bin").lower()
    key = f"{kind}/{user_id}/{uuid.uuid4()}.{ext}"

    url = _public_client().generate_presigned_url(
        "put_object",
        Params={
            "Bucket": current_app.config["S3_BUCKET"],
            "Key": key,
            "ContentType": content_type,
        },
        ExpiresIn=expires_in,
    )
    return {"upload_url": url, "storage_key": key}


def presign_download(storage_key: str, expires_in: int = 900) -> str:
    return _public_client().generate_presigned_url(
        "get_object",
        Params={"Bucket": current_app.config["S3_BUCKET"], "Key": storage_key},
        ExpiresIn=expires_in,
    )


def upload_bytes(key: str, data: bytes, content_type: str) -> None:
    """Server-generated files (PDF reports, data exports) — unlike user
    media, the API writes these directly rather than handing out a presigned
    PUT for the client to upload to.
    """
    _client().put_object(Bucket=current_app.config["S3_BUCKET"], Key=key, Body=data, ContentType=content_type)


def download_bytes(storage_key: str) -> bytes:
    """Server-side read of an already-uploaded asset — used to hand an
    uploaded photo to a vision-capable LLM provider.
    """
    obj = _client().get_object(Bucket=current_app.config["S3_BUCKET"], Key=storage_key)
    return obj["Body"].read()
