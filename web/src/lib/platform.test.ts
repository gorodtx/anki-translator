import { describe, expect, it } from 'vitest';
import { detectPlatform } from './platform';
describe('platform recommendation', () => {
  it('does not offer a desktop build as an iPad installation', () => {
    expect(detectPlatform('Mozilla Macintosh', 'MacIntel', 5)).toBe('mobile');
    expect(detectPlatform('Android Linux', 'Linux arm', 5)).toBe('mobile');
  });
  it('distinguishes only supported OS families, not CPU or distro', () => {
    expect(detectPlatform('Macintosh', 'MacIntel')).toBe('mac');
    expect(detectPlatform('Linux', 'Linux x86_64')).toBe('linux');
    expect(detectPlatform('Windows', 'Win32')).toBe('unknown');
  });
});
