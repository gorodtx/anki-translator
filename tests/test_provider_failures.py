"""An unavailable source must not look like a successful empty translation."""

from __future__ import annotations

import asyncio
from concurrent.futures import Future
from dataclasses import replace

import pytest
import aiohttp

from desktop_app.application.translation_session import TranslationSession
from translate_logic.application.pipeline import translate as pipeline
from translate_logic.infrastructure.http.transport import (
    FetchError,
    FetchStatusError,
    build_async_fetcher,
)
from translate_logic.infrastructure.providers import apple
from translate_logic.models import (
    LexicalEntry,
    LexicalInfo,
    LexicalSense,
    SourceToggles,
    TranslationResult,
    TranslationStatus,
)

ALL_OFF = SourceToggles(False, False, False, False, False, False)
CAMBRIDGE_BANK = '<span class="trans" lang="ru">банк</span>'
GOOGLE_BANK = '{"sentences": [{"trans": "банк"}]}'


@pytest.mark.parametrize("provider", ["google", "cambridge"])
def test_an_unreachable_only_source_reports_failure(provider: str) -> None:
    async def unavailable(url: str) -> str:
        raise FetchError("network denied")

    with pytest.raises(FetchError):
        asyncio.run(
            pipeline.translate_async(
                "bank",
                fetcher=unavailable,
                sources=replace(ALL_OFF, **{provider: True}),
            )
        )


@pytest.mark.parametrize("provider", ["google", "cambridge"])
def test_a_valid_empty_response_is_a_normal_no_match(provider: str) -> None:
    async def empty(url: str) -> str:
        return "{}" if provider == "google" else "<html>No dictionary entry</html>"

    result = asyncio.run(
        pipeline.translate_async(
            "bank", fetcher=empty, sources=replace(ALL_OFF, **{provider: True})
        )
    )

    assert result.status is TranslationStatus.EMPTY


def test_cambridge_not_found_is_a_normal_no_match() -> None:
    async def missing(url: str) -> str:
        raise FetchStatusError("no entry", status_code=404)

    result = asyncio.run(
        pipeline.translate_async(
            "unlistedword", fetcher=missing, sources=replace(ALL_OFF, cambridge=True)
        )
    )

    assert result.status is TranslationStatus.EMPTY


def test_repeated_cambridge_http_not_found_stays_a_no_match() -> None:
    requests: list[bytes] = []

    async def scenario() -> None:
        async def serve(
            reader: asyncio.StreamReader, writer: asyncio.StreamWriter
        ) -> None:
            try:
                requests.append(await reader.readuntil(b"\r\n\r\n"))
                writer.write(
                    b"HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
                )
                await writer.drain()
            finally:
                writer.close()
                await writer.wait_closed()

        server = await asyncio.start_server(serve, "127.0.0.1", 0)
        port = server.sockets[0].getsockname()[1]
        async with server, aiohttp.ClientSession() as session:
            fetch = build_async_fetcher(session, cache=None)

            async def local_fetch(url: str) -> str:
                query = url.split("?", 1)[1]
                return await fetch(f"http://127.0.0.1:{port}/dictionary?{query}")

            for _ in range(2):
                result = await pipeline.translate_async(
                    "bank",
                    fetcher=local_fetch,
                    sources=replace(ALL_OFF, cambridge=True),
                )
                assert result.status is TranslationStatus.EMPTY

    asyncio.run(scenario())
    assert len(requests) == 4, "404 must not populate the outage backoff"


@pytest.mark.parametrize("status", [429, 503])
def test_http_rate_limit_and_server_failure_keep_outage_backoff(status: int) -> None:
    requests: list[bytes] = []

    async def scenario() -> None:
        async def serve(
            reader: asyncio.StreamReader, writer: asyncio.StreamWriter
        ) -> None:
            try:
                requests.append(await reader.readuntil(b"\r\n\r\n"))
                writer.write(
                    f"HTTP/1.1 {status} Unavailable\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".encode()
                )
                await writer.drain()
            finally:
                writer.close()
                await writer.wait_closed()

        server = await asyncio.start_server(serve, "127.0.0.1", 0)
        port = server.sockets[0].getsockname()[1]
        async with server, aiohttp.ClientSession() as session:
            fetch = build_async_fetcher(session, cache=None)
            url = f"http://127.0.0.1:{port}/unavailable"
            with pytest.raises(FetchStatusError) as first:
                await fetch(url)
            assert first.value.status_code == status
            with pytest.raises(FetchError):
                await fetch(url)

    asyncio.run(scenario())
    assert len(requests) == 1, "repeat calls must not hammer an unavailable server"


