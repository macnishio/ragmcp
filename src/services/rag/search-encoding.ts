/**
 * Encoding utilities for Japanese text search
 */

/**
 * Normalize Japanese text for better search matching
 */
export function normalizeJapaneseText(text: string): string {
  return text
    // Normalize to NFKC form (handles half-width katakana, etc.)
    .normalize('NFKC')
    // Convert to lowercase for case-insensitive search
    .toLowerCase()
    // Remove extra whitespace
    .replace(/\s+/g, ' ')
    .trim();
}

/**
 * Prepare search query with multiple encoding variations
 */
export function prepareSearchVariations(query: string): string[] {
  const normalized = normalizeJapaneseText(query);
  const variations = new Set<string>();
  
  // Original normalized query
  variations.add(normalized);
  
  // Add hiragana to katakana conversions
  variations.add(hiraganaToKatakana(normalized));
  variations.add(katakanaToHiragana(normalized));
  
  // Add romaji variations (basic)
  variations.add(toRomaji(normalized));
  
  // Add common character variations
  variations.add(replaceCommonCharacters(normalized));
  
  return Array.from(variations).filter(v => v.length > 0);
}

/**
 * Convert hiragana to katakana
 */
function hiraganaToKatakana(text: string): string {
  return text.replace(/[\u3041-\u3096]/g, (char) => {
    const code = char.charCodeAt(0);
    return String.fromCharCode(code + 0x60); // Convert to katakana
  });
}

/**
 * Convert katakana to hiragana
 */
function katakanaToHiragana(text: string): string {
  return text.replace(/[\u30A1-\u30F6]/g, (char) => {
    const code = char.charCodeAt(0);
    return String.fromCharCode(code - 0x60); // Convert to hiragana
  });
}

/**
 * Basic romaji conversion (simplified)
 */
function toRomaji(text: string): string {
  const romajiMap: { [key: string]: string } = {
    'あ': 'a', 'い': 'i', 'う': 'u', 'え': 'e', 'お': 'o',
    'か': 'ka', 'き': 'ki', 'く': 'ku', 'け': 'ke', 'こ': 'ko',
    'が': 'ga', 'ぎ': 'gi', 'ぐ': 'gu', 'げ': 'ge', 'ご': 'go',
    'さ': 'sa', 'し': 'shi', 'す': 'su', 'せ': 'se', 'そ': 'so',
    'ざ': 'za', 'じ': 'ji', 'ず': 'zu', 'ぜ': 'ze', 'ぞ': 'zo',
    'た': 'ta', 'ち': 'chi', 'つ': 'tsu', 'て': 'te', 'と': 'to',
    'だ': 'da', 'ぢ': 'ji', 'づ': 'zu', 'で': 'de', 'ど': 'do',
    'な': 'na', 'に': 'ni', 'ぬ': 'nu', 'ね': 'ne', 'の': 'no',
    'は': 'ha', 'ひ': 'hi', 'ふ': 'fu', 'へ': 'he', 'ほ': 'ho',
    'ば': 'ba', 'び': 'bi', 'ぶ': 'bu', 'べ': 'be', 'ぼ': 'bo',
    'ぱ': 'pa', 'ぴ': 'pi', 'ぷ': 'pu', 'ぺ': 'pe', 'ぽ': 'po',
    'ま': 'ma', 'み': 'mi', 'む': 'mu', 'め': 'me', 'も': 'mo',
    'や': 'ya', 'ゆ': 'yu', 'よ': 'yo',
    'ら': 'ra', 'り': 'ri', 'る': 'ru', 'れ': 're', 'ろ': 'ro',
    'わ': 'wa', 'を': 'wo', 'ん': 'n',
    
    // Katakana
    'ア': 'a', 'イ': 'i', 'ウ': 'u', 'エ': 'e', 'オ': 'o',
    'カ': 'ka', 'キ': 'ki', 'ク': 'ku', 'ケ': 'ke', 'コ': 'ko',
    'ガ': 'ga', 'ギ': 'gi', 'グ': 'gu', 'ゲ': 'ge', 'ゴ': 'go',
    'サ': 'sa', 'シ': 'shi', 'ス': 'su', 'セ': 'se', 'ソ': 'so',
    'ザ': 'za', 'ジ': 'ji', 'ズ': 'zu', 'ゼ': 'ze', 'ゾ': 'zo',
    'タ': 'ta', 'チ': 'chi', 'ツ': 'tsu', 'テ': 'te', 'ト': 'to',
    'ダ': 'da', 'ヂ': 'ji', 'ヅ': 'zu', 'デ': 'de', 'ド': 'do',
    'ナ': 'na', 'ニ': 'ni', 'ヌ': 'nu', 'ネ': 'ne', 'ノ': 'no',
    'ハ': 'ha', 'ヒ': 'hi', 'フ': 'fu', 'ヘ': 'he', 'ホ': 'ho',
    'バ': 'ba', 'ビ': 'bi', 'ブ': 'bu', 'ベ': 'be', 'ボ': 'bo',
    'パ': 'pa', 'ピ': 'pi', 'プ': 'pu', 'ペ': 'pe', 'ポ': 'po',
    'マ': 'ma', 'ミ': 'mi', 'ム': 'mu', 'メ': 'me', 'モ': 'mo',
    'ヤ': 'ya', 'ユ': 'yu', 'ヨ': 'yo',
    'ラ': 'ra', 'リ': 'ri', 'ル': 'ru', 'レ': 're', 'ロ': 'ro',
    'ワ': 'wa', 'ヲ': 'wo', 'ン': 'n',
    
    // Special characters
    'ー': '-',
    '。': '.',
    '、': ',',
  };
  
  let result = text;
  for (const [japanese, romaji] of Object.entries(romajiMap)) {
    result = result.replace(new RegExp(japanese, 'g'), romaji);
  }
  
  return result;
}

/**
 * Replace common character variations
 */
function replaceCommonCharacters(text: string): string {
  const replacements: { [key: string]: string } = {
    '（': '(', '）': ')', '［': '[', '］': ']',
    '｛': '{', '｝': '}', '\u201c': '"', '\u201d': '"',
    '\u2018': "'", '\u2019': "'", '・': '・', '：': ':',
    '；': ';', '！': '!', '？': '?', '％': '%',
    '＆': '&', '＃': '#', '＄': '$', '＠': '@',
    '＾': '^', '＿': '_', '｜': '|',
    '￥': '\\',
  };
  
  let result = text;
  for (const [original, replacement] of Object.entries(replacements)) {
    result = result.replace(new RegExp(original.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'g'), replacement);
  }
  
  return result;
}

/**
 * Check if text contains Japanese characters
 */
export function containsJapanese(text: string): boolean {
  return /[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FAF]/.test(text);
}

/**
 * Improve search scoring for Japanese text
 */
export function calculateJapaneseScore(query: string, content: string): number {
  const normalizedQuery = normalizeJapaneseText(query);
  const normalizedContent = normalizeJapaneseText(content);
  
  let score = 0;
  
  // Exact match bonus
  if (normalizedContent.includes(normalizedQuery)) {
    score += 10;
  }
  
  // Partial match bonus
  const queryVariations = prepareSearchVariations(query);
  for (const variation of queryVariations) {
    if (normalizedContent.includes(variation)) {
      score += 5;
    }
  }
  
  // Word boundary bonus
  const words = normalizedQuery.split(/\s+/);
  for (const word of words) {
    if (word.length > 0 && normalizedContent.includes(word)) {
      score += 2;
    }
  }
  
  return score;
}
