import { extname } from "node:path";

import { SUPPORTED_TEXT_EXTENSIONS } from "./constants.js";

export function isSupportedTextFile(fileName: string): boolean {
  return SUPPORTED_TEXT_EXTENSIONS.has(extname(fileName).toLowerCase());
}

function looksBinary(text: string): boolean {
  const sample = text.slice(0, 512);
  let controlCount = 0;
  for (const char of sample) {
    const code = char.charCodeAt(0);
    if ((code >= 0 && code <= 8) || code === 65533) {
      controlCount += 1;
    }
  }
  return controlCount > 8;
}

export function extractTextFromBuffer(fileName: string, content: Buffer): string | null {
  if (!isSupportedTextFile(fileName)) {
    return null;
  }

  const text = content.toString("utf8").replace(/\u0000/g, "");
  if (!text.trim() || looksBinary(text)) {
    return null;
  }

  return text;
}
