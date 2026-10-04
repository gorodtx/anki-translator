from __future__ import annotations

import asyncio
import json
from pathlib import Path
import stat

import pytest

from desktop_app.application.examples_state import EntryExamplesState
from desktop_app.infrastructure.services.history import HistoryStore
from desktop_app.infrastructure.services.history_persistence import HistoryPersistence
from translate_logic.models import (
    Example,
    ExamplePair,
    FieldValue,
    LexicalEntry,
    LexicalInfo,
    LexicalSense,
    TranslationResult,
)


def _result(text: str = "банк") -> TranslationResult:
    return TranslationResult(
        translation_ru=FieldValue.present(text),
        definitions_en=("A financial institution.",),
        examples=(Example("The bank is closed."),),
        lexical=LexicalInfo(
            headword="bank",
            ipa_uk="baŋk",
            ipa_us="bæŋk",
            entries=(
                LexicalEntry(
                    pos="noun",
                    senses=(
                        LexicalSense(
                            index=1,
                            label="Finance",
                            translation="банк",
                            examples=(
                                ExamplePair("bank clerk", "банковский служащий"),
                            ),
                        ),
                    ),
                ),
            ),
        ),
    )


def test_restart_restores_results_lexical_examples_and_ids(tmp_path: Path) -> None:
    async def scenario() -> None:
        path = tmp_path / "profile" / "history.json"
        store = HistoryStore()
        writer = HistoryPersistence(store, path)
        await writer.start()
        first = store.add("bank", "bank", _result())
        store.add("bank account", "bank account", _result("банковский счёт"))
        store.update_examples(
            first.entry_id,
            EntryExamplesState(
                lookup_text="bank",
                visible_examples=(Example("A new example."),),
                collected_examples=(
                    Example("The bank is closed."),
                    Example("A new example."),
                ),
                exhausted=True,
            ),
        )
        expected = store.snapshot()
        await writer.close()
        reloaded = HistoryStore()
        reader = HistoryPersistence(reloaded, path)
        await reader.start()
        assert reloaded.snapshot() == expected
        assert reloaded.get(first.entry_id) == expected[1]
        assert reloaded.add("new", "new", TranslationResult.empty()).entry_id == 3
        await reader.close()
        assert stat.S_IMODE(path.stat().st_mode) == 0o600
        assert list(path.parent.glob(".history-*")) == []

    asyncio.run(scenario())


def test_history_writes_before_shutdown_and_bounds_reloaded_size(
    tmp_path: Path,
) -> None:
    async def scenario() -> None:
        path = tmp_path / "history.json"
        store = HistoryStore(max_entries=3)
        persistence = HistoryPersistence(store, path)
        await persistence.start()
        for index in range(6):
            store.add(str(index), str(index), _result())
        for _ in range(100):
            if path.exists():
                break
            await asyncio.sleep(0.01)
        assert path.exists(), "History should persist while the daemon is running"
        reloaded = HistoryStore(max_entries=2)
        reader = HistoryPersistence(reloaded, path)
        await reader.start()
        assert [item.text for item in reloaded.snapshot()] == ["5", "4"]
        assert reloaded.add("next", "next", _result()).entry_id == 7
        await reader.close()
        await persistence.close()

    asyncio.run(scenario())


@pytest.mark.parametrize(
    "raw",
    [b"{broken", b'{"version":99,"items":[]}', b'{"version":1,"items":[{"id":true}]}'],
)
def test_invalid_history_does_not_break_start_or_get_overwritten_on_open(
    tmp_path: Path, raw: bytes
) -> None:
    async def scenario() -> None:
        path = tmp_path / "history.json"
        path.write_bytes(raw)
        store = HistoryStore()
        persistence = HistoryPersistence(store, path)
        await persistence.start()
        assert store.snapshot() == []
        await persistence.close()
        assert path.read_bytes() == raw

    asyncio.run(scenario())


def test_duplicate_lookup_updates_saved_result_without_duplicating_id(
    tmp_path: Path,
) -> None:
    async def scenario() -> None:
        path = tmp_path / "history.json"
        store = HistoryStore()
        persistence = HistoryPersistence(store, path)
        await persistence.start()
        initial = store.add("bank", "bank", _result())
        updated = store.add("bank", "bank", _result("берег"))
        assert updated.entry_id == initial.entry_id
        await persistence.close()
        restored = HistoryStore()
        reader = HistoryPersistence(restored, path)
        await reader.start()
        assert restored.snapshot() == [updated]
        await reader.close()

    asyncio.run(scenario())


def test_write_failure_keeps_runtime_history_and_previous_file(tmp_path: Path) -> None:
    async def scenario() -> None:
        # A file in the parent slot makes creation impossible on every OS,
        # including privileged CI where chmod-based denial is unreliable.
        parent = tmp_path / "not-a-directory"
        parent.write_text("sentinel")
        store = HistoryStore()
        persistence = HistoryPersistence(store, parent / "history.json")
        await persistence.start()
        item = store.add("bank", "bank", _result())
        await persistence.close()
        assert store.get(item.entry_id) == item
        assert parent.read_text() == "sentinel"

    asyncio.run(scenario())


def test_no_empty_file_or_write_on_read_only_restart(tmp_path: Path) -> None:
    async def scenario() -> None:
        path = tmp_path / "history.json"
        persistence = HistoryPersistence(HistoryStore(), path)
        await persistence.start()
        await persistence.close()
        assert not path.exists()
        store = HistoryStore()
        writer = HistoryPersistence(store, path)
        await writer.start()
        store.add("bank", "bank", _result())
        await writer.close()
        before = path.stat().st_mtime_ns
        payload = json.loads(path.read_text())
        reader = HistoryPersistence(HistoryStore(), path)
        await reader.start()
        await reader.close()
        assert path.stat().st_mtime_ns == before
        assert json.loads(path.read_text()) == payload

    asyncio.run(scenario())
