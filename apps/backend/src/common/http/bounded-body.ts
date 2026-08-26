/**
 * Reading an upstream body without letting it decide how much memory we spend.
 *
 * Every client in this codebase declares a byte limit for what it is willing to
 * accept. A limit checked AFTER `response.text()` is not a limit: by then the
 * whole body is already on the heap, and the only real bound left is the amount
 * of memory the process happens to have. `Content-Length` does not close that
 * gap either — it is a claim, it is frequently absent (chunked transfers are the
 * norm for the feeds this API reads), and nothing forces it to be true.
 *
 * So the cap is enforced WHILE reading: chunks are counted as they arrive and
 * the transfer is cancelled the moment the limit is passed, before the next one
 * is pulled.
 */

/** The body passed the limit. Each caller maps this onto its own error type. */
export class BodyTooLargeError extends Error {
  constructor(public readonly maxBytes: number) {
    super(`The response body exceeded the ${maxBytes} byte limit.`);
    this.name = 'BodyTooLargeError';
  }
}

/**
 * Reads the body into a buffer, refusing it as soon as it passes `maxBytes`.
 *
 * A response without a body (304, 204, HEAD) reads as empty rather than
 * failing — "nothing to read" is not an error here.
 *
 * @throws {BodyTooLargeError} once the received bytes exceed `maxBytes`.
 */
export async function readBoundedBytes(response: Response, maxBytes: number): Promise<Buffer> {
  // Typed explicitly: the DOM lib declares `body` as `ReadableStream<any>`,
  // and an `any` chunk would silently disable every check below it.
  const body = response.body as ReadableStream<Uint8Array> | null;
  if (!body) {
    return Buffer.alloc(0);
  }

  const reader: ReadableStreamDefaultReader<Uint8Array> = body.getReader();
  const chunks: Buffer[] = [];
  let total = 0;

  try {
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      if (value === undefined) continue;

      total += value.byteLength;
      if (total > maxBytes) {
        // Stop the transfer instead of finishing a download we already refuse.
        await reader.cancel();
        throw new BodyTooLargeError(maxBytes);
      }
      // Copies, deliberately: the view handed out by the reader is not ours to
      // keep hold of.
      chunks.push(Buffer.from(value));
    }
  } finally {
    reader.releaseLock();
  }

  return Buffer.concat(chunks, total);
}

/**
 * {@link readBoundedBytes}, decoded as UTF-8.
 *
 * The limit counts BYTES, not characters: it exists to bound memory, and a
 * character count would understate a body of multi-byte text. Decoding happens
 * once over the assembled buffer, so a multi-byte sequence split across two
 * chunks is never mangled.
 */
export async function readBoundedText(response: Response, maxBytes: number): Promise<string> {
  return (await readBoundedBytes(response, maxBytes)).toString('utf8');
}
