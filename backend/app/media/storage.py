import uuid

import boto3
from flask import current_app


def _client():
    cfg = current_app.config
    return boto3.client(
        "s3",
        endpoint_url=cfg["S3_ENDPOINT_URL"],
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

    url = _client().generate_presigned_url(
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
    return _client().generate_presigned_url(
        "get_object",
        Params={"Bucket": current_app.config["S3_BUCKET"], "Key": storage_key},
        ExpiresIn=expires_in,
    )
