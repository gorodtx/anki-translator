# Демо Translator

Перед каждой задачей по UI читать и применять `/Users/den/.agents/skills/apple-design/SKILL.md` и `/Users/den/.agents/skills/preserve-project-design/SKILL.md`. Это постоянное проектное правило; наличие файла не заявляется как автоматический hook.

React/TypeScript strict, Tailwind 4, shadcn aliases. Компоненты: `src/components/ui/`; стили: `src/index.css`; `@/` означает `src/`. Существующие Mono assets сохранять. Круговой текст не вращается. Desktop использует нативное drag selection; touch — тап. Перевод только по кнопке, без глобальных хоткеев.

Montserrat загружается локально; popup использует системный шрифт. Glass layers не перехватывают input. WebGL имеет reduced-motion/static fallback, bounded DPR, visibility pause и cleanup. Не добавлять рекламные изображения, фиктивные перевод/батарею/часы или чужое погодное содержимое.

Проверки: `npm run check`, `npm run build`, `npm test`; real browser отдельно. На Mac учитывать общий бюджет проекта 1 ГБ и останавливать собственные preview/backend/browser после проверки. Native app/user history/Anki не менять.
