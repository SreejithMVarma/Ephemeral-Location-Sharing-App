from pydantic import BaseModel, Field


class AuthTokenRequest(BaseModel):
    user_id: str = Field(min_length=3, max_length=80)
    session_id: str
    passkey: str


class AuthTokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
