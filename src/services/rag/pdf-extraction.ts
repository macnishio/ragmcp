import { readFile } from 'node:fs/promises';
import { exec } from 'node:child_process';
import { promisify } from 'node:util';

const execAsync = promisify(exec);

export interface ExtractedText {
  text: string;
  metadata: {
    title?: string;
    author?: string;
    pageCount: number;
    success: boolean;
    error?: string;
  };
}

/**
 * Extract text from PDF file using multiple methods
 */
export async function extractTextFromPDF(filePath: string): Promise<ExtractedText> {
  const metadata: ExtractedText['metadata'] = {
    pageCount: 0,
    success: false
  };

  try {
    // Method 1: Try using pdftotext (if available)
    const pdftotextResult = await tryPdfToText(filePath);
    if (pdftotextResult.success) {
      return {
        text: pdftotextResult.text,
        metadata: { ...metadata, ...pdftotextResult.metadata, success: true }
      };
    }

    // Method 2: Try using pdf-parse (Node.js library)
    const pdfParseResult = await tryPdfParse(filePath);
    if (pdfParseResult.success) {
      return {
        text: pdfParseResult.text,
        metadata: { ...metadata, ...pdfParseResult.metadata, success: true }
      };
    }

    // Method 3: Fallback to basic text extraction
    const basicResult = await tryBasicExtraction(filePath);
    return {
      text: basicResult.text,
      metadata: { ...metadata, ...basicResult.metadata, success: basicResult.text.length > 0 }
    };

  } catch (error) {
    return {
      text: '',
      metadata: { ...metadata, success: false, error: String(error) }
    };
  }
}

/**
 * Try pdftotext command-line tool
 */
async function tryPdfToText(filePath: string): Promise<{ text: string; metadata: any; success: boolean }> {
  try {
    const { stdout, stderr } = await execAsync(`pdftotext "${filePath}" -`, { timeout: 30000 });
    if (stdout && stdout.trim().length > 0) {
      return {
        text: stdout,
        metadata: { pageCount: estimatePageCount(stdout) },
        success: true
      };
    }
  } catch (error) {
    // pdftotext not available or failed
  }
  return { text: '', metadata: {}, success: false };
}

/**
 * Try pdf-parse library
 */
async function tryPdfParse(filePath: string): Promise<{ text: string; metadata: any; success: boolean }> {
  try {
    // Dynamic import to avoid build issues
    const pdfParseModule: any = await import('pdf-parse');
    const pdfParse = pdfParseModule.default || pdfParseModule;
    const buffer = await readFile(filePath);
    const data = await pdfParse(buffer);
    
    return {
      text: data.text,
      metadata: {
        title: data.info?.Title,
        author: data.info?.Author,
        pageCount: data.numpages
      },
      success: true
    };
  } catch (error) {
    // pdf-parse not available or failed
    console.warn('PDF parsing failed:', error);
  }
  return { text: '', metadata: {}, success: false };
}

/**
 * Basic extraction attempt
 */
async function tryBasicExtraction(filePath: string): Promise<{ text: string; metadata: any; success: boolean }> {
  try {
    const buffer = await readFile(filePath);
    const text = buffer.toString('utf8', 0, Math.min(buffer.length, 1024 * 1024)); // First 1MB
    
    // Extract readable strings from binary data
    const readableText = text.replace(/[^\x20-\x7E\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FAF]/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();
    
    return {
      text: readableText,
      metadata: { pageCount: 1 },
      success: readableText.length > 100
    };
  } catch (error) {
    return { text: '', metadata: {}, success: false };
  }
}

/**
 * Estimate page count from text content
 */
function estimatePageCount(text: string): number {
  // Rough estimation: each page break or form feed suggests a new page
  const pageBreaks = (text.match(/\f/g) || []).length;
  const lineCount = text.split('\n').length;
  return Math.max(pageBreaks + 1, Math.ceil(lineCount / 60)); // Assume ~60 lines per page
}

/**
 * Check if PDF extraction tools are available
 */
export async function checkPDFExtractionSupport(): Promise<{ pdftotext: boolean; pdfParse: boolean }> {
  const pdftotext = await checkCommandExists('pdftotext');
  const pdfParse = await checkLibraryExists('pdf-parse');
  
  return { pdftotext, pdfParse };
}

async function checkCommandExists(command: string): Promise<boolean> {
  try {
    await execAsync(`which ${command}`);
    return true;
  } catch {
    try {
      await execAsync(`where ${command}`);
      return true;
    } catch {
      return false;
    }
  }
}

async function checkLibraryExists(library: string): Promise<boolean> {
  try {
    await import(library);
    return true;
  } catch {
    return false;
  }
}
