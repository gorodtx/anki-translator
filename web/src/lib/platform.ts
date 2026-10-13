export type Platform = 'mac' | 'linux' | 'mobile' | 'unknown';
export function detectPlatform(agent: string, platform: string, touchPoints = 0): Platform {
  if (/Android|iPhone|iPad|iPod/i.test(agent) || (/Mac/i.test(platform) && touchPoints > 1)) return 'mobile';
  if (/Mac/i.test(platform) || /Macintosh/i.test(agent)) return 'mac';
  if (/Linux/i.test(platform) || /Linux/i.test(agent)) return 'linux';
  return 'unknown';
}
export const repository = 'https://github.com/gorodtx/selection-translator';
export const macDownload = `${repository}/releases/download/v0.3.1-rc.2/Translator-0.3.1-macos-arm64.dmg`;
export const linuxDownload = `${repository}/tree/gnome#русский`;
