import { sanitizeBlocks } from './content-blocks';

describe('sanitizeBlocks', () => {
  it('returns an empty result for nullish or non-array input', () => {
    expect(sanitizeBlocks(null)).toEqual({ blocks: [], droppedBlockTypes: [] });
    expect(sanitizeBlocks(undefined)).toEqual({ blocks: [], droppedBlockTypes: [] });
    expect(sanitizeBlocks('not an array')).toEqual({ blocks: [], droppedBlockTypes: [] });
  });

  it('keeps a paragraph with its inline text', () => {
    const { blocks, droppedBlockTypes } = sanitizeBlocks([
      { type: 'paragraph', children: [{ type: 'text', text: 'Hallo' }] },
    ]);
    expect(droppedBlockTypes).toEqual([]);
    expect(blocks).toEqual([{ type: 'paragraph', children: [{ type: 'text', text: 'Hallo' }] }]);
  });

  it('preserves inline text marks', () => {
    const { blocks } = sanitizeBlocks([
      {
        type: 'paragraph',
        children: [{ type: 'text', text: 'fett', bold: true, italic: false, code: true }],
      },
    ]);
    expect(blocks[0]).toEqual({
      type: 'paragraph',
      children: [{ type: 'text', text: 'fett', bold: true, code: true }],
    });
  });

  it('clamps a heading level into the supported range', () => {
    const { blocks } = sanitizeBlocks([
      { type: 'heading', level: 99, children: [{ type: 'text', text: 'H' }] },
      { type: 'heading', level: 0, children: [{ type: 'text', text: 'H' }] },
      { type: 'heading', children: [{ type: 'text', text: 'H' }] },
    ]);
    expect(blocks.map((b) => (b as { level: number }).level)).toEqual([6, 1, 2]);
  });

  it('keeps lists and their items', () => {
    const { blocks } = sanitizeBlocks([
      {
        type: 'list',
        format: 'ordered',
        children: [{ type: 'list-item', children: [{ type: 'text', text: 'Eins' }] }],
      },
    ]);
    expect(blocks).toEqual([
      {
        type: 'list',
        format: 'ordered',
        children: [{ type: 'list-item', children: [{ type: 'text', text: 'Eins' }] }],
      },
    ]);
  });

  it('defaults an unknown list format to unordered', () => {
    const { blocks } = sanitizeBlocks([{ type: 'list', format: 'weird', children: [] }]);
    expect((blocks[0] as { format: string }).format).toBe('unordered');
  });

  it('drops an unknown block type and reports it instead of throwing', () => {
    const { blocks, droppedBlockTypes } = sanitizeBlocks([
      { type: 'paragraph', children: [{ type: 'text', text: 'ok' }] },
      { type: 'some-future-embed', payload: { anything: true } },
      { type: 'code', children: [{ type: 'text', text: 'x' }] },
    ]);
    expect(blocks).toHaveLength(1);
    expect(droppedBlockTypes.sort()).toEqual(['code', 'some-future-embed']);
  });

  it('reports each dropped type only once', () => {
    const { droppedBlockTypes } = sanitizeBlocks([
      { type: 'code' },
      { type: 'code' },
      { type: 'code' },
    ]);
    expect(droppedBlockTypes).toEqual(['code']);
  });

  it('records a dropped entry for a malformed block without a usable type', () => {
    const { blocks, droppedBlockTypes } = sanitizeBlocks([null, 42, {}, { type: 123 }]);
    expect(blocks).toEqual([]);
    expect(droppedBlockTypes).toEqual(['unknown']);
  });

  describe('link safety', () => {
    it('keeps https, mailto and tel links', () => {
      const { blocks } = sanitizeBlocks([
        {
          type: 'paragraph',
          children: [
            { type: 'link', url: 'https://example.org', children: [{ type: 'text', text: 'a' }] },
            { type: 'link', url: 'mailto:a@example.org', children: [{ type: 'text', text: 'b' }] },
            { type: 'link', url: 'tel:+4900000', children: [{ type: 'text', text: 'c' }] },
          ],
        },
      ]);
      const children = (blocks[0] as { children: unknown[] }).children;
      expect(children).toHaveLength(3);
    });

    it('strips a javascript: link but keeps its visible text', () => {
      const { blocks } = sanitizeBlocks([
        {
          type: 'paragraph',
          children: [
            {
              type: 'link',
              url: 'javascript:alert(1)',
              children: [{ type: 'text', text: 'klick' }],
            },
          ],
        },
      ]);
      expect((blocks[0] as { children: unknown[] }).children).toEqual([
        { type: 'text', text: 'klick' },
      ]);
    });

    it('strips plain http and data links', () => {
      const { blocks } = sanitizeBlocks([
        {
          type: 'paragraph',
          children: [
            {
              type: 'link',
              url: 'http://insecure.example',
              children: [{ type: 'text', text: 'x' }],
            },
            {
              type: 'link',
              url: 'data:text/html,<script>',
              children: [{ type: 'text', text: 'y' }],
            },
          ],
        },
      ]);
      expect((blocks[0] as { children: unknown[] }).children).toEqual([
        { type: 'text', text: 'x' },
        { type: 'text', text: 'y' },
      ]);
    });
  });

  describe('images', () => {
    it('publishes an image on this API, not on the CMS', () => {
      // The client must never fetch from Strapi (AGENTS.md §2.1), and the
      // local upload provider hands back a relative path a phone cannot
      // resolve at all.
      const { blocks } = sanitizeBlocks([
        {
          type: 'image',
          image: {
            url: '/uploads/pic_abc123.png',
            alternativeText: 'Alt',
            width: 800,
            height: 600,
          },
        },
      ]);
      expect(blocks[0]).toEqual({
        type: 'image',
        url: '/v1/media/uploads/pic_abc123.png',
        alternativeText: 'Alt',
        width: 800,
        height: 600,
      });
    });

    it('rewrites a remote provider URL onto this API too', () => {
      const { blocks } = sanitizeBlocks([
        { type: 'image', image: { url: 'https://cdn.example/uploads/pic.png' } },
      ]);
      expect(blocks[0]).toMatchObject({ url: '/v1/media/uploads/pic.png' });
      expect(JSON.stringify(blocks)).not.toContain('cdn.example');
    });

    it('drops an image that is not in the upload directory', () => {
      const { blocks, droppedBlockTypes } = sanitizeBlocks([
        { type: 'image', image: { url: 'https://cdn.example/etc/passwd' } },
      ]);
      expect(blocks).toEqual([]);
      expect(droppedBlockTypes).toEqual(['image']);
    });

    it('drops an image without a url', () => {
      const { blocks } = sanitizeBlocks([{ type: 'image', image: {} }]);
      expect(blocks).toEqual([]);
    });
  });

  it('never leaks Strapi internals from a block', () => {
    const { blocks } = sanitizeBlocks([
      {
        type: 'paragraph',
        documentId: 'abc123',
        attributes: { secret: true },
        children: [{ type: 'text', text: 'ok', documentId: 'xyz' }],
      },
    ]);
    expect(JSON.stringify(blocks)).not.toContain('documentId');
    expect(JSON.stringify(blocks)).not.toContain('attributes');
  });
});