@pytest.mark.parametrize("status", [403, 429, 503])
def test_cambridge_refused_or_unavailable_is_not_a_no_match(status: int) -> None:
    async def rejected(url: str) -> str:
        raise FetchStatusError("provider unavailable", status_code=status)

    with pytest.raises(FetchError):
        asyncio.run(
            pipeline.translate_async(
                "bank", fetcher=rejected, sources=replace(ALL_OFF, cambridge=True)
            )
        )


def test_google_unreadable_response_reports_failure() -> None:
    async def invalid(url: str) -> str:
        return "<html>upstream error</html>"

    with pytest.raises(FetchError):
        asyncio.run(
            pipeline.translate_async(
                "bank", fetcher=invalid, sources=replace(ALL_OFF, google=True)
            )
        )


def test_google_timeout_and_recovery_timeouts_report_failure(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(
        pipeline,
        "_PROVIDER_BUDGET",
        replace(pipeline._PROVIDER_BUDGET, google_timeout_s=0.01),
    )
    cancelled: list[str] = []

    async def never_answers(url: str) -> str:
        try:
            await asyncio.Event().wait()
        finally:
            cancelled.append(url)
        return "{}"

    with pytest.raises(FetchError):
        asyncio.run(
            pipeline.translate_async(
                "bank", fetcher=never_answers, sources=replace(ALL_OFF, google=True)
            )
        )

    assert cancelled, "the failed provider must have been attempted and cancelled"


def test_google_recovery_can_succeed_after_initial_network_failure() -> None:
    attempts: list[str] = []

    async def recovers(url: str) -> str:
        attempts.append(url)
        if "attempt=" not in url:
            raise FetchError("temporary failure")
        return GOOGLE_BANK

    result = asyncio.run(
        pipeline.translate_async(
            "bank", fetcher=recovers, sources=replace(ALL_OFF, google=True)
        )
    )

    assert result.translation_ru.text == "банк"
    assert any("attempt=" in url for url in attempts)


@pytest.mark.parametrize("cambridge_delay", [None, 0.0, 0.04])
def test_google_primary_gets_its_budget_when_cambridge_has_no_translation(
    cambridge_delay: float | None,
) -> None:
    google_requests: list[str] = []
    cancelled_google: list[str] = []

    async def slow_valid_google(url: str) -> str:
        if "dictionary.cambridge.org" in url:
            await asyncio.sleep(cambridge_delay or 0)
            return "<html>No dictionary entry</html>"
        google_requests.append(url)
        try:
            # A valid response inside the primary1.4s budget, but outside the
            # 0.3s best-effort augmentation and0.35s recovery windows.
            await asyncio.sleep(0.45)
        except asyncio.CancelledError:
            cancelled_google.append(url)
            raise
        return GOOGLE_BANK

    result = asyncio.run(
        pipeline.translate_async(
            "bank",
            fetcher=slow_valid_google,
            sources=replace(
                ALL_OFF, google=True, cambridge=cambridge_delay is not None
            ),
        )
    )

    assert result.translation_ru.text == "банк"
    assert len(google_requests) == 1, (
        "a valid primary request must finish without a retry"
    )
    assert cancelled_google == [], (
        "best-effort augmentation must not cancel the only primary"
    )


def test_google_is_still_best_effort_when_cambridge_already_translated() -> None:
    cancelled: list[str] = []

    async def translated_then_optional(url: str) -> str:
        if "dictionary.cambridge.org" in url:
            return CAMBRIDGE_BANK
        try:
            await asyncio.Event().wait()
        finally:
            cancelled.append(url)
        return "{}"

    result = asyncio.run(
        pipeline.translate_async(
            "bank",
            fetcher=translated_then_optional,
            sources=replace(ALL_OFF, google=True, cambridge=True),
        )
    )

    assert result.translation_ru.text == "банк"
    assert len(cancelled) == 1, "unneeded Google enrichment must be cancelled"


@pytest.mark.parametrize("timeout", [False, True])
def test_failed_google_recovery_after_a_valid_empty_first_response_reports_failure(
    timeout: bool,
) -> None:
    async def empty_then_fails(url: str) -> str:
        if "attempt=" not in url:
            return "{}"
        if timeout:
            await asyncio.Event().wait()
        raise FetchError("recovery unavailable")

    with pytest.raises(FetchError):
        asyncio.run(
            pipeline.translate_async(
                "bank",
                fetcher=empty_then_fails,
                sources=replace(ALL_OFF, google=True),
            )
        )


def test_cambridge_budget_timeout_reports_failure(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(
        pipeline,
        "_PROVIDER_BUDGET",
        replace(pipeline._PROVIDER_BUDGET, cambridge_en_ru_timeout_s=0.01),
    )
    cancelled: list[str] = []

    async def never_answers(url: str) -> str:
        try:
            await asyncio.Event().wait()
        finally:
            cancelled.append(url)
        return ""

    with pytest.raises(FetchError):
        asyncio.run(
            pipeline.translate_async(
                "bank",
                fetcher=never_answers,
                sources=replace(ALL_OFF, cambridge=True),
            )
        )

    assert len(cancelled) == 2, "both Cambridge page requests must be cancelled"


def test_a_working_cambridge_page_survives_the_other_page_failing() -> None:
    async def one_page(url: str) -> str:
        if "datasetsearch=english-russian" in url:
            return CAMBRIDGE_BANK
        raise FetchError("English page unavailable")

    result = asyncio.run(
        pipeline.translate_async(
            "bank", fetcher=one_page, sources=replace(ALL_OFF, cambridge=True)
        )
    )

    assert result.translation_ru.text == "банк"


def test_a_working_online_source_survives_the_other_source_failing() -> None:
    async def one_provider(url: str) -> str:
        if "translate.googleapis.com" in url:
            return GOOGLE_BANK
        raise FetchError("Cambridge unavailable")

    result = asyncio.run(
        pipeline.translate_async(
            "bank",
            fetcher=one_provider,
            sources=replace(ALL_OFF, google=True, cambridge=True),
        )
    )

    assert result.translation_ru.text == "банк"


def test_an_apple_translation_survives_failed_online_sources(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(apple, "is_available", lambda: True)
    apple_permissions: list[tuple[bool, bool]] = []

    async def local_lookup(
        *,
        text: str,
        lookup_text: str,
        source_lang: str,
        target_lang: str,
        allow_dictionary: bool,
        allow_translation: bool,
    ) -> apple.AppleLookup:
        apple_permissions.append((allow_dictionary, allow_translation))
        return apple.AppleLookup(definition=None, machine_translation="банк")

    monkeypatch.setattr(apple, "lookup", local_lookup)

    async def unavailable(url: str) -> str:
        raise FetchError("network denied")

    result = asyncio.run(
        pipeline.translate_async(
            "bank",
            fetcher=unavailable,
            sources=replace(
                ALL_OFF, google=True, cambridge=True, apple_translation=True
            ),
        )
    )

    assert result.translation_ru.text == "банк"
    assert apple_permissions == [(False, True)]


@pytest.mark.parametrize("dictionary", [False, True])
@pytest.mark.parametrize("failed_google", [False, True])
def test_cold_apple_primary_gets_its_engine_budget(
    monkeypatch: pytest.MonkeyPatch,
    dictionary: bool,
    failed_google: bool,
) -> None:
    monkeypatch.setattr(apple, "is_available", lambda: True)
    cancelled: list[bool] = []
    network_calls: list[str] = []
    lookup_ready = asyncio.Event()
    observed_budgets: list[float] = []
    resolve_apple_lookup = pipeline._resolve_apple_lookup

    async def release_primary_lookup(
        task: asyncio.Task[apple.AppleLookup],
        *,
        timeout_s: float = pipeline._APPLE_FINAL_WAIT_S,
    ) -> apple.AppleLookup | None:
        observed_budgets.append(timeout_s)
        lookup_ready.set()
        return await resolve_apple_lookup(task, timeout_s=timeout_s)

    monkeypatch.setattr(pipeline, "_resolve_apple_lookup", release_primary_lookup)

    async def cold_lookup(
        *,
        text: str,
        lookup_text: str,
        source_lang: str,
        target_lang: str,
        allow_dictionary: bool,
        allow_translation: bool,
    ) -> apple.AppleLookup:
        assert (allow_dictionary, allow_translation) == (dictionary, not dictionary)
        try:
            # Keep the primary lookup pending until the pipeline chooses its
            # budget, without relying on a loaded CI runner waking a timer.
            await lookup_ready.wait()
        except asyncio.CancelledError:
            cancelled.append(True)
            raise
        if not dictionary:
            return apple.AppleLookup(None, "банк")
        definition = apple.AppleDefinition(
            lexical=LexicalInfo(
                headword="bank",
                entries=(
                    LexicalEntry(pos="noun", senses=(LexicalSense(1, "", "банк"),)),
                ),
            ),
            dictionary="Test dictionary",
            raw="bank банк",
        )
        return apple.AppleLookup(definition, None)

    monkeypatch.setattr(apple, "lookup", cold_lookup)

    async def unavailable(url: str) -> str:
        network_calls.append(url)
        raise FetchError("network denied")

    result = asyncio.run(
        pipeline.translate_async(
            "bank",
            fetcher=unavailable,
            sources=replace(
                ALL_OFF,
                apple_dictionary=dictionary,
                apple_translation=not dictionary,
                google=failed_google,
            ),
        )
    )

    assert result.translation_ru.text == "банк"
    expected_budget = (
        apple.DEFAULT_DEFINE_TIMEOUT_S
        if dictionary
        else apple.DEFAULT_TRANSLATE_TIMEOUT_S
    )
    assert observed_budgets == [expected_budget]
    assert cancelled == [], "a valid primary Apple response must be allowed to finish"
    assert bool(network_calls) == failed_google


def test_apple_remains_bounded_enrichment_after_a_working_online_translation(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(apple, "is_available", lambda: True)
    cancelled: list[bool] = []

    async def never_finishes(
        *,
        text: str,
        lookup_text: str,
        source_lang: str,
        target_lang: str,
        allow_dictionary: bool,
        allow_translation: bool,
    ) -> apple.AppleLookup:
        try:
            await asyncio.Event().wait()
        finally:
            cancelled.append(True)
        return apple.AppleLookup(None, None)

    monkeypatch.setattr(apple, "lookup", never_finishes)

    async def online(url: str) -> str:
        return GOOGLE_BANK

    async def scenario() -> TranslationResult:
        return await asyncio.wait_for(
            pipeline.translate_async(
                "bank",
                fetcher=online,
                sources=replace(ALL_OFF, google=True, apple_translation=True),
            ),
            timeout=1.1,
        )

    result = asyncio.run(scenario())
    assert result.translation_ru.text == "банк"
    assert cancelled == [True]


def test_concurrent_and_later_requests_do_not_inherit_failures_or_consent(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(apple, "is_available", lambda: False)
    calls: list[str] = []

    async def fetcher(url: str) -> str:
        calls.append(url)
        await asyncio.sleep(0)
        if "q=bad" in url:
            raise FetchError("network denied")
        return GOOGLE_BANK if "translate.googleapis.com" in url else CAMBRIDGE_BANK

    async def scenario() -> None:
        good, bad, disabled = await asyncio.gather(
            pipeline.translate_async(
                "good", fetcher=fetcher, sources=replace(ALL_OFF, google=True)
            ),
            pipeline.translate_async(
                "bad", fetcher=fetcher, sources=replace(ALL_OFF, google=True)
            ),
            pipeline.translate_async("disabled", fetcher=fetcher, sources=ALL_OFF),
            return_exceptions=True,
        )
        assert (
            isinstance(good, TranslationResult) and good.translation_ru.text == "банк"
        )
        assert isinstance(bad, FetchError)
        assert (
            isinstance(disabled, TranslationResult)
            and disabled.status is TranslationStatus.EMPTY
        )
        await pipeline.translate_async("off", fetcher=fetcher, sources=ALL_OFF)
        later = await pipeline.translate_async("later", fetcher=fetcher)
        assert later.translation_ru.text == "банк"

    asyncio.run(scenario())
    assert not any("q=disabled" in url or "q=off" in url for url in calls)
    assert any("q=later" in url for url in calls)


def test_failed_provider_reaches_existing_session_error_callback() -> None:
    async def unavailable(url: str) -> str:
        raise FetchError("network denied")

    def start_translation(
        text: str,
        lookup: str,
        on_partial: object,
    ) -> Future[TranslationResult]:
        future: Future[TranslationResult] = Future()
        try:
            result = asyncio.run(
                pipeline.translate_async(
                    text,
                    lookup_text=lookup,
                    fetcher=unavailable,
                    sources=replace(ALL_OFF, google=True),
                )
            )
        except FetchError as exc:
            future.set_exception(exc)
        else:
            future.set_result(result)
        return future

    events: list[str] = []
    session = TranslationSession(
        start_translation=start_translation,
        on_start=lambda text: events.append("begin"),
        on_partial=lambda result: events.append("partial"),
        on_complete=lambda result: events.append("final"),
        on_error=lambda: events.append("error"),
    )
    session.run("bank", "bank", "bank")

    assert events == ["begin", "error"]
