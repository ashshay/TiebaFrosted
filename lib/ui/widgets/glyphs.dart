import 'package:prism_ui/icons/icons.dart';

/// TiebaFrosted 专属 24 栅格矢量图标集合（与 prism_ui 图标引擎完全一致）。
abstract final class FrostedGlyphs {
  static const home = Glyph([
    GlyphPath('M10 20v-6h4v6h5v-8h3L12 3 2 12h3v8z'),
  ]);

  static const explore = Glyph([
    GlyphPath(
      'M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm2.19 12.19L6 18l3.81-8.19L18 6l-3.81 8.19z',
    ),
    GlyphCircle(12, 12, 1.1, role: GlyphRole.detail, solid: true),
  ]);

  static const bell = Glyph([
    GlyphPath(
      'M12 22c1.1 0 2-.9 2-2h-4c0 1.1.89 2 2 2zm6-6v-5c0-3.07-1.64-5.64-4.5-6.32V4c0-.83-.67-1.5-1.5-1.5s-1.5.67-1.5 1.5v.68C7.63 5.36 6 7.92 6 11v5l-2 2v1h16v-1l-2-2z',
    ),
  ]);

  static const person = Glyph([
    GlyphPath(
      'M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z',
    ),
  ]);

  static const forum = Glyph([
    GlyphPath(
      'M20 2H4c-1.1 0-2 .9-2 2v18l4-4h14c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2zm-3 12H7v-2h10v2zm0-3H7V9h10v2zm0-3H7V6h10v2z',
    ),
  ]);

  static const search = Glyph([
    GlyphPath(
      'M15.5 14h-.79l-.28-.27A6.471 6.471 0 0 0 16 9.5 6.5 6.5 0 1 0 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14z',
    ),
  ]);

  static const thumbUp = Glyph([
    GlyphPath(
      'M1 21h4V9H1v12zm22-11c0-1.1-.9-2-2-2h-6.31l.95-4.57.03-.32c0-.41-.17-.79-.44-1.06L14.17 1 7.59 7.59C7.22 7.95 7 8.45 7 9v10c0 1.1.9 2 2 2h9c.83 0 1.54-.5 1.84-1.22l3.02-7.05c.09-.23.14-.47.14-.73v-2z',
    ),
  ]);

  static const like = Glyph([
    GlyphPath(
      'M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z',
    ),
  ]);

  static const comment = Glyph([
    GlyphPath(
      'M21.99 4c0-1.1-.89-2-1.99-2H4c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h14l4 4-.01-18z',
    ),
  ]);

  static const bookmark = Glyph([
    GlyphPath(
      'M17 3H7c-1.1 0-1.99.9-1.99 2L5 21l7-3 7 3V5c0-1.1-.9-2-2-2z',
    ),
  ]);

  static const share = Glyph([
    GlyphPath(
      'M18 16.08c-.76 0-1.44.3-1.96.77L8.91 12.7c.05-.23.09-.46.09-.7s-.04-.47-.09-.7l7.05-4.11c.54.5 1.25.81 2.04.81 1.66 0 3-1.34 3-3s-1.34-3-3-3-3 1.34-3 3c0 .24.04.47.09.7L8.04 9.81C7.5 9.31 6.79 9 6 9c-1.66 0-3 1.34-3 3s1.34 3 3 3c.79 0 1.5-.31 2.04-.81l7.12 4.16c-.05.21-.08.43-.08.65 0 1.61 1.31 2.92 2.92 2.92s2.92-1.31 2.92-2.92-1.31-2.92-2.92-2.92z',
    ),
  ]);

  static const signIn = Glyph([
    GlyphPath(
      'M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z',
    ),
  ]);

  static const calendarCheck = Glyph([
    GlyphPath(
      'M19 3h-1V1h-2v2H8V1H6v2H5c-1.11 0-2 .9-2 2v14c0 1.1.89 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm0 16H5V8h14v11zm-8.46-2.46L7.4 13.4l1.41-1.41 1.73 1.72 4.65-4.65 1.41 1.42-6.06 6.06z',
    ),
  ]);

