"""Two-way mirror + self-healing for a pair of S3 buckets.

One copy of this Lambda runs next to each bucket (LOCAL_*), with the other
bucket as PEER_*. It:
  * mirrors new/changed objects LOCAL -> PEER
  * restores any object deleted from LOCAL (marker or permanent) from PEER
  * recreates LOCAL if the bucket itself was deleted, then refills it from PEER
  * runs a periodic reconcile that pulls anything missing from PEER
Copies carry metadata 'sync-origin' so they never trigger another copy (no loops).
"""
import os
import boto3
from botocore.exceptions import ClientError

LOCAL = os.environ["LOCAL_BUCKET"]
LOCAL_REGION = os.environ["LOCAL_REGION"]
PEER = os.environ["PEER_BUCKET"]
PEER_REGION = os.environ["PEER_REGION"]
MARK = "sync-origin"
TOMB = ".force-deleted/"  # tombstone prefix written by the dashboard's force delete

s3_local = boto3.client("s3", region_name=LOCAL_REGION)
s3_peer = boto3.client("s3", region_name=PEER_REGION)

NOT_FOUND = ("404", "NoSuchKey", "NotFound", "NoSuchBucket")


def head(client, bucket, key):
    try:
        return client.head_object(Bucket=bucket, Key=key)
    except ClientError as e:
        if e.response["Error"]["Code"] in NOT_FOUND:
            return None
        raise


def bucket_exists(client, bucket):
    try:
        client.head_bucket(Bucket=bucket)
        return True
    except ClientError as e:
        if e.response["Error"]["Code"] in NOT_FOUND:
            return False
        raise


def ensure_local_bucket():
    """Recreate the local bucket (with versioning/events) if it is gone."""
    if bucket_exists(s3_local, LOCAL):
        return False
    print(f"Bucket {LOCAL} missing - recreating")
    kwargs = {"Bucket": LOCAL}
    if LOCAL_REGION != "us-east-1":
        kwargs["CreateBucketConfiguration"] = {"LocationConstraint": LOCAL_REGION}
    try:
        s3_local.create_bucket(**kwargs)
    except ClientError as e:
        # OperationAborted while the name is still being released: next reconcile retries
        if e.response["Error"]["Code"] != "BucketAlreadyOwnedByYou":
            raise
    s3_local.put_bucket_versioning(Bucket=LOCAL, VersioningConfiguration={"Status": "Enabled"})
    s3_local.put_public_access_block(
        Bucket=LOCAL,
        PublicAccessBlockConfiguration={
            "BlockPublicAcls": True,
            "IgnorePublicAcls": True,
            "BlockPublicPolicy": True,
            "RestrictPublicBuckets": True,
        },
    )
    s3_local.put_bucket_cors(
        Bucket=LOCAL,
        CORSConfiguration={"CORSRules": [{
            "AllowedOrigins": ["*"],
            "AllowedMethods": ["GET", "PUT", "POST", "DELETE", "HEAD"],
            "AllowedHeaders": ["*"],
            "ExposeHeaders": ["ETag"],
        }]},
    )
    s3_local.put_bucket_notification_configuration(
        Bucket=LOCAL, NotificationConfiguration={"EventBridgeConfiguration": {}}
    )
    return True


def copy(src_client, src_bucket, dst_client, dst_bucket, key, src_head=None):
    h = src_head or head(src_client, src_bucket, key)
    if h is None:
        return False
    meta = dict(h.get("Metadata", {}))
    meta[MARK] = "1"
    dst_client.copy(
        {"Bucket": src_bucket, "Key": key},
        dst_bucket,
        key,
        ExtraArgs={
            "MetadataDirective": "REPLACE",
            "Metadata": meta,
            "ContentType": h.get("ContentType", "binary/octet-stream"),
        },
        SourceClient=src_client,
    )
    print(f"copied {src_bucket}/{key} -> {dst_bucket}")
    return True


def tombstoned(key):
    """True if a force-delete tombstone exists for key in either bucket."""
    t = TOMB + key
    return head(s3_local, LOCAL, t) is not None or (
        bucket_exists(s3_peer, PEER) and head(s3_peer, PEER, t) is not None)


def on_created(key):
    h = head(s3_local, LOCAL, key)
    if h is None or MARK in h.get("Metadata", {}):
        return
    if not bucket_exists(s3_peer, PEER):
        print("peer bucket missing; its healer will rebuild it")
        return
    ph = head(s3_peer, PEER, key)
    if ph and ph["ETag"] == h["ETag"]:
        return
    copy(s3_local, LOCAL, s3_peer, PEER, key, h)


def on_deleted(detail):
    if detail.get("reason") == "Lifecycle Expiration":
        return
    key = detail["object"]["key"]
    if not key.startswith(TOMB) and tombstoned(key):
        print(f"{key} was force-deleted; not healing")
        return
    if detail.get("deletion-type") == "Delete Marker Created":
        # Removing the marker un-deletes the previous version, even if peer also lost it.
        vid = detail["object"].get("version-id")
        if vid:
            s3_local.delete_object(Bucket=LOCAL, Key=key, VersionId=vid)
    if head(s3_local, LOCAL, key) is not None:
        print(f"{key} is present again")
        return
    if not copy(s3_peer, PEER, s3_local, LOCAL, key):
        print(f"WARNING: {key} is gone from both buckets, cannot heal")


def reconcile(context):
    ensure_local_bucket()
    if not bucket_exists(s3_peer, PEER):
        print("peer bucket missing; its healer will rebuild it")
        return
    local_keys = set()
    dead = set()
    for c, b in ((s3_local, LOCAL), (s3_peer, PEER)):
        for page in c.get_paginator("list_objects_v2").paginate(Bucket=b, Prefix=TOMB):
            dead.update(o["Key"][len(TOMB):] for o in page.get("Contents", []))
    for page in s3_local.get_paginator("list_objects_v2").paginate(Bucket=LOCAL):
        local_keys.update(o["Key"] for o in page.get("Contents", []))
    for page in s3_peer.get_paginator("list_objects_v2").paginate(Bucket=PEER):
        for o in page.get("Contents", []):
            if o["Key"] in local_keys or o["Key"] in dead:
                continue
            if context.get_remaining_time_in_millis() < 30000:
                print("running out of time; next run continues")
                return
            copy(s3_peer, PEER, s3_local, LOCAL, o["Key"])


def handler(event, context):
    dt = event.get("detail-type")
    detail = event.get("detail", {})
    if dt == "Object Created":
        on_created(detail["object"]["key"])
    elif dt == "Object Deleted":
        on_deleted(detail)
    else:  # scheduled run or DeleteBucket API call
        reconcile(context)
