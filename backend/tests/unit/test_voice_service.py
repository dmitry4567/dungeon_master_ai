"""Unit tests for Agora voice service functions."""

from __future__ import annotations

import time
from datetime import datetime, timezone
from uuid import UUID, uuid4

import pytest

from src.services.voice_service import (
    create_voice_token_response,
    generate_voice_token,
    get_agora_uid,
)


class TestGetAgoraUid:
    """Tests for get_agora_uid function."""

    def test_returns_deterministic_value(self):
        """Same user_id should always produce same uid."""
        user_id = uuid4()
        uid1 = get_agora_uid(user_id)
        uid2 = get_agora_uid(user_id)
        assert uid1 == uid2

    def test_returns_value_in_valid_range(self):
        """uid should be in range [0, 2^31-1]."""
        for _ in range(100):
            user_id = uuid4()
            uid = get_agora_uid(user_id)
            assert 0 <= uid < 2**31

    def test_accepts_string_uuid(self):
        """Should accept string UUID as well as UUID object."""
        user_id = uuid4()
        uid_from_uuid = get_agora_uid(user_id)
        uid_from_str = get_agora_uid(str(user_id))
        assert uid_from_uuid == uid_from_str

    def test_different_users_get_different_uids(self):
        """Different users should get different uids (with high probability)."""
        user_ids = [uuid4() for _ in range(100)]
        uids = [get_agora_uid(uid) for uid in user_ids]
        # With 100 random UUIDs, collisions are extremely unlikely
        assert len(set(uids)) > 90


class TestGenerateVoiceToken:
    """Tests for generate_voice_token function."""

    # Test credentials - these are only used for token generation testing
    TEST_APP_ID = "test_app_id_12345678901234567890"
    TEST_APP_CERTIFICATE = "test_certificate_1234567890123456"

    def test_returns_token_and_expiry(self):
        """Should return tuple of (token, expires_at)."""
        token, expires_at = generate_voice_token(
            app_id=self.TEST_APP_ID,
            app_certificate=self.TEST_APP_CERTIFICATE,
            channel_name="test-channel",
            uid=12345,
            expire_seconds=3600,
        )
        assert isinstance(token, str)
        assert len(token) > 0
        assert isinstance(expires_at, datetime)
        assert expires_at.tzinfo == timezone.utc

    def test_expiry_is_in_future(self):
        """Expiry time should be in the future."""
        expire_seconds = 3600
        before = datetime.now(timezone.utc)

        _, expires_at = generate_voice_token(
            app_id=self.TEST_APP_ID,
            app_certificate=self.TEST_APP_CERTIFICATE,
            channel_name="test-channel",
            uid=12345,
            expire_seconds=expire_seconds,
        )

        after = datetime.now(timezone.utc)
        # expires_at should be approximately expire_seconds from now
        assert expires_at > before
        assert (expires_at - before).total_seconds() <= expire_seconds + 1
        assert (expires_at - before).total_seconds() >= expire_seconds - 1

    def test_different_channels_get_different_tokens(self):
        """Different channel names should produce different tokens."""
        token1, _ = generate_voice_token(
            app_id=self.TEST_APP_ID,
            app_certificate=self.TEST_APP_CERTIFICATE,
            channel_name="channel-1",
            uid=12345,
        )
        token2, _ = generate_voice_token(
            app_id=self.TEST_APP_ID,
            app_certificate=self.TEST_APP_CERTIFICATE,
            channel_name="channel-2",
            uid=12345,
        )
        assert token1 != token2

    def test_different_uids_get_different_tokens(self):
        """Different uids should produce different tokens."""
        token1, _ = generate_voice_token(
            app_id=self.TEST_APP_ID,
            app_certificate=self.TEST_APP_CERTIFICATE,
            channel_name="channel",
            uid=12345,
        )
        token2, _ = generate_voice_token(
            app_id=self.TEST_APP_ID,
            app_certificate=self.TEST_APP_CERTIFICATE,
            channel_name="channel",
            uid=67890,
        )
        assert token1 != token2

    def test_default_expiry_is_4_hours(self):
        """Default expiry should be 14400 seconds (4 hours)."""
        before = time.time()

        _, expires_at = generate_voice_token(
            app_id=self.TEST_APP_ID,
            app_certificate=self.TEST_APP_CERTIFICATE,
            channel_name="test-channel",
            uid=12345,
        )

        expected_expiry = before + 14400
        actual_expiry = expires_at.timestamp()
        assert abs(actual_expiry - expected_expiry) < 2  # Allow 2 second tolerance


class TestCreateVoiceTokenResponse:
    """Tests for create_voice_token_response function."""

    TEST_APP_ID = "test_app_id_12345678901234567890"
    TEST_APP_CERTIFICATE = "test_certificate_1234567890123456"

    def test_returns_complete_response(self):
        """Should return VoiceTokenResponse with all fields."""
        room_id = str(uuid4())
        user_id = uuid4()

        response = create_voice_token_response(
            app_id=self.TEST_APP_ID,
            app_certificate=self.TEST_APP_CERTIFICATE,
            room_id=room_id,
            user_id=user_id,
        )

        assert response.token
        assert response.channel_name == room_id
        assert response.uid == get_agora_uid(user_id)
        assert response.app_id == self.TEST_APP_ID
        assert response.expires_at is not None
        assert response.expires_at > datetime.now(timezone.utc)

    def test_channel_name_equals_room_id(self):
        """Channel name should be the same as room_id."""
        room_id = str(uuid4())

        response = create_voice_token_response(
            app_id=self.TEST_APP_ID,
            app_certificate=self.TEST_APP_CERTIFICATE,
            room_id=room_id,
            user_id=uuid4(),
        )

        assert response.channel_name == room_id

    def test_uid_is_deterministic(self):
        """uid should be deterministic for the same user."""
        user_id = uuid4()

        response1 = create_voice_token_response(
            app_id=self.TEST_APP_ID,
            app_certificate=self.TEST_APP_CERTIFICATE,
            room_id=str(uuid4()),
            user_id=user_id,
        )
        response2 = create_voice_token_response(
            app_id=self.TEST_APP_ID,
            app_certificate=self.TEST_APP_CERTIFICATE,
            room_id=str(uuid4()),
            user_id=user_id,
        )

        assert response1.uid == response2.uid
