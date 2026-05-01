import logging
from collections.abc import Iterable
from typing import Any

from src.repositories.redis_repository import RedisRepository

logger = logging.getLogger(__name__)

SESSION_TTL_SECONDS = 12 * 60 * 60
MAX_CHAT_MESSAGES = 200


class SessionRepository(RedisRepository):
    @staticmethod
    def session_key(session_id: str) -> str:
        return f"session:{session_id}"

    @staticmethod
    def members_key(session_id: str) -> str:
        return f"session:{session_id}:members"

    @staticmethod
    def locations_key(session_id: str) -> str:
        return f"session:{session_id}:locations"

    @staticmethod
    def global_chat_key(session_id: str) -> str:
        return f"session:{session_id}:chat:global"

    @staticmethod
    def dm_chat_key(session_id: str, user_one: str, user_two: str) -> str:
        u1, u2 = sorted([user_one, user_two])
        return f"session:{session_id}:chat:dm:{u1}:{u2}"

    @staticmethod
    def path_stream_key(session_id: str, user_id: str) -> str:
        return f"session:{session_id}:path:{user_id}"

    @staticmethod
    def user_key(user_id: str) -> str:
        return f"user:{user_id}"

    async def create_session(self, session_id: str, values: dict[str, Any], host_user_id: str | None = None) -> None:
        key = self.session_key(session_id)
        members_key = self.members_key(session_id)
        try:
            pipeline = self.redis.pipeline(transaction=True)
            pipeline.hset(key, mapping=values)
            pipeline.expire(key, SESSION_TTL_SECONDS)
            pipeline.expire(members_key, SESSION_TTL_SECONDS)
            if host_user_id:
                pipeline.sadd(members_key, host_user_id)
            await pipeline.execute()
        except Exception:
            logger.exception("Create session failed", extra={"session_id": session_id})
            raise

    async def add_member(self, session_id: str, user_id: str) -> None:
        members = self.members_key(session_id)
        try:
            pipeline = self.redis.pipeline(transaction=True)
            pipeline.sadd(members, user_id)
            pipeline.expire(members, SESSION_TTL_SECONDS)
            await pipeline.execute()
        except Exception:
            logger.exception("Add member failed", extra={"session_id": session_id, "user_id": user_id})
            raise

    async def remove_member(self, session_id: str, user_id: str) -> None:
        try:
            await self.redis.srem(self.members_key(session_id), user_id)
        except Exception:
            logger.exception("Remove member failed", extra={"session_id": session_id, "user_id": user_id})
            raise

    async def get_members(self, session_id: str) -> set[str]:
        try:
            return set(await self.redis.smembers(self.members_key(session_id)))
        except Exception:
            logger.exception("Get members failed", extra={"session_id": session_id})
            return set()

    async def get_member_profiles(self, session_id: str) -> list[dict[str, str]]:
        member_ids = sorted(await self.get_members(session_id))
        profiles: list[dict[str, str]] = []
        for member_id in member_ids:
            profile = await self.get_hash(self.user_key(member_id))
            display_name = profile.get("display_name", "").strip()
            current_session = profile.get("current_session", "")
            if not display_name or current_session not in {"", session_id}:
                continue

            profiles.append(
                {
                    "user_id": member_id,
                    "display_name": display_name,
                    "avatar_url": profile.get("avatar", ""),
                    "privacy_mode": profile.get("privacy_mode", "direction_distance"),
                }
            )
        return profiles

    async def set_user_profile(self, user_id: str, profile: dict[str, Any]) -> None:
        try:
            await self.set_hash(self.user_key(user_id), profile)
        except Exception:
            logger.exception("Set user profile failed", extra={"user_id": user_id})
            raise

    async def add_location(self, session_id: str, user_id: str, lng: float, lat: float) -> None:
        try:
            await self.redis.geoadd(self.locations_key(session_id), (lng, lat, user_id))
            await self.redis.expire(self.locations_key(session_id), SESSION_TTL_SECONDS)
        except Exception:
            logger.exception("Geo add failed", extra={"session_id": session_id, "user_id": user_id})
            raise

    async def nearby_members(self, session_id: str, user_id: str, radius_meters: float) -> list[tuple[str, float]]:
        try:
            results = await self.redis.georadiusbymember(
                self.locations_key(session_id),
                user_id,
                radius_meters,
                unit="m",
                withdist=True,
                sort="ASC",
            )
            normalized: list[tuple[str, float]] = []
            for item in results:
                member, distance = item
                normalized.append((str(member), float(distance)))
            return normalized
        except Exception:
            logger.exception("Geo radius query failed", extra={"session_id": session_id, "user_id": user_id})
            return []

    async def append_global_chat(self, session_id: str, message_json: str) -> None:
        key = self.global_chat_key(session_id)
        try:
            pipeline = self.redis.pipeline(transaction=True)
            pipeline.rpush(key, message_json)
            pipeline.ltrim(key, -MAX_CHAT_MESSAGES, -1)
            pipeline.expire(key, SESSION_TTL_SECONDS)
            await pipeline.execute()
        except Exception:
            logger.exception("Append global chat failed", extra={"session_id": session_id})
            raise

    async def append_dm_chat(self, session_id: str, user_one: str, user_two: str, message_json: str) -> None:
        key = self.dm_chat_key(session_id, user_one, user_two)
        try:
            pipeline = self.redis.pipeline(transaction=True)
            pipeline.rpush(key, message_json)
            pipeline.ltrim(key, -MAX_CHAT_MESSAGES, -1)
            pipeline.expire(key, SESSION_TTL_SECONDS)
            await pipeline.execute()
        except Exception:
            logger.exception("Append DM chat failed", extra={"session_id": session_id})
            raise

    async def add_path_point(self, session_id: str, user_id: str, lat: float, lng: float, ts: str) -> str:
        stream = self.path_stream_key(session_id, user_id)
        try:
            entry_id = await self.redis.xadd(stream, {"lat": str(lat), "lng": str(lng), "ts": ts})
            await self.redis.expire(stream, SESSION_TTL_SECONDS)
            return str(entry_id)
        except Exception:
            logger.exception("XADD path stream failed", extra={"session_id": session_id, "user_id": user_id})
            raise

    async def delete_session_cascade(self, session_id: str) -> int:
        deleted = 0
        try:
            exact_keys = [
                self.session_key(session_id),
                self.members_key(session_id),
                self.locations_key(session_id),
                self.global_chat_key(session_id),
            ]
            deleted += await self.delete(*exact_keys)

            patterns = [
                f"session:{session_id}:chat:dm:*",
                f"session:{session_id}:path:*",
            ]

            for pattern in patterns:
                keys = [k async for k in self.redis.scan_iter(match=pattern)]
                if keys:
                    deleted += await self.delete(*keys)
            return deleted
        except Exception:
            logger.exception("Session cleanup cascade failed", extra={"session_id": session_id})
            raise

    async def on_expired_key(self, key: str) -> None:
        # Trigger cleanup cascade if the top-level session hash expires.
        if not key.startswith("session:"):
            return
        parts = key.split(":")
        if len(parts) != 2:
            return
        await self.delete_session_cascade(parts[1])

    async def remove_location_member(self, session_id: str, user_id: str) -> None:
        try:
            await self.redis.zrem(self.locations_key(session_id), user_id)
        except Exception:
            logger.exception("Remove geo member failed", extra={"session_id": session_id, "user_id": user_id})
            raise

    async def bulk_create_session_atomic(self, session_id: str, session_values: dict[str, Any], member_ids: Iterable[str]) -> None:
        try:
            pipeline = self.redis.pipeline(transaction=True)
            pipeline.hset(self.session_key(session_id), mapping=session_values)
            if member_ids:
                pipeline.sadd(self.members_key(session_id), *list(member_ids))
            pipeline.expire(self.session_key(session_id), SESSION_TTL_SECONDS)
            pipeline.expire(self.members_key(session_id), SESSION_TTL_SECONDS)
            await pipeline.execute()
        except Exception:
            logger.exception("Bulk session create failed", extra={"session_id": session_id})
            raise