  static const wrench = Glyph([
    GlyphPath(
      'M22.7 19l-9.1-9.1c.9-2.3.4-5-1.5-6.9-2-2-5-2.4-7.4-1.3L9 6 6 9 1.6 4.7C.4 7.1.9 10.1 2.9 12.1c1.9 1.9 4.6 2.4 6.9 1.5l9.1 9.1c.4.4 1 .4 1.4 0l2.3-2.3c.5-.4.5-1.1.1-1.4z',
    ),
  ]);

  static const clock = Glyph([
    GlyphCircle(12, 12, 9, role: GlyphRole.line),
    GlyphPath('M11.5 7H13v6l4.2 2.5-0.8 1.3-4.9-3z'),
  ]);

  static const shield = Glyph([
    GlyphPath(
      'M12 1L3 5v6c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V5l-9-4z',
    ),
  ]);

  static const flame = Glyph([
    GlyphPath(
      'M13.5.67s.74 2.65.74 4.8c0 2.06-1.35 3.73-3.41 3.73-2.07 0-3.63-1.67-3.63-3.73l.03-.36C5.21 7.51 4 10.62 4 14c0 4.42 3.58 8 8 8s8-3.58 8-8C20 8.61 17.41 3.8 13.5.67z',
    ),
  ]);

  static const refresh = Glyph([
    GlyphPath(
      'M17.65 6.35A7.958 7.958 0 0 0 12 4c-4.42 0-7.99 3.58-7.99 8s3.57 8 7.99 8c3.73 0 6.84-2.55 7.73-6h-2.08A5.99 5.99 0 0 1 12 18c-3.31 0-6-2.69-6-6s2.69-6 6-6c1.66 0 3.14.69 4.22 1.78L13 11h7V4l-2.35 2.35z',
    ),
  ]);

  static const more = Glyph([
    GlyphCircle(6, 12, 1.8, solid: true),
    GlyphCircle(12, 12, 1.8, solid: true),
    GlyphCircle(18, 12, 1.8, solid: true),
  ]);

  static const add = Glyph([
    GlyphPath('M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6v2z'),
  ]);

  static const send = Glyph([
    GlyphPath('M2.01 21L23 12 2.01 3 2 10l15 2-15 2z'),
  ]);

  static const download = Glyph([
    GlyphPath('M19 9h-4V3H9v6H5l7 7 7-7zM5 18v2h14v-2H5z'),
  ]);

  static const openExternal = Glyph([
    GlyphPath(
      'M19 19H5V5h7V3H5c-1.11 0-2 .9-2 2v14c0 1.1.89 2 2 2h14c1.1 0 2-.9 2-2v-7h-2v7zM14 3v2h3.59l-9.83 9.83 1.41 1.41L19 6.41V10h2V3h-7z',
    ),
  ]);

  static const play = Glyph([GlyphPath('M8 5v14l11-7z')]);

  static const image = Glyph([
    GlyphPath(
      'M21 19V5c0-1.1-.9-2-2-2H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2zM8.5 13.5l2.5 3.01L14.5 12l4.5 6H5l3.5-4.5z',
    ),
  ]);

  static const emoji = Glyph([
    GlyphCircle(12, 12, 9, role: GlyphRole.line),
    GlyphCircle(9, 10, 1.2, solid: true),
    GlyphCircle(15, 10, 1.2, solid: true),
    GlyphPath('M8.5 14.5c.9 1.3 2.1 2 3.5 2s2.6-.7 3.5-2'),
  ]);

  static const delete = Glyph([
    GlyphPath(
      'M6 19c0 1.1.9 2 2 2h8c1.1 0 2-.9 2-2V7H6v12zM19 4h-3.5l-1-1h-5l-1 1H5v2h14V4z',
    ),
  ]);

  static const link = Glyph([
    GlyphPath(
      'M3.9 12c0-1.71 1.39-3.1 3.1-3.1h4V7H7c-2.76 0-5 2.24-5 5s2.24 5 5 5h4v-1.9H7c-1.71 0-3.1-1.39-3.1-3.1zM8 13h8v-2H8v2zm9-6h-4v1.9h4c1.71 0 3.1 1.39 3.1 3.1s-1.39 3.1-3.1 3.1h-4V17h4c2.76 0 5-2.24 5-5s-2.24-5-5-5z',
    ),
  ]);

