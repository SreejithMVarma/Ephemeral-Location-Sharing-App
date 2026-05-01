from pydantic import BaseModel, Field


class CreateSessionRequest(BaseModel):
    session_name: str = Field(min_length=1, max_length=80)
    admin_id: str = Field(min_length=3, max_length=80)
    admin_display_name: str = Field(min_length=1, max_length=30)
    region: str = "us-east"


class CreateSessionResponse(BaseModel):
    session_id: str
    passkey: str
    deep_link_url: str


class VerifySessionResponse(BaseModel):
    session_name: str
    host_name: str
    active_members: int
    websocket_url: str


class JoinSessionRequest(BaseModel):
    user_id: str = Field(min_length=3, max_length=80)
    display_name: str = Field(min_length=1, max_length=30)
