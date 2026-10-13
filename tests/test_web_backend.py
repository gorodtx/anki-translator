from __future__ import annotations

import asyncio
from pathlib import Path

import httpx
import pytest

from translate_logic.domain.models import FieldValue, TranslationResult
from translate_logic.infrastructure.http.transport import FetchError
from web_backend import app as module
from web_backend.app import MAX_CONCURRENT, create_app


def test_translation_validation_and_response_isolation(tmp_path: Path) -> None:
    async def engine(text: str) -> TranslationResult:
        return TranslationResult(translation_ru=FieldValue.present(f"ответ:{text}"))

    async def scenario() -> None:
        transport = httpx.ASGITransport(app=create_app(db_dir=tmp_path, engine=engine))
        async with httpx.AsyncClient(
            transport=transport, base_url="http://test"
        ) as client:
            for payload in (
                {"text": ""},
                {"text": " "},
                {"text": "x" * 201},
                {"text": "bank", "target_lang": "de"},
            ):
                assert (
                    await client.post("/api/translate", json=payload)
                ).status_code == 422
            responses = await asyncio.gather(
                *(
                    client.post("/api/translate", json={"text": text})
                    for text in ("bank", "time")
                )
            )
            assert [response.json()["translation"] for response in responses] == [
                "ответ:bank",
                "ответ:time",
            ]
            capabilities = (await client.get("/api/capabilities")).json()
            assert capabilities["apple_engines"] is False
            assert capabilities["primary_db"] is False
            assert capabilities["history"] == "browser-session"
            assert (
                await client.post("/api/translate", content=b"x" * 4097)
            ).status_code == 413

    asyncio.run(scenario())


def test_chunked_body_limit(tmp_path: Path) -> None:
    async def chunks():
        for _ in range(5):
            yield b"x" * 1000

    async def scenario() -> None:
        transport = httpx.ASGITransport(app=create_app(db_dir=tmp_path))
        async with httpx.AsyncClient(
            transport=transport, base_url="http://test"
        ) as client:
            response = await client.post("/api/translate", content=chunks())
            assert response.status_code == 413

    asyncio.run(scenario())


def test_capacity_is_bounded_and_recovers(tmp_path: Path) -> None:
    async def scenario() -> None:
        release = asyncio.Event()
        started = asyncio.Event()
        count = 0

        async def engine(text: str) -> TranslationResult:
            nonlocal count
            count += 1
            if count == MAX_CONCURRENT:
                started.set()
            await release.wait()
            return TranslationResult(translation_ru=FieldValue.present(text))

        transport = httpx.ASGITransport(app=create_app(db_dir=tmp_path, engine=engine))
        async with httpx.AsyncClient(
            transport=transport, base_url="http://test"
        ) as client:
            jobs = [
                asyncio.create_task(
                    client.post("/api/translate", json={"text": "bank"})
                )
                for _ in range(MAX_CONCURRENT)
            ]
            await asyncio.wait_for(started.wait(), timeout=2)
            assert (
                await client.post("/api/translate", json={"text": "extra"})
            ).status_code == 503
            release.set()
            assert all(
                response.status_code == 200 for response in await asyncio.gather(*jobs)
            )
            assert (
                await client.post("/api/translate", json={"text": "again"})
            ).status_code == 200

    asyncio.run(scenario())


def test_provider_outage_is_not_a_fake_result(tmp_path: Path) -> None:
    async def engine(_text: str) -> TranslationResult:
        raise FetchError("private provider diagnostic")

    async def scenario() -> None:
        transport = httpx.ASGITransport(app=create_app(db_dir=tmp_path, engine=engine))
        async with httpx.AsyncClient(
            transport=transport, base_url="http://test"
        ) as client:
            response = await client.post("/api/translate", json={"text": "bank"})
            assert response.status_code == 502
            assert "private provider diagnostic" not in response.text

    asyncio.run(scenario())


def test_timeout_releases_capacity(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(module, "REQUEST_TIMEOUT", 0.01)

    async def engine(_text: str) -> TranslationResult:
        await asyncio.sleep(1)
        return TranslationResult.empty()

    async def scenario() -> None:
        transport = httpx.ASGITransport(app=create_app(db_dir=tmp_path, engine=engine))
        async with httpx.AsyncClient(
            transport=transport, base_url="http://test"
        ) as client:
            for _ in range(MAX_CONCURRENT + 1):
                assert (
                    await client.post("/api/translate", json={"text": "bank"})
                ).status_code == 504

    asyncio.run(scenario())


def test_rate_limit_is_bounded(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(module, "MAX_REQUESTS_PER_MINUTE", 2)

    async def engine(_text: str) -> TranslationResult:
        return TranslationResult.empty()

    async def scenario() -> None:
        transport = httpx.ASGITransport(app=create_app(db_dir=tmp_path, engine=engine))
        async with httpx.AsyncClient(
            transport=transport, base_url="http://test"
        ) as client:
            assert (
                await client.post("/api/translate", json={"text": "bank"})
            ).status_code == 200
            assert (
                await client.post("/api/translate", json={"text": "bank"})
            ).status_code == 200
            limited = await client.post("/api/translate", json={"text": "bank"})
            assert limited.status_code == 429
            assert limited.headers["retry-after"] == "60"

    asyncio.run(scenario())
