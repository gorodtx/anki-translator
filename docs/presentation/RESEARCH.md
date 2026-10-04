# Исследование — Presentation Layer Translator

Статус на 04.10.2026: **INITIAL_BRIEF; полное исследование ещё не выполнено**. Владелец: Translator1-Distribution после принятия передачи. Требования и матрица задач: [эпик](EPIC-03-PRESENTATION-LAYER.md).

## Проверенные начальные источники

- [Screen Studio](https://screen.studio/): официальный сайт представляет продуктовые записи экрана, zoom/motion/framing. Это источник о возможностях capture; рекламные claims не измерения Translator.
- [Remotion fundamentals](https://www.remotion.dev/docs/the-fundamentals): видео задаётся React-композицией и временем/кадрами. Подходит для программируемых титров, переходов и композиции.
- [Remotion Player](https://www.remotion.dev/docs/player): та же video-композиция может воспроизводиться в React-приложении. Текущие API/размер/лицензия и необходимость React для нашего сайта требуют дальнейшей проверки.
- [21st.dev metadata](21ST-REFERENCES-2026-10-04.json): два бесплатных MCP search, шесть results. Source IDs/author/preview/video URLs сохранены; это retrieval metadata, не просмотр previews, не license approval и не импорт source.

Начальная рекомендация Main, ещё не итог research: настоящий Screen Studio capture приложения + code-based титры/переходы при необходимости. До footage можно реализовать собственный story/composition и site prototype из подтверждённых assets. Анимированную web-иллюстрацию не называть записью native-приложения.

## Что должен заполнить владелец

1. Фактический аудит нынешнего README: устаревший Linux-first CTA, English-first текст, badges и CLI на первом экране; проверить каждый проблемный claim по текущему продукту.
2. Сравнительная таблица README и лендингов: прямые источники, даты, популярность только после проверки, механика, применимость, отклонённые варианты.
3. Просмотр подходящих 21st.dev previews, выбор небольшой подборки и источник/лицензия для каждой адаптации.
4. Сравнение video tools и решение: настоящий capture, программируемая композиция, web demo, exports, license, time/cost, доступность и fallback.
5. Рекомендованный story/контент и обоснование короткого русского README; перенос полезных технических материалов.
6. Обоснованный минимальный стек сайта/демо, hosting path, build/preview и scoped проверки.
7. Реальная schema и архитектура read-only DB checkpoint; размеры, память, индекс/query plan, limits, приватность, provenance/лицензии и безопасный локальный PoC.
8. Финальная рекомендация, реализованные решения, исходники/preview/evidence и конкретные unresolved зависимости. Обновлять по мере знаний, сохранять прежние выводы с датами.
