from enum import Enum
from pydantic import BaseModel


class WsMessageType(str, Enum):
    LOCATION_UPDATE = "LOCATION_UPDATE"
    USER_CONNECTED = "USER_CONNECTED"
    USER_DISCONNECTED = "USER_DISCONNECTED"
    SESSION_ENDED = "SESSION_ENDED"
    CHAT_MESSAGE = "CHAT_MESSAGE"
    PULSE_PING = "PULSE_PING"
    PRIVACY_UPDATE = "PRIVACY_UPDATE"
    PING = "PING"
    PONG = "PONG"
    RATE_LIMITED = "RATE_LIMITED"


class WsEnvelope(BaseModel):
    type: WsMessageType
    payload: dict
    sender_id: str
    timestamp: str
