from __future__ import annotations

import asyncio
from concurrent.futures import ThreadPoolExecutor
import importlib
from pathlib import Path
from typing import Protocol, cast


class ModelBusyError(Exception):
    pass


class Tokenizer(Protocol):
    def encode(self, text: str, *, out_type: type[str]) -> list[str]: ...

    def decode(self, tokens: list[str]) -> str: ...


class Hypothesis(Protocol):
    @property
    def hypotheses(self) -> list[list[str]]: ...


class Runtime(Protocol):
    def translate_batch(
        self,
        source: list[list[str]],
        *,
        beam_size: int,
        max_decoding_length: int,
        replace_unknowns: bool,
    ) -> list[Hypothesis]: ...


class OfflineTranslator:
    """One bounded CPU inference at a time, including after HTTP cancellation.

    CTranslate2/SentencePiece are untyped native extensions. Narrow protocols
    describe only the verified API used here; their objects never enter DTOs.
    """

    def __init__(self, path: Path) -> None:
        self.path = path
        self._runtime: Runtime | None = None
        self._source: Tokenizer | None = None
        self._target: Tokenizer | None = None
        self._executor = ThreadPoolExecutor(
            max_workers=1, thread_name_prefix="demo-model"
        )
        self._pending: asyncio.Future[str] | None = None

    @property
    def available(self) -> bool:
        return all(
            (self.path / name).is_file()
            for name in ("model.bin", "config.json", "source.spm", "target.spm")
        )

    async def translate(self, text: str) -> str:
        if self._pending is not None and not self._pending.done():
            raise ModelBusyError
        self._pending = asyncio.get_running_loop().run_in_executor(
            self._executor, self._infer, text
        )
        # HTTP deadlines do not cancel the native worker or permit a new queue.
        return await asyncio.shield(self._pending)

    def _infer(self, text: str) -> str:
        if self._runtime is None:
            ct2 = importlib.import_module("ctranslate2")
            spm = importlib.import_module("sentencepiece")
            self._runtime = cast(
                Runtime,
                ct2.Translator(
                    str(self.path),
                    device="cpu",
                    compute_type="int8",
                    inter_threads=1,
                    intra_threads=1,
                    max_queued_batches=1,
                ),
            )
            self._source = cast(
                Tokenizer,
                spm.SentencePieceProcessor(model_file=str(self.path / "source.spm")),
            )
            self._target = cast(
                Tokenizer,
                spm.SentencePieceProcessor(model_file=str(self.path / "target.spm")),
            )
        assert self._source is not None and self._target is not None
        tokens = self._source.encode(text, out_type=str)
        result = self._runtime.translate_batch(
            [tokens], beam_size=1, max_decoding_length=128, replace_unknowns=True
        )
        return self._target.decode(result[0].hypotheses[0]).strip()

    def close(self) -> None:
        self._executor.shutdown(wait=False, cancel_futures=True)
