import re
import boto3
from functools import lru_cache
from typing import List, AsyncGenerator, Optional
from botocore.exceptions import ClientError, BotoCoreError

from fastapi import HTTPException

from src.core.config import get_settings


class TTSService:
    def __init__(self):
        self.settings = get_settings()

        # Initialize AWS Polly client
        self.polly_client = boto3.client(
            'polly',
            aws_access_key_id=self.settings.aws_access_key_id,
            aws_secret_access_key=self.settings.aws_secret_access_key,
            region_name=self.settings.aws_region,
        )

        self.voice_id = self.settings.polly_voice_id
        self.engine = self.settings.polly_engine

    async def stream_tts(self, text: str) -> AsyncGenerator[bytes, None]:
        """
        Generates streaming TTS audio using AWS Polly.
        Yields audio chunks as they're generated.
        """
        if not self.settings.aws_access_key_id or not self.settings.aws_secret_access_key:
            print("AWS credentials not configured")
            return

        processed_text = self.preprocess_text(text)
        if len(processed_text) > self.settings.tts_max_text_length:
            print(f"Text too long: {len(processed_text)} chars")
            return

        text_chunks = self._chunk_text(processed_text)

        for chunk in text_chunks:
            try:
                # Request TTS from Polly
                response = self.polly_client.synthesize_speech(
                    Text=chunk,
                    OutputFormat='mp3',
                    VoiceId=self.voice_id,
                    Engine=self.engine,
                )

                # Stream audio data
                if 'AudioStream' in response:
                    # Read audio stream in chunks
                    audio_stream = response['AudioStream']
                    while True:
                        audio_chunk = audio_stream.read(4096)
                        if not audio_chunk:
                            break
                        yield audio_chunk
                    audio_stream.close()

            except (BotoCoreError, ClientError) as e:
                print(f"AWS Polly error: {e}")
                # Don't raise HTTPException during streaming - just stop
                break
            except Exception as e:
                print(f"Unexpected error during TTS streaming: {e}")
                break

    def preprocess_text(self, text: str) -> str:
        """
        Cleans and preprocesses text before sending to TTS engine.
        1. Strips Markdown formatting.
        2. Removes custom DICE tags.
        3. Normalizes whitespace.
        4. Trims leading/trailing whitespace.
        """
        # 1. Strip Markdown
        text = re.sub(r"[\*_`~]", "", text)

        # 2. Remove DICE tags
        text = re.sub(r"\[DICE:.*?\]", "", text)

        # 3. Normalize whitespace
        text = re.sub(r"\s+", " ", text)

        # 4. Trim whitespace
        return text.strip()

    def _chunk_text(self, text: str) -> List[str]:
        """
        Splits text into chunks smaller than `tts_chunk_size`.
        """
        if len(text) <= self.settings.tts_chunk_size:
            return [text]

        chunks = []
        # Split by sentence-ending punctuation
        sentences = re.split(r'(?<=[.!?])\s+', text)

        current_chunk = ""
        for sentence in sentences:
            if len(current_chunk) + len(sentence) + 1 > self.settings.tts_chunk_size:
                if current_chunk:
                    chunks.append(current_chunk)
                current_chunk = sentence
            else:
                current_chunk += (" " + sentence if current_chunk else sentence)

        if current_chunk:
            chunks.append(current_chunk)

        # Further split any chunks that are still too long
        final_chunks = []
        for chunk in chunks:
            if len(chunk) > self.settings.tts_chunk_size:
                # Fallback to splitting by comma/semicolon, then by space
                sub_chunks = re.split(r'([,;])\s*', chunk)
                temp_chunk = ""
                for s_chunk in sub_chunks:
                    if len(temp_chunk) + len(s_chunk) > self.settings.tts_chunk_size:
                        final_chunks.append(temp_chunk)
                        temp_chunk = s_chunk
                    else:
                        temp_chunk += s_chunk
                if temp_chunk:
                    final_chunks.append(temp_chunk)
            else:
                final_chunks.append(chunk)

        return final_chunks

    async def check_availability(self) -> tuple[bool, Optional[str]]:
        """
        Проверяет доступность AWS Polly.
        Возвращает (доступен, сообщение об ошибке).
        """
        if not self.settings.aws_access_key_id or not self.settings.aws_secret_access_key:
            return False, "AWS credentials not configured"

        try:
            # Test Polly with a minimal request
            response = self.polly_client.synthesize_speech(
                Text="test",
                OutputFormat='mp3',
                VoiceId=self.voice_id,
                Engine=self.engine,
            )

            if 'AudioStream' in response:
                # Close the stream immediately
                response['AudioStream'].close()
                return True, None
            else:
                return False, "Invalid response from AWS Polly"

        except ClientError as e:
            error_code = e.response.get('Error', {}).get('Code', 'Unknown')
            if error_code == 'InvalidParametersException':
                return False, f"Invalid voice or engine: {self.voice_id}/{self.engine}"
            elif error_code == 'AccessDeniedException':
                return False, "AWS access denied - check credentials"
            else:
                return False, f"AWS Polly error: {error_code}"
        except BotoCoreError as e:
            return False, f"AWS connection error: {str(e)}"
        except Exception as e:
            return False, f"Unexpected error: {str(e)}"


@lru_cache
def get_tts_service() -> TTSService:
    return TTSService()
