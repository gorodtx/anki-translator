import { Accordion, AccordionContent, AccordionItem, AccordionTrigger } from '@/components/ui/accordion';
import { repository } from '@/lib/platform';

const items = [
  ['Как попробовать перевод?', 'Выделите мышью слово или часть фразы и нажмите «Перевести». На телефоне тап по дуге выбирает всю фразу. Через «Свой текст» можно заменить её своей.'],
  ['Это настоящий перевод?', 'Да. Страница обращается к тому же Python-движку, что и приложение. Результат приходит с сервера; готового списка ответов здесь нет. Сервер использует сетевые источники и подключённые словарные базы. Apple Dictionary и Apple Translation работают в установленной версии для Mac.'],
  ['Где работает приложение?', 'Версия для Mac рассчитана на Apple Silicon и macOS 26 или новее. Также есть версия для GNOME / Arch Linux. Онлайн-демо можно открыть в браузере; установка для этого не нужна.'],
  ['Нужен ли Anki?', 'Нет. Переводчик работает самостоятельно. В установленном приложении AnkiConnect позволяет добавлять карточки в вашу коллекцию; онлайн-демо к личному Anki не подключается.'],
  ['Что происходит с введённым текстом?', 'Для перевода выделенный текст отправляется на сервер и может передаваться Google или Cambridge. История демо хранится только в памяти этой вкладки и исчезает после перезагрузки. Для пробы используйте текст без личной информации.'],
];
export default function FAQs() {
  return <section id="faq" className="faq-section" aria-labelledby="faq-title">
    <div className="faq-heading"><h2 id="faq-title">Есть вопрос?</h2><p>Несколько ответов перед установкой.</p><a href={`${repository}/issues`}>Написать нам ↗</a></div>
    <Accordion type="single" collapsible className="faq-list">
      {items.map(([question, answer]) => <AccordionItem key={question} value={question ?? ''}><AccordionTrigger>{question}</AccordionTrigger><AccordionContent><p>{answer}</p></AccordionContent></AccordionItem>)}
    </Accordion>
  </section>;
}
