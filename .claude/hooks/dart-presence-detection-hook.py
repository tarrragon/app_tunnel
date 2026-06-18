#!/usr/bin/env -S uv run --quiet --script
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""
Dart Presence-Detection Hook (PreToolUse on Edit / Write)

偵測「應有設施缺席」三類問題，針對 greenfield 專案從不 bootstrap i18n / theme
而使依賴設施存在的 hook 終生空轉的結構盲區（來源：1.2.0-W1-015）。

與既有 hook 的差異（非重複）：
  - style-guardian-hook：PostToolUse + WARNING-only，假設 theme / UISpacing 設施存在，
    檢查「既有設施的一致性」。
  - l10n-sync-verification-hook：只在 .arb 編輯時觸發，presence-blind（無 i18n 專案永不觸發）。
  - 本 hook：PreToolUse + blocking-with-override，偵測「應有而無」的設施缺席，
    在 .dart 寫入時直接攔截硬編碼。

偵測三類缺席：
  1. 硬編碼 user-facing 字串（排除 log / debug / assert / import / 註解 / annotation）→ 應進 i18n
  2. 裸 Color() / Colors.xxx（非 theme token 引用）→ 應進 theme token
  3. 魔術數字字面（SizedBox / EdgeInsets / Duration / fontSize / BorderRadius 等）→ 應集中常數

設計防呆（避免癱瘓 remediation，來源：ticket 防呆要求）：
  - 只偵測「變更內容」（Edit 的 new_string / Write 的 content），不掃整檔。
    遷移 ticket（021/024/025）改動既有舊行時，未被本次編輯觸及的舊問題不會被重複攔截。
  - Override marker：同行或前一行含 `// presence-exempt` / `// i18n-exempt` /
    `// color-exempt` / `// magic-exempt` 的命中行豁免。
  - 降級路徑：環境變數 PRESENCE_HOOK_MODE=warn 時退化為純警告（exit 0），
    供 warn→觀察→升 blocking 的漸進式部署。預設為 block。

Exit Codes：
  0 - 無命中 / 已 override / warn 模式 / 非 .dart / 解析失敗（不阻塊原則）
  2 - block 模式且偵測到未豁免的缺席（permissionDecision: deny）
