// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

/**
 * A deliberately strict reader for the XML subset our own map assets use.
 *
 * This is an ALLOWLIST parser, not a general XML implementation: anything it
 * does not explicitly understand is an error rather than a best-effort guess.
 * That is the point. The map SVG is a versioned asset we author ourselves, so
 * a construct the reader has never seen is far more likely to be a mistake (or
 * something smuggled in) than a legitimate feature, and failing loudly beats
 * silently shipping it into the app bundle.
 *
 * Consequences of that stance, all intentional:
 *  - no DOCTYPE, therefore no entity expansion attack surface at all;
 *  - no CDATA, no processing instructions beyond the leading XML declaration;
 *  - only the five standard entities plus numeric character references.
 *
 * Being dependency-free matches the house style of `packages/openapi`.
 */

export class SvgParseError extends Error {
  constructor(message) {
    super(message);
    this.name = 'SvgParseError';
  }
}

const NAME_START = /[A-Za-z_:]/;
const NAME_CHAR = /[-A-Za-z0-9_:.]/;

/** Elements that must never appear in a bundled map asset. */
const FORBIDDEN_ELEMENTS = new Set([
  'script',
  'foreignobject',
  'image',
  'iframe',
  'embed',
  'object',
  'audio',
  'video',
  'animation',
  'handler',
  'listener',
]);

const HREF_ATTRS = new Set(['href', 'xlink:href']);

function decodeEntities(raw, where) {
  return raw.replace(/&(#x?[0-9A-Fa-f]+|[A-Za-z][A-Za-z0-9]*);/g, (match, body) => {
    switch (body) {
      case 'amp':
        return '&';
      case 'lt':
        return '<';
      case 'gt':
        return '>';
      case 'quot':
        return '"';
      case 'apos':
        return "'";
      default:
        break;
    }
    if (body.startsWith('#')) {
      const hex = body[1] === 'x' || body[1] === 'X';
      const code = Number.parseInt(hex ? body.slice(2) : body.slice(1), hex ? 16 : 10);
      if (Number.isFinite(code) && code > 0 && code <= 0x10ffff) {
        return String.fromCodePoint(code);
      }
    }
    throw new SvgParseError(`Unsupported entity "${match}" in ${where}`);
  });
}

/**
 * Parses `text` into a lossless node tree.
 *
 * Node shapes: `{ type: 'element', name, attrs, children }`,
 * `{ type: 'text', value }`, `{ type: 'comment', value }`.
 */
export function parseSvgDocument(text) {
  if (typeof text !== 'string' || text.length === 0) {
    throw new SvgParseError('Empty document');
  }
  if (/<!DOCTYPE/i.test(text)) {
    throw new SvgParseError('DOCTYPE declarations are not allowed');
  }
  if (text.includes('<![CDATA[')) {
    throw new SvgParseError('CDATA sections are not allowed');
  }

  let index = 0;

  // The XML declaration is the only processing instruction we accept, and only
  // as the very first thing in the document.
  const declaration = /^\s*<\?xml[^>]*\?>/.exec(text);
  if (declaration) {
    index = declaration[0].length;
  }
  if (text.includes('<?', index)) {
    throw new SvgParseError('Processing instructions are not allowed');
  }

  const stack = [];
  let root = null;

  const appendChild = (node) => {
    if (stack.length === 0) {
      if (node.type === 'element') {
        if (root) throw new SvgParseError('Multiple root elements');
        root = node;
      }
      // Whitespace and comments outside the root are simply dropped.
      return;
    }
    stack[stack.length - 1].children.push(node);
  };

  while (index < text.length) {
    const next = text.indexOf('<', index);

    if (next === -1) {
      const trailing = text.slice(index);
      if (trailing.trim().length > 0 && stack.length > 0) {
        appendChild({ type: 'text', value: decodeEntities(trailing, 'text') });
      }
      break;
    }

    if (next > index) {
      const chunk = text.slice(index, next);
      if (stack.length > 0) {
        appendChild({ type: 'text', value: decodeEntities(chunk, 'text') });
      } else if (chunk.trim().length > 0) {
        throw new SvgParseError('Text outside the root element');
      }
    }

    if (text.startsWith('<!--', next)) {
      const end = text.indexOf('-->', next + 4);
      if (end === -1) throw new SvgParseError('Unterminated comment');
      appendChild({ type: 'comment', value: text.slice(next + 4, end) });
      index = end + 3;
      continue;
    }

    if (text.startsWith('</', next)) {
      const end = text.indexOf('>', next);
      if (end === -1) throw new SvgParseError('Unterminated closing tag');
      const name = text.slice(next + 2, end).trim();
      const open = stack.pop();
      if (!open) throw new SvgParseError(`Unexpected closing tag </${name}>`);
      if (open.name !== name) {
        throw new SvgParseError(`Closing tag </${name}> does not match <${open.name}>`);
      }
      index = end + 1;
      continue;
    }

    if (text.startsWith('<!', next)) {
      throw new SvgParseError('Declarations are not allowed');
    }

    // --- opening (possibly self-closing) tag ---------------------------------
    let cursor = next + 1;
    if (!NAME_START.test(text[cursor] ?? '')) {
      throw new SvgParseError(`Malformed tag at offset ${next}`);
    }
    let nameEnd = cursor;
    while (nameEnd < text.length && NAME_CHAR.test(text[nameEnd])) nameEnd += 1;
    const name = text.slice(cursor, nameEnd);
    cursor = nameEnd;

    const attrs = {};
    for (;;) {
      while (cursor < text.length && /\s/.test(text[cursor])) cursor += 1;
      if (cursor >= text.length) throw new SvgParseError(`Unterminated tag <${name}>`);

      if (text.startsWith('/>', cursor)) {
        const node = { type: 'element', name, attrs, children: [] };
        appendChild(node);
        if (!root && stack.length === 0) root = node;
        cursor += 2;
        break;
      }
      if (text[cursor] === '>') {
        const node = { type: 'element', name, attrs, children: [] };
        appendChild(node);
        if (!root && stack.length === 0) root = node;
        stack.push(node);
        cursor += 1;
        break;
      }

      let attrEnd = cursor;
      if (!NAME_START.test(text[attrEnd] ?? '')) {
        throw new SvgParseError(`Malformed attribute in <${name}>`);
      }
      while (attrEnd < text.length && NAME_CHAR.test(text[attrEnd])) attrEnd += 1;
      const attrName = text.slice(cursor, attrEnd);
      cursor = attrEnd;

      while (cursor < text.length && /\s/.test(text[cursor])) cursor += 1;
      if (text[cursor] !== '=') {
        throw new SvgParseError(`Attribute "${attrName}" in <${name}> has no value`);
      }
      cursor += 1;
      while (cursor < text.length && /\s/.test(text[cursor])) cursor += 1;

      const quote = text[cursor];
      if (quote !== '"' && quote !== "'") {
        throw new SvgParseError(`Attribute "${attrName}" in <${name}> is not quoted`);
      }
      const valueEnd = text.indexOf(quote, cursor + 1);
      if (valueEnd === -1) {
        throw new SvgParseError(`Unterminated value for "${attrName}" in <${name}>`);
      }
      if (Object.hasOwn(attrs, attrName)) {
        throw new SvgParseError(`Duplicate attribute "${attrName}" in <${name}>`);
      }
      attrs[attrName] = decodeEntities(text.slice(cursor + 1, valueEnd), `attribute "${attrName}"`);
      cursor = valueEnd + 1;
    }

    index = cursor;
  }

  if (stack.length > 0) {
    throw new SvgParseError(`Unclosed element <${stack[stack.length - 1].name}>`);
  }
  if (!root) {
    throw new SvgParseError('Document has no root element');
  }
  if (root.name !== 'svg') {
    throw new SvgParseError(`Root element must be <svg>, found <${root.name}>`);
  }
  return root;
}

