from __future__ import annotations

import json
import random
import time

from locust import User, between, task


class RadarWsUser(User):
    wait_time = between(0.05, 0.2)

    def on_start(self) -> None:
        # This skeleton keeps Step 25 executable artifacts in-repo.
        # Replace with authenticated WS setup against staging in CI.
        self.session_id = f"session_{random.randint(1000, 9999)}"
        self.user_id = f"user_{random.randint(1000, 9999)}"

    @task
    def emit_location_like_payload(self) -> None:
        # Placeholder operation to model update pacing at 10 updates/s.
        _payload = {
            "type": "LOCATION_UPDATE",
            "payload": {
                "lat": round(37.7749 + random.random() / 1000, 6),
                "lng": round(-122.4194 + random.random() / 1000, 6),
            },
            "sender_id": self.user_id,
            "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        }
        _ = json.dumps(_payload)
