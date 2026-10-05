import {media} from './media.js';

const video = document.querySelector('#demo-video');
const empty = document.querySelector('#video-empty');
const message = document.querySelector('#video-message');
const detail = document.querySelector('#video-detail');
const caption = document.querySelector('#demo-caption');
const logo = document.querySelector('#logo');
const logoDark = document.querySelector('#logo-dark');

function asset(value) {
  if (typeof value !== 'string' || !value.startsWith('assets/')) return null;
  const url = new URL(value, location.href);
  return url.origin === location.origin && url.pathname.startsWith(new URL('assets/', location.href).pathname) ? url.href : null;
}
const logoUrl = asset(media.logo);
if (logoUrl) logo.src = logoUrl;
const logoDarkUrl = asset(media.logoDark);
if (logoDarkUrl) logoDark.srcset = logoDarkUrl;
const videoUrl = asset(media.video);
if (videoUrl) {
  video.src = videoUrl;
  const posterUrl = asset(media.poster);
  if (posterUrl) video.poster = posterUrl;
  const captionsUrl = asset(media.captions);
  if (captionsUrl) {
    const track = document.createElement('track');
    track.kind = 'captions'; track.srclang = 'ru'; track.label = 'Русские субтитры'; track.src = captionsUrl;
    video.append(track);
  }
  video.hidden = false;
  empty.hidden = true;
  caption.textContent = 'Настоящая запись приложения. Нажмите воспроизведение.';
  video.addEventListener('error', () => {
    video.hidden = true; empty.hidden = false;
    message.textContent = 'Видео пока недоступно.';
    detail.textContent = 'Попробуйте позже. Скачать приложение можно ниже.';
    caption.textContent = 'Не удалось загрузить запись приложения.';
  });
}
// No autoplay, loops, provider requests, generated frames or background timers.