"""

import json
import os
import re
import sys
from pathlib import Path

from hook_utils import setup_hook_logging, run_hook_safely, read_json_from_stdin

# ---------------------------------------------------------------------------
# 範圍判定
# ---------------------------------------------------------------------------

# 跳過的檔案模式（生成檔、測試、theme / config 設施本體）
SKIP_PATTERNS = [
    r"\.g\.dart$",
    r"\.freezed\.dart$",
    r"\.mocks\.dart$",
    r"\.gr\.dart$",
    r"/test/",
    r"/integration_test/",
    r"_test\.dart$",
    r"/l10n/",
    r"/generated/",
    r"ui_config\.dart$",
    r"flat_design_config\.dart$",
    r"responsive_config\.dart$",
    r"theme\.dart$",
    r"app_colors\.dart$",
    r"ui_colors\.dart$",
    r"ui_spacing\.dart$",
    r"ui_constants\.dart$",
    # 013/014 ANA 選定的集中化 sink 檔（app_*/terminal_* 命名）。
    # 常數定義本體（018/020 將寫入）不應被誤攔，否則 bootstrap 自身被阻塞。
    r"app_spacing\.dart$",
    r"app_typography\.dart$",
    r"terminal_constants\.dart$",
]

# Override marker：命中行自身或前一行存在即豁免
OVERRIDE_MARKERS = [
    "presence-exempt",
    "i18n-exempt",
    "color-exempt",
    "magic-exempt",
    "style-exempt",
]

# ---------------------------------------------------------------------------
# 偵測 pattern
# ---------------------------------------------------------------------------

# 1. 硬編碼 user-facing 字串：含 CJK 或含空白的多字英文字串字面
#    （單字 token 如 'utf-8' / 'GET' 不視為 user-facing，降低誤判）
_CJK_STRING = re.compile(r"""(['"])(?=[^'"]*[一-鿿])[^'"]*\1""")
_ENGLISH_SENTENCE = re.compile(r"""(['"])([A-Za-z][^'"]*\s+[^'"]+)\1""")

# 排除的字串脈絡（log / debug / assert / import / 註解 / annotation / key / 路徑）
_STRING_EXCLUDE_CONTEXT = re.compile(
    r"""(
        ^\s*//                |   # 行註解
        ^\s*/?\*              |   # 區塊註解
        ^\s*import\s          |
        ^\s*export\s          |
        ^\s*part\s            |
        ^\s*@                 |   # annotation
        \blog(ger)?\.\w+      |
        \bdebugPrint\b        |
        \bprint\b             |
        \bassert\b            |
        \bthrow\s+\w*Exception|   # 例外訊息屬開發者面
        \bArgumentError\b     |   # 參數校驗錯誤訊息屬開發者面（017 觀察過度偵測）
        \btoString\s*\(       |   # toString 內字串屬開發者除錯輸出，非 user-facing（017 觀察）
        \bAppLogger\b         |
        \bKey\s*\(            |   # ValueKey / Key 字面
        \bByName\b
    )""",
    re.VERBOSE,
)

# 2. 裸 Color：Color(0x...) 或 Colors.named（非 token 引用）
_BARE_COLOR = re.compile(
    r"""(?<![A-Za-z0-9_.])(
        Color\s*\(\s*0x[0-9A-Fa-f]{6,8}\s*\)  |
        Colors\.[a-zA-Z]+
    )""",
    re.VERBOSE,
)
# theme token 前綴（已是設施引用，豁免）
_COLOR_EXCEPTION = re.compile(r"\b(UIColors|AppColors|Theme\.of|colorScheme|ColorScheme)\b")

# 3. 魔術數字：layout 構造子帶數字字面
_MAGIC_NUMBER = re.compile(
    r"""(
        SizedBox\s*\(\s*(?:height|width)\s*:\s*\d+(?:\.\d+)?      |
        EdgeInsets\.(?:all|symmetric|only|fromLTRB)\s*\([^)]*\b\d+(?:\.\d+)?\b |
        \bfontSize\s*:\s*\d+(?:\.\d+)?                           |
        BorderRadius\.circular\s*\(\s*\d+(?:\.\d+)?\s*\)         |
        Duration\s*\(\s*\w+\s*:\s*\d+\s*\)
    )""",
    re.VERBOSE,
)
# 常數設施前綴（已集中，豁免）
_MAGIC_EXCEPTION = re.compile(r"\b(UISpacing|UIFontSizes|UIBorderRadius|UIDurations|AppDimens)\b")


def should_skip_file(file_path: str) -> bool:
    """檔案是否在偵測範圍外（生成檔、測試、設施本體）。"""
    normalised = file_path.replace("\\", "/")
    return any(re.search(p, normalised) for p in SKIP_PATTERNS)


def is_dart_file(file_path: str) -> bool:
    return file_path.endswith(".dart")


def _line_is_overridden(lines: list, index: int) -> bool:
    """命中行自身或前一行含 override marker。"""
    candidates = [lines[index]]
    if index > 0:
        candidates.append(lines[index - 1])
    joined = " ".join(candidates)
    return any(marker in joined for marker in OVERRIDE_MARKERS)


def detect_violations(content: str) -> list:
    """
    對「變更內容」掃描三類缺席。

    僅掃描傳入的 content（Edit new_string / Write content），不讀整檔，
    避免重複攔截本次未觸及的既有舊問題（remediation 防呆）。

    Returns: list of {line, category, snippet, suggestion}
    """
    violations = []
    lines = content.split("\n")

    for idx, line in enumerate(lines):
        stripped = line.strip()
        if not stripped:
            continue

        # 1. 硬編碼 user-facing 字串
        if not _STRING_EXCLUDE_CONTEXT.search(line):
            if _CJK_STRING.search(line) or _ENGLISH_SENTENCE.search(line):
                if not _line_is_overridden(lines, idx):
                    violations.append({
                        "line": idx + 1,
                        "category": "i18n",
                        "snippet": stripped[:80],
                        "suggestion": "user-facing 字串應進 i18n（或標 // i18n-exempt）",
                    })
                    continue  # 一行一類即可

        # 2. 裸 Color / Colors.named
        if _BARE_COLOR.search(line) and not _COLOR_EXCEPTION.search(line):
            if not _line_is_overridden(lines, idx):
                violations.append({
                    "line": idx + 1,
                    "category": "color",
                    "snippet": stripped[:80],
                    "suggestion": "裸 Color 應改用 theme token（或標 // color-exempt）",
                })
                continue

        # 3. 魔術數字
        if _MAGIC_NUMBER.search(line) and not _MAGIC_EXCEPTION.search(line):
            if not _line_is_overridden(lines, idx):
                violations.append({
                    "line": idx + 1,
                    "category": "magic-number",
                    "snippet": stripped[:80],
                    "suggestion": "魔術數字應集中為常數（或標 // magic-exempt）",
                })

    return violations


def extract_changed_content(tool_name: str, tool_input: dict) -> str:
    """
    取得本次編輯實際寫入的內容（變更行而非全檔）。

    Edit  → new_string（僅替換後的新內容）
    Write → content（新檔內容；新建檔本就是全部新內容）
    """
    if tool_name == "Write":
        return tool_input.get("content", "") or ""
    if tool_name == "Edit":
        return tool_input.get("new_string", "") or ""
    if tool_name == "MultiEdit":
        edits = tool_input.get("edits") or []
        return "\n".join(e.get("new_string", "") or "" for e in edits)
    return ""


def build_block_message(file_path: str, violations: list) -> str:
    """組裝 block 訊息（含修復指引與 override 用法）。"""
    by_cat = {}
    for v in violations:
        by_cat.setdefault(v["category"], []).append(v)

    lines = [
        "[Presence Guard] 偵測到應有設施缺席（blocking-with-override）",
        f"檔案: {file_path}",
        "",
    ]
    cat_label = {
        "i18n": "硬編碼 user-facing 字串（應進 i18n）",
        "color": "裸 Color / Colors.xxx（應進 theme token）",
        "magic-number": "魔術數字字面（應集中常數）",
    }
    for cat, items in by_cat.items():
        lines.append(f"[{cat_label.get(cat, cat)}]")
        for v in items[:5]:
            lines.append(f"  變更行 {v['line']}: {v['snippet']}")
            lines.append(f"    → {v['suggestion']}")
        if len(items) > 5:
            lines.append(f"  ... 另有 {len(items) - 5} 處")
        lines.append("")

    lines.append("修復選項（擇一）：")
    lines.append("  1. 引入對應設施（i18n / theme token / 常數）後重試")
    lines.append("  2. 確屬例外時於命中行或前一行加 override marker：")
    lines.append("     // i18n-exempt  /  // color-exempt  /  // magic-exempt  /  // presence-exempt")
    lines.append("")
    lines.append("漸進部署：設 PRESENCE_HOOK_MODE=warn 可暫退為純警告（不阻擋）。")
    return "\n".join(lines)


def main() -> int:
    logger = setup_hook_logging("dart-presence-detection")

    input_data = read_json_from_stdin(logger)
    if input_data is None:
        return 0

    tool_name = input_data.get("tool_name", "")
    tool_input = input_data.get("tool_input") or {}

    if tool_name not in ("Edit", "Write", "MultiEdit"):
        logger.debug("跳過: 工具 %s 不在 Edit/Write/MultiEdit 範圍", tool_name)
        return 0

    file_path = tool_input.get("file_path", "")
    if not is_dart_file(file_path):
        logger.debug("跳過: 非 .dart 檔案 %s", file_path)
        return 0

    if should_skip_file(file_path):
        logger.info("跳過: 範圍外檔案（生成檔/測試/設施本體）%s", file_path)
        return 0

    changed_content = extract_changed_content(tool_name, tool_input)
    if not changed_content.strip():
        logger.debug("跳過: 無變更內容 %s", file_path)
        return 0

    violations = detect_violations(changed_content)
    mode = os.environ.get("PRESENCE_HOOK_MODE", "block").strip().lower()

    logger.info(
        "presence_check: file=%s, tool=%s, violations=%d, mode=%s",
        file_path, tool_name, len(violations), mode,
    )

    if not violations:
        return 0

    message = build_block_message(file_path, violations)

    if mode == "warn":
        # 降級路徑：純警告，不阻擋（warn→觀察→升 block）
        logger.info("warn 模式：偵測到 %d 處但不阻擋", len(violations))
        print(message, file=sys.stderr)
        output = {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "allow",
                "permissionDecisionReason": "presence warn 模式：僅提示不阻擋",
            }
        }
        print(json.dumps(output, ensure_ascii=False))
        return 0

    # block 模式：阻擋並回饋 Claude
    print(message, file=sys.stderr)
    output = {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": message,
        }
    }
    print(json.dumps(output, ensure_ascii=False))
    return 2


if __name__ == "__main__":
    sys.exit(run_hook_safely(main, "dart-presence-detection"))
