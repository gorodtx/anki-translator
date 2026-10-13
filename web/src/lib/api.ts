export interface LexicalInfo {
  headword: string;
  ipa_uk: string;
  ipa_us: string;
  source: string;
  entries: { pos: string; senses: { index: number; label: string; translation: string; examples: { en: string; ru: string }[] }[] }[];
}
export interface Translation {
  original: string;
  translation: string;
  status: 'success' | 'empty';
  definitions: string[];
  examples: string[];
  lexical: LexicalInfo | null;
}

function strings(value: unknown): value is string[] { return Array.isArray(value) && value.every(item => typeof item === 'string'); }
function record(value: unknown): value is Record<string, unknown> { return typeof value === 'object' && value !== null; }
function lexical(value: unknown): value is LexicalInfo {
  return record(value) && typeof value.headword === 'string' && typeof value.ipa_uk === 'string' && typeof value.ipa_us === 'string' && typeof value.source === 'string' && Array.isArray(value.entries) && value.entries.every(entry => record(entry) && typeof entry.pos === 'string' && Array.isArray(entry.senses) && entry.senses.every(sense => record(sense) && typeof sense.index === 'number' && typeof sense.label === 'string' && typeof sense.translation === 'string' && Array.isArray(sense.examples) && sense.examples.every(pair => record(pair) && typeof pair.en === 'string' && typeof pair.ru === 'string')));
}

export async function translate(text: string, signal: AbortSignal): Promise<Translation> {
  const response = await fetch(new URL('api/translate', new URL('./', document.baseURI)), {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ text }), signal,
  }).catch((error: unknown) => {
    if (signal.aborted) throw error;
    throw new Error('Не удалось связаться с переводчиком. Проверьте соединение и повторите.');
  });
  const value: unknown = await response.json().catch(() => { throw new Error('Сервер вернул непонятный ответ. Попробуйте ещё раз.'); });
  if (!response.ok) {
    const detail = record(value) && typeof value.detail === 'string' ? value.detail : 'Не удалось получить перевод. Попробуйте ещё раз.';
    throw new Error(detail);
  }
  if (!record(value) || typeof value.original !== 'string' || typeof value.translation !== 'string' || !['success', 'empty'].includes(String(value.status)) || !strings(value.definitions) || !strings(value.examples) || !(value.lexical === null || lexical(value.lexical))) throw new Error('Не удалось прочитать ответ переводчика.');
  return value as unknown as Translation;
}
