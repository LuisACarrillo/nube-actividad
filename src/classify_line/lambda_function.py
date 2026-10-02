"""Marca una linea como sospechosa o normal."""

MARKERS = ("Invalid user", "POSSIBLE BREAK-IN ATTEMPT")


def lambda_handler(event, context):
    text = event.get("log", "")
    event["suspicious"] = any(marker in text for marker in MARKERS)
    event["host"] = event.get("host") or event.get("hostname") or "unknown"
    event["pk"] = event["host"]
    event["id"] = event.get("id") or event.get("sk")
    event["gsi_pk"] = "LOG"
    event["severity"] = "high" if event["suspicious"] else "info"
    return event
