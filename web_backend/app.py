from __future__ import annotations

import asyncio
from collections import deque
from collections.abc import Awaitable, Callable
from dataclasses import asdict, dataclass
from contextlib import asynccontextmanager
from collections.abc import AsyncIterator
import os
import mimetypes
from pathlib import Path
import time

from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, ConfigDict, Field, field_validator
from starlette.types import ASGIApp, Message, Receive, Scope, Send

from translate_logic.engine import translate_async
from translate_logic.domain.models import (
    LexicalInfo,
    SourceToggles,
    TranslationResult,
    FieldValue,
)
from translate_logic.infrastructure.http.transport import FetchError
from translate_logic.infrastructure.language_base.definitions_provider import (
    DefinitionsBaseProvider,
)
from translate_logic.infrastructure.language_base.provider import LanguageBaseProvider
from translate_logic.infrastructure.language_base.multi_provider import (
    MultiLanguageBaseProvider,
)
from translate_logic.infrastructure.language_base.locations import (
    default_offline_base_dir,
)

from web_backend.offline import ModelBusyError, OfflineTranslator

MAX_TEXT_CHARS = 200
MAX_BODY_BYTES = 4096
MAX_CONCURRENT = 3
MAX_REQUESTS_PER_MINUTE = 60
REQUEST_TIMEOUT = 8.0


class BodyLimitMiddleware:
    def __init__(self, app: ASGIApp) -> None:
        self.app = app

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http" or scope.get("method") != "POST":
            await self.app(scope, receive, send)
            return
        body = bytearray()
        while True:
            message = await receive()
            if message["type"] == "http.disconnect":
                return
            chunk = message.get("body", b"")
            if len(body) + len(chunk) > MAX_BODY_BYTES:
                response = JSONResponse(
                    {"detail": "Слишком большой запрос."}, status_code=413
                )
                await response(scope, receive, send)
                return
            body.extend(chunk)
            if not message.get("more_body", False):
                break
        delivered = False

        async def bounded_receive() -> Message:
            nonlocal delivered
            if not delivered:
                delivered = True
                return {"type": "http.request", "body": bytes(body), "more_body": False}
            return await receive()

        await self.app(scope, bounded_receive, send)


class TranslateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    text: str = Field(min_length=1, max_length=MAX_TEXT_CHARS)

    @field_validator("text")
    @classmethod
    def trim_text(cls, value: str) -> str:
        text = value.strip()
        if not text:
            raise ValueError("Выделите английский текст.")
        return text


class ExamplePairResponse(BaseModel):
    en: str
    ru: str


class SenseResponse(BaseModel):
    index: int
    label: str
    translation: str
    examples: list[ExamplePairResponse]


class EntryResponse(BaseModel):
    pos: str
    senses: list[SenseResponse]


class LexicalResponse(BaseModel):
    headword: str
    ipa_uk: str
    ipa_us: str
    entries: list[EntryResponse]
    source: str

    @classmethod
    def from_domain(cls, value: LexicalInfo) -> LexicalResponse:
        return cls.model_validate(asdict(value))


class TranslateResponse(BaseModel):
    original: str
    translation: str
    status: str
    definitions: list[str]
    examples: list[str]
    lexical: LexicalResponse | None
    source: str = "shared-pipeline"


class Capabilities(BaseModel):
    language_pair: str = "en-ru"
    max_text_chars: int = MAX_TEXT_CHARS
    apple_engines: bool = False
    primary_db: bool
    fallback_db: bool
    definitions_db: bool
    history: str = "browser-session"
    anki: bool = False
    local_translation: bool = False


Engine = Callable[[str], Awaitable[TranslationResult]]


@dataclass(slots=True)
class RequestBudget:
    active: int = 0


