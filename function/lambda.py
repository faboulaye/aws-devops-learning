import json
import os
import random
import time


def _release_info():
    return {
        "version": os.getenv("RELEASE_VERSION", "0.0.0"),
        "environment": os.getenv("STAGE", os.getenv("ENV", "dev")),
    }



def lambda_handler(event, context):
    body = {
        "message": "Hello from Lambda!",
        "release": _release_info(),
        "requestId": getattr(context, "aws_request_id", None),
        "coldStart": _set_and_get_cold_start(),
    }
    return {"statusCode": 200, "headers": {"Content-Type": "application/json"}, "body": json.dumps(body)}


_WARM = False


def _set_and_get_cold_start():
    global _WARM
    was_cold = not _WARM
    _WARM = True
    return was_cold
