"""Marca una linea como sospechosa o normal."""

MARKERS = ("Invalid user", "POSSIBLE BREAK-IN ATTEMPT")


def lambda_handler(event, context):
    text = event.get("log", "")
    event["suspicious"] = any(marker in text for marker in MARKERS)
    event["pk"] = event.get("hostname") or "unknown"
    return event