def create_app(
    *,
    db_dir: Path | None = None,
    static_dir: Path | None = None,
    engine: Engine | None = None,
    model_dir: Path | None = None,
) -> FastAPI:
    db_root = db_dir or default_offline_base_dir()
    language_base = MultiLanguageBaseProvider(
        primary=LanguageBaseProvider(db_path=db_root / "primary.sqlite3"),
        fallback=LanguageBaseProvider(db_path=db_root / "fallback.sqlite3"),
    )
    definitions = DefinitionsBaseProvider(db_path=db_root / "definitions_pack.sqlite3")
    # This HTTP service is portable. It does not attach to the owner's desktop
    # helper, history or Anki. Native Apple sources remain in the Mac application.
    sources = SourceToggles(apple_dictionary=False, apple_translation=False)
    budget = RequestBudget()
    recent_requests: deque[float] = deque()

    async def real_engine(text: str) -> TranslationResult:
        return await translate_async(
            text,
            language_base=language_base,
            definitions_base=definitions,
            sources=sources,
        )

    run_engine = engine or real_engine
    offline = OfflineTranslator(
        model_dir or Path(os.getenv("TRANSLATOR_MODEL_DIR", "/data/model"))
    )

    @asynccontextmanager
    async def lifespan(_app: FastAPI) -> AsyncIterator[None]:
        try:
            yield
        finally:
            offline.close()

    app = FastAPI(
        title="Translator browser demo",
        docs_url=None,
        redoc_url=None,
        lifespan=lifespan,
    )
    app.add_middleware(BodyLimitMiddleware)

    @app.get("/api/health")
    async def health() -> dict[str, str]:
        return {"status": "ok", "service": "translator", "engine": "shared-pipeline"}

    @app.get("/api/capabilities")
    async def capabilities() -> Capabilities:
        return Capabilities(
            primary_db=(db_root / "primary.sqlite3").is_file(),
            fallback_db=(db_root / "fallback.sqlite3").is_file(),
            definitions_db=(db_root / "definitions_pack.sqlite3").is_file(),
            local_translation=offline.available,
        )

    @app.post("/api/translate")
    async def translate(request: TranslateRequest) -> TranslateResponse:
        now = time.monotonic()
        while recent_requests and now - recent_requests[0] >= 60:
            recent_requests.popleft()
        if len(recent_requests) >= MAX_REQUESTS_PER_MINUTE:
            raise HTTPException(
                429,
                "Слишком много запросов. Попробуйте через минуту.",
                headers={"Retry-After": "60"},
            )
        if budget.active >= MAX_CONCURRENT:
            raise HTTPException(
                503,
                "Переводчик занят. Попробуйте ещё раз.",
                headers={"Retry-After": "2"},
            )
        recent_requests.append(now)
        budget.active += 1
        try:
            source = "shared-pipeline"
            async with asyncio.timeout(REQUEST_TIMEOUT):
                try:
                    result = await run_engine(request.text)
                except FetchError:
                    if not offline.available:
                        raise
                    translation = await offline.translate(request.text)
                    result = TranslationResult(
                        translation_ru=FieldValue.from_optional(translation)
                    )
                    source = "local-opus-mt"
                if (
                    not result.translation_ru.is_present
                    and offline.available
                    and source == "shared-pipeline"
                ):
                    translation = await offline.translate(request.text)
                    result = TranslationResult(
                        translation_ru=FieldValue.from_optional(translation),
                        definitions_en=result.definitions_en,
                        examples=result.examples,
                        lexical=result.lexical,
                    )
                    source = "local-opus-mt"
            return TranslateResponse(
                original=request.text,
                source=source,
                translation=result.translation_ru.text,
                status=result.status.value,
                definitions=list(result.definitions_en[:5]),
                examples=[example.en for example in result.examples[:4]],
                lexical=LexicalResponse.from_domain(result.lexical)
                if result.lexical
                else None,
            )
        except TimeoutError as exc:
            raise HTTPException(
                504, "Перевод занял слишком много времени. Попробуйте ещё раз."
            ) from exc
        except ModelBusyError as exc:
            raise HTTPException(
                503,
                "Переводчик занят. Попробуйте ещё раз.",
                headers={"Retry-After": "2"},
            ) from exc
        except (FetchError, RuntimeError, OSError, ValueError) as exc:
            raise HTTPException(
                502, "Источник перевода временно недоступен. Попробуйте позже."
            ) from exc
        finally:
            budget.active -= 1

    dist = static_dir or Path(__file__).resolve().parents[1] / "web" / "dist"
    if dist.is_dir():
        mimetypes.add_type("font/woff2", ".woff2")
        app.mount("/", StaticFiles(directory=dist, html=True), name="web")
    return app


app = create_app()
