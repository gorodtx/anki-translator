"""Bounded, atomic history storage; disk I/O runs outside the UI/IPC loop."""

from __future__ import annotations

import asyncio
import json
import logging
import os
from pathlib import Path
import tempfile
from typing import cast

from desktop_app.application.examples_state import EntryExamplesState
from desktop_app.application.history import HistoryItem
from desktop_app.config import JsonValue
from desktop_app.infrastructure.services.history import HistoryStore
from translate_logic.models import (
    Example,
    ExamplePair,
    FieldValue,
    LexicalEntry,
    LexicalInfo,
    LexicalSense,
    TranslationResult,
)

type JsonObject = dict[str, JsonValue]

logger = logging.getLogger(__name__)
_MAX_BYTES = 8 * 1024 * 1024
_VERSION = 1


class HistoryPersistence:
    def __init__(self, store: HistoryStore, path: Path) -> None:
        self._store = store
        self._path = path
        self._changed = asyncio.Event()
        self._dirty = False
        self._closing = False
        self._task: asyncio.Task[None] | None = None

    async def start(self) -> None:
        items = await asyncio.to_thread(_read, self._path)
        self._store.restore(items)
        self._store.on_change = self._notify
        self._task = asyncio.create_task(self._run(), name="persist-history")

    async def close(self) -> None:
        self._store.on_change = None
        self._closing = True
        self._changed.set()
        if self._task is not None:
            await self._task
            self._task = None

    def _notify(self) -> None:
        self._dirty = True
        self._changed.set()

    async def _run(self) -> None:
        while True:
            await self._changed.wait()
            dirty = self._dirty
            self._dirty = False
            self._changed.clear()
            # close() wakes the writer even when nothing changed. Avoid
            # replacing a corrupt/unsupported file merely by opening the app.
            if dirty:
                items = self._store.snapshot()
                try:
                    await asyncio.to_thread(_write, self._path, items)
                except (OSError, ValueError):
                    logger.warning("History could not be saved", exc_info=True)
            if self._closing and not self._dirty:
                return


def _read(path: Path) -> list[HistoryItem]:
    try:
        with path.open("rb") as file:
            raw = file.read(_MAX_BYTES + 1)
        if len(raw) > _MAX_BYTES:
            raise ValueError("History file exceeds its size limit")
        payload: object = json.loads(raw)
        data = _object(payload)
        if data.get("version") != _VERSION:
            raise ValueError("Unsupported history version")
        items = [_item(_object(value)) for value in _list(data.get("items"))]
        ids = [item.entry_id for item in items]
        if len(set(ids)) != len(ids):
            raise ValueError("Duplicate history IDs")
        return items
    except FileNotFoundError:
        return []
    except (OSError, ValueError, TypeError, KeyError):
        logger.warning("History could not be loaded; starting empty", exc_info=True)
        return []


def _write(path: Path, items: list[HistoryItem]) -> None:
    payload: JsonObject = {
        "version": _VERSION,
        "items": [_encode_item(item) for item in items],
    }
    raw = json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode()
    if len(raw) > _MAX_BYTES:
        raise ValueError("History snapshot exceeds its size limit")
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, name = tempfile.mkstemp(prefix=".history-", dir=path.parent)
    temporary = Path(name)
    try:
        with os.fdopen(descriptor, "wb") as file:
            file.write(raw)
            file.flush()
            os.fsync(file.fileno())
        temporary.replace(path)
    finally:
        temporary.unlink(missing_ok=True)


def _encode_item(item: HistoryItem) -> JsonObject:
    examples = item.examples_state
    return {
        "id": item.entry_id,
        "text": item.text,
        "lookup": item.lookup_text,
        "translation": item.result.translation_ru.text,
        "definitions": list(item.result.definitions_en),
        "examples": [example.en for example in item.result.examples],
        "lexical": _encode_lexical(item.result.lexical),
        "examples_state": {
            "lookup": examples.lookup_text,
            "visible": [example.en for example in examples.visible_examples],
            "collected": [example.en for example in examples.collected_examples],
            "exhausted": examples.exhausted,
        },
    }


def _encode_lexical(info: LexicalInfo | None) -> JsonValue:
    if info is None:
        return None
    entries: list[JsonValue] = []
    for entry in info.entries:
        senses: list[JsonValue] = [
            {
                "index": sense.index,
                "label": sense.label,
                "translation": sense.translation,
                "examples": [{"en": pair.en, "ru": pair.ru} for pair in sense.examples],
            }
            for sense in entry.senses
        ]
        entries.append({"pos": entry.pos, "senses": senses})
    return {
        "headword": info.headword,
        "ipa_uk": info.ipa_uk,
        "ipa_us": info.ipa_us,
        "source": info.source,
        "entries": entries,
    }


def _item(data: dict[str, object]) -> HistoryItem:
    entry_id = _integer(data["id"])
    if entry_id <= 0:
        raise ValueError("History IDs must be positive")
    state = _object(data["examples_state"])
    exhausted = state["exhausted"]
    if not isinstance(exhausted, bool):
        raise ValueError("Invalid exhausted flag")
    return HistoryItem(
        entry_id=entry_id,
        text=_string(data["text"]),
        lookup_text=_string(data["lookup"]),
        result=TranslationResult(
            translation_ru=FieldValue.present(_string(data["translation"])),
            definitions_en=_strings(data["definitions"]),
            examples=tuple(Example(text) for text in _strings(data["examples"])),
            lexical=_lexical(data["lexical"]),
        ),
        examples_state=EntryExamplesState(
            lookup_text=_string(state["lookup"]),
            visible_examples=tuple(
                Example(text) for text in _strings(state["visible"])
            ),
            collected_examples=tuple(
                Example(text) for text in _strings(state["collected"])
            ),
            exhausted=exhausted,
        ),
    )


def _lexical(value: object) -> LexicalInfo | None:
    if value is None:
        return None
    data = _object(value)
    entries: list[LexicalEntry] = []
    for raw_entry in _list(data["entries"]):
        entry = _object(raw_entry)
        senses: list[LexicalSense] = []
        for raw_sense in _list(entry["senses"]):
            sense = _object(raw_sense)
            pairs = [_object(pair) for pair in _list(sense["examples"])]
            senses.append(
                LexicalSense(
                    index=_integer(sense["index"]),
                    label=_string(sense["label"]),
                    translation=_string(sense["translation"]),
                    examples=tuple(
                        ExamplePair(_string(pair["en"]), _string(pair["ru"]))
                        for pair in pairs
                    ),
                )
            )
        entries.append(LexicalEntry(pos=_string(entry["pos"]), senses=tuple(senses)))
    return LexicalInfo(
        headword=_string(data["headword"]),
        ipa_uk=_string(data["ipa_uk"]),
        ipa_us=_string(data["ipa_us"]),
        source=_string(data["source"]),
        entries=tuple(entries),
    )


def _object(value: object) -> dict[str, object]:
    if not isinstance(value, dict) or not all(isinstance(key, str) for key in value):
        raise ValueError("Expected an object")
    return cast(dict[str, object], value)


def _list(value: object) -> list[object]:
    if not isinstance(value, list):
        raise ValueError("Expected a list")
    return cast(list[object], value)


def _string(value: object) -> str:
    if not isinstance(value, str):
        raise ValueError("Expected a string")
    return value


def _strings(value: object) -> tuple[str, ...]:
    return tuple(_string(item) for item in _list(value))


def _integer(value: object) -> int:
    if not isinstance(value, int) or isinstance(value, bool):
        raise ValueError("Expected an integer")
    return value