  static const pin = Glyph([
    GlyphPath('M16 12V4h1V2H7v2h1v8l-2 2v2h5.2v6h1.6v-6H18v-2l-2-2z'),
  ]);

  static const star = Glyph([
    GlyphPath(
      'M12 17.27L18.18 21l-1.64-7.03L22 9.24l-7.19-.61L12 2 9.19 8.63 2 9.24l5.46 4.73L5.82 21z',
    ),
  ]);

  static const palette = Glyph([
    GlyphPath(
      'M12 3c-4.97 0-9 4.03-9 9s4.03 9 9 9c.83 0 1.5-.67 1.5-1.5 0-.39-.15-.74-.39-1.01-.23-.26-.38-.61-.38-.99 0-.83.67-1.5 1.5-1.5H16c2.76 0 5-2.24 5-5 0-4.42-4.03-8-9-8z',
    ),
  ]);

  static const sort = Glyph([
    GlyphPath('M3 18h6v-2H3v2zM3 6v2h18V6H3zm0 7h12v-2H3v2z'),
  ]);

  static const key = Glyph([
    GlyphPath(
      'M12.65 10C11.83 7.67 9.61 6 7 6c-3.31 0-6 2.69-6 6s2.69 6 6 6c2.61 0 4.83-1.67 5.65-4H17v4h4v-4h2v-4H12.65zM7 14c-1.1 0-2-.9-2-2s.9-2 2-2 2 .9 2 2-.9 2-2 2z',
    ),
  ]);

  static const info = Glyph([
    GlyphPath(
      'M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-6h2v6zm0-8h-2V7h2v2z',
    ),
  ]);

  static const follow = Glyph([
    GlyphPath(
      'M16 11c1.66 0 2.99-1.34 2.99-3S17.66 5 16 5c-1.66 0-3 1.34-3 3s1.34 3 3 3zm-8 0c1.66 0 2.99-1.34 2.99-3S9.66 5 8 5C6.34 5 5 6.34 5 8s1.34 3 3 3zm0 2c-2.33 0-7 1.17-7 3.5V19h14v-2.5c0-2.33-4.67-3.5-7-3.5zm8 0c-.29 0-.62.02-.97.05 1.16.84 1.97 1.97 1.97 3.45V19h6v-2.5c0-2.33-4.67-3.5-7-3.5z',
    ),
  ]);

  static const at = Glyph([
    GlyphPath(
      'M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10h5v-2h-5c-4.34 0-8-3.66-8-8s3.66-8 8-8 8 3.66 8 8v1.43c0 .79-.71 1.57-1.5 1.57s-1.5-.78-1.5-1.57V12c0-2.76-2.24-5-5-5s-5 2.24-5 5 2.24 5 5 5c1.38 0 2.64-.56 3.54-1.47.65.89 1.77 1.47 2.96 1.47 1.97 0 3.5-1.6 3.5-3.57V12c0-5.52-4.48-10-10-10zm0 13c-1.66 0-3-1.34-3-3s1.34-3 3-3 3 1.34 3 3-1.34 3-3 3z',
    ),
  ]);

  static const rule = Glyph([
    GlyphPath(
      'M14 2H6c-1.1 0-2 .9-2 2v16c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V8l-6-6zm2 16H8v-2h8v2zm0-4H8v-2h8v2zm-3-5V3.5L18.5 9H13z',
    ),
  ]);

  static const edit = Glyph([
    GlyphPath(
      'M3 17.25V21h3.75L17.81 9.94l-3.75-3.75L3 17.25zM20.71 7.04c.39-.39.39-1.02 0-1.41l-2.34-2.34a.9959.9959 0 0 0-1.41 0l-1.83 1.83 3.75 3.75 1.83-1.83z',
    ),
  ]);

  /// 「进吧」排列切换：三条横杠，表示单列列表。
  static const layoutList = Glyph([
    GlyphPath('M4 5h16v3H4zm0 5.5h16v3H4zm0 5.5h16v3H4z'),
  ]);

  /// 「进吧」排列切换：田字格，表示多列网格。
  static const layoutGrid = Glyph([
    GlyphPath('M4 4h7v7H4zm9 0h7v7h-7zM4 13h7v7H4zm9 0h7v7h-7z'),
  ]);
}
