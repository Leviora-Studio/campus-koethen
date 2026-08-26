import { BodyTooLargeError, readBoundedBytes, readBoundedText } from './bounded-body';

/**
 * A response whose body is produced chunk by chunk, recording how many chunks
 * were actually pulled. That count is the whole point: it is what tells a
 * streamed cap apart from a cap checked after the download finished.
 */
function chunkedResponse(chunks: string[]): { response: Response; pulled: () => number } {
  let pulled = 0;
  let index = 0;
  const stream = new ReadableStream<Uint8Array>({
    pull(controller) {
      if (index >= chunks.length) {
        controller.close();
        return;
      }
      pulled += 1;
      controller.enqueue(new TextEncoder().encode(chunks[index]));
      index += 1;
    },
  });
  return { response: new Response(stream), pulled: () => pulled };
}

describe('readBoundedBytes', () => {
  it('returns the whole body when it stays inside the limit', async () => {
    const { response } = chunkedResponse(['abc', 'def']);
    await expect(readBoundedBytes(response, 1024)).resolves.toEqual(Buffer.from('abcdef'));
  });

  it('stops the transfer instead of buffering a body it already refuses', async () => {
    const { response, pulled } = chunkedResponse(Array.from({ length: 100 }, () => 'X'.repeat(10)));

    await expect(readBoundedBytes(response, 25)).rejects.toBeInstanceOf(BodyTooLargeError);

    // The limit is passed at the third chunk (30 bytes); the stream may have
    // one more queued ahead. Anything close to 100 would mean the whole body
    // was downloaded before the limit was even looked at.
    expect(pulled()).toBeLessThan(10);
  });

  it('refuses a body that lies about (or omits) its length', async () => {
    const stream = new ReadableStream<Uint8Array>({
      pull(controller) {
        controller.enqueue(new Uint8Array(1024));
      },
    });
    // No content-length at all, and a stream that never ends by itself.
    const response = new Response(stream);
    await expect(readBoundedBytes(response, 4096)).rejects.toBeInstanceOf(BodyTooLargeError);
  });

  it('reads a body-less response as empty rather than failing', async () => {
    await expect(readBoundedBytes(new Response(null, { status: 304 }), 1024)).resolves.toEqual(
      Buffer.alloc(0),
    );
  });
});

describe('readBoundedText', () => {
  it('decodes a multi-byte sequence split across two chunks', async () => {
    const bytes = new TextEncoder().encode('Köthen');
    const stream = new ReadableStream<Uint8Array>({
      start(controller) {
        // The split falls INSIDE the two bytes of "ö".
        controller.enqueue(bytes.slice(0, 2));
        controller.enqueue(bytes.slice(2));
        controller.close();
      },
    });
    await expect(readBoundedText(new Response(stream), 1024)).resolves.toBe('Köthen');
  });

  it('counts bytes, not characters', async () => {
    // 6 characters, 7 bytes.
    const { response } = chunkedResponse(['Köthen']);
    await expect(readBoundedText(response, 6)).rejects.toBeInstanceOf(BodyTooLargeError);
  });
});
