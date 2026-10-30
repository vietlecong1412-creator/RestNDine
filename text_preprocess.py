"""
Tien xu ly van ban tieng Viet truoc khi dua vao PhoBERT.
Xu ly: viet tat, slang tang nghia, emoji, lap ki tu.
"""
import re

# Viet tat pho bien (word boundary de tranh match nham)
ABBREVS = {
    r'\bko\b': 'không', r'\bk\b': 'không', r'\bkg\b': 'không',
    r'\bhk\b': 'không', r'\bkh\b': 'không', r'\bkog\b': 'không',
    r'\bđc\b': 'được',  r'\bdc\b': 'được',
    r'\bcx\b': 'cũng',  r'\bcg\b': 'cũng',
    r'\br\b':  'rồi',
    r'\bmn\b': 'mọi người',
    r'\bvs\b': 'với',
    r'\bnma\b': 'nhưng mà', r'\bnhma\b': 'nhưng mà', r'\bnmà\b': 'nhưng mà',
    r'\bbt\b': 'bình thường',
    r'\bng\b': 'người',
    r'\bthk\b': 'thích',
    r'\bnv\b': 'nhân viên',
    r'\bpv\b': 'phục vụ',
    r'\bdd\b': 'địa điểm',
    r'\bck\b': 'chồng',
    r'\bvk\b': 'vợ',
    r'\bns\b': 'nói',
    r'\bms\b': 'mới',
    r'\bkb\b': 'không biết',
    r'\bqá\b': 'quá',
    r'\bntn\b': 'như thế nào',
    r'\bthôi\b': 'thôi',  # giữ nguyên nhưng đảm bảo không bị tokenize lạ
}

# Slang tang nghia manh → "rất" (de PhoBERT hieu duoc muc do cam xuc)
SLANG_INTENSIFIERS = [
    r'\bvl\b', r'\bvcl\b', r'\bvkl\b',
    r'\bvãi\b', r'\bvãi lúa\b', r'\bvãi nồi\b',
    r'\bđỉnh của chóp\b', r'\bđỉnh kout\b', r'\bđỉnh nóc\b',
    r'\bno cap\b', r'\blegit\b',
    r'\bkinh khủng\b',  # giữ nguyên - PhoBERT hiểu
]

# Slang tich cuc dac biet → "rất tốt"
POSITIVE_SLANG = [
    r'\bchanh sả\b', r'\bchill phết\b', r'\bxịn sò\b', r'\bxịn xò\b',
    r'\bneat\b', r'\bperfect\b', r'\bamazing\b', r'\bawesome\b',
    r'\bslay\b', r'\bfire\b',
]

# Slang tieu cuc dac biet → "rất tệ"
NEGATIVE_SLANG = [
    r'\btệ thật\b', r'\bchán thật\b', r'\bphét\b',
    r'\btrash\b', r'\bawful\b', r'\bterrible\b',
]

# Emoji → text
EMOJI_MAP = {
    '🔥': ' tuyệt vời ',  '✨': ' tuyệt ',    '💯': ' hoàn hảo ',
    '❤️': ' yêu thích ', '♥':  ' yêu thích ', '🥰': ' yêu thích ',
    '😍': ' tuyệt vời ', '😋': ' ngon ',       '🤤': ' ngon ',
    '👍': ' tốt ',        '👎': ' tệ ',
    '😡': ' tức giận ',  '😠': ' tức giận ',
    '😢': ' buồn ',       '😤': ' tức giận ',
    '⭐': ' sao ',        '🌟': ' xuất sắc ',
    '🤢': ' kinh khủng ','🤮': ' kinh khủng ',
    '😒': ' không hài lòng ', '🙄': ' không hài lòng ',
    '😊': ' vui ',        '😄': ' vui ',       '🥳': ' vui ',
}


def normalize(text: str) -> str:
    if not text:
        return text

    # 1. Emoji → text
    for emoji, replacement in EMOJI_MAP.items():
        text = text.replace(emoji, replacement)

    # 2. Ki tu lap (ngoooon → ngon, tệệệ → tệ) — giu lai 1 ki tu
    text = re.sub(r'(.)\1{2,}', r'\1', text)

    # 3. Teen code so don gian (0→o, 4→a, 3→e) — chi trong cac cum chu ro rang
    text = re.sub(r'\b(\w*)0(\w*)\b', lambda m: m.group(0).replace('0', 'o'), text)

    # 4. Slang tich cuc dac biet
    for pattern in POSITIVE_SLANG:
        text = re.sub(pattern, ' rất tốt ', text, flags=re.IGNORECASE)

    # 5. Slang tieu cuc dac biet
    for pattern in NEGATIVE_SLANG:
        text = re.sub(pattern, ' rất tệ ', text, flags=re.IGNORECASE)

    # 6. Slang tang nghia (vl, vcl...) → "rất"
    for pattern in SLANG_INTENSIFIERS:
        text = re.sub(pattern, ' rất ', text, flags=re.IGNORECASE)

    # 7. Viet tat → day du
    for pattern, replacement in ABBREVS.items():
        text = re.sub(pattern, replacement, text, flags=re.IGNORECASE)

    # 8. Chuan hoa khoang trang
    text = re.sub(r'\s+', ' ', text).strip()

    return text