/** Depth-first walk over element nodes. */
export function* walkElements(node) {
  if (node.type !== 'element' && node.name !== 'svg') return;
  yield node;
  for (const child of node.children ?? []) {
    if (child.type === 'element' || child.name) {
      yield* walkElements(child);
    }
  }
}

function localName(name) {
  const colon = name.indexOf(':');
  return (colon === -1 ? name : name.slice(colon + 1)).toLowerCase();
}

/** Every `url(...)` target that is not a local `#fragment`. */
function externalUrlTargets(value) {
  const out = [];
  for (const match of value.matchAll(/url\(\s*(['"]?)([^)'"]*)\1\s*\)/gi)) {
    const target = match[2].trim();
    if (!target.startsWith('#')) out.push(target);
  }
  return out;
}

/**
 * Reports every construct that must not survive into a bundled asset.
 * Returns human-readable strings; an empty array means the document is clean.
 */
export function findUnsafe(root) {
  const problems = [];

  for (const element of walkElements(root)) {
    const local = localName(element.name);

    if (FORBIDDEN_ELEMENTS.has(local)) {
      problems.push(`forbidden element <${element.name}>`);
    }

    for (const [attr, rawValue] of Object.entries(element.attrs ?? {})) {
      const value = String(rawValue);
      const lowerAttr = attr.toLowerCase();
      const compact = value.replace(/\s+/g, '').toLowerCase();

      if (lowerAttr.startsWith('on')) {
        problems.push(`event handler attribute "${attr}" on <${element.name}>`);
      }
      if (compact.includes('javascript:') || compact.includes('data:text/html')) {
        problems.push(`unsafe URL scheme in "${attr}" on <${element.name}>`);
      }
      if (HREF_ATTRS.has(lowerAttr) && !value.startsWith('#')) {
        problems.push(`non-local ${attr}="${value}" on <${element.name}>`);
      }
      for (const target of externalUrlTargets(value)) {
        problems.push(`external url(${target}) in "${attr}" on <${element.name}>`);
      }
    }

    if (local === 'style') {
      const css = (element.children ?? [])
        .filter((child) => child.type === 'text')
        .map((child) => child.value)
        .join('');
      if (/@import/i.test(css)) {
        problems.push('@import in an inline <style> block');
      }
      for (const target of externalUrlTargets(css)) {
        problems.push(`external url(${target}) in an inline <style> block`);
      }
    }
  }

  return problems;
}

/** Every element carrying a `data-room-key`, in document order. */
export function findRooms(root) {
  const rooms = [];
  for (const element of walkElements(root)) {
    if (element.attrs && typeof element.attrs['data-room-key'] === 'string') {
      rooms.push(element);
    }
  }
  return rooms;
}
