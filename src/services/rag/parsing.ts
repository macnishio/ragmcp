import { extname } from "node:path";
import { readFile } from "node:fs/promises";

import { SUPPORTED_TEXT_EXTENSIONS } from "./constants.js";
import { extractTextFromPDF } from "./pdf-extraction.js";

export function isSupportedTextFile(fileName: string): boolean {
  const ext = extname(fileName).toLowerCase();
  return SUPPORTED_TEXT_EXTENSIONS.has(ext) || ext === '.pdf';
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

export async function extractTextFromBuffer(fileName: string, content: Buffer): Promise<string | null> {
  const ext = extname(fileName).toLowerCase();
  
  // Handle PDF files with special extraction
  if (ext === '.pdf') {
    try {
      // Create temporary file path for PDF extraction
      const fs = await import('node:fs');
      const path = await import('node:path');
      const os = await import('node:os');
      
      const tempDir = os.tmpdir();
      const tempFilePath = path.join(tempDir, `temp_${Date.now()}_${path.basename(fileName)}`);
      
      // Write buffer to temporary file
      await fs.promises.writeFile(tempFilePath, content);
      
      try {
        // Extract text from PDF
        const result = await extractTextFromPDF(tempFilePath);
        
        if (result.metadata.success && result.text.trim()) {
          return result.text;
        }
      } finally {
        // Clean up temporary file
        try {
          await fs.promises.unlink(tempFilePath);
        } catch {
          // Ignore cleanup errors
        }
      }
    } catch (error) {
      console.error('PDF extraction failed:', error);
    }
    
    return null;
  }
  
  // Handle regular text files
  if (!SUPPORTED_TEXT_EXTENSIONS.has(ext)) {
    return null;
  }

  const text = content.toString("utf8").replace(/\u0000/g, "");
  if (!text.trim() || looksBinary(text)) {
    return null;
  }

  return text;
}
