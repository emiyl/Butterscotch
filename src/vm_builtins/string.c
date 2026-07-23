#include "string.h"

RValue builtin_string_length(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (1 > argCount) return RValue_makeInt32(0);
    // GML converts non-string arguments to string before measuring length
    RValue value = args[0];
    // Fast path: If the RValue is already a string, just return its length instead of creating a copy
    if (value.type == RVALUE_STRING) {
        if (value.string == nullptr)
            return RValue_makeInt32(0);
        int32_t byteLen = (int32_t) strlen(value.string);
        return RValue_makeInt32(TextUtils_utf8CodepointCount(value.string, byteLen));
    }
    char* str = RValue_toString(value);
    int32_t byteLen = (int32_t) strlen(str);
    int32_t len = TextUtils_utf8CodepointCount(str, byteLen);
    free(str);
    return RValue_makeInt32(len);
}

// https://docs.vultr.com/clang/examples/remove-all-characters-in-a-string-except-alphabets
void filterAlphabets(char *str) {
    char *result = (char *)safeMalloc(strlen(str) + 1);
    int j = 0;
    for (int i = 0; str[i] != '\0'; i++) {
        if ((str[i] >= 'a' && str[i] <= 'z') || (str[i] >= 'A' && str[i] <= 'Z')) {
            result[j++] = str[i];
        }
    }
    result[j] = '\0';  // Null-terminate the result string
    strcpy(str, result);  // Optionally copy back to original string
    free(result);
}

RValue builtin_string_letters(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (1 > argCount) return RValue_makeInt32(0);
    char* str = RValue_toString(args[0]);
    filterAlphabets(str);
    return RValue_makeString(str);
}

RValue builtin_string_digits(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (1 > argCount) return RValue_makeOwnedString(safeStrdup(""));
    char* str = RValue_toString(args[0]);
    int len = strlen(str);
    char* result = (char*)malloc(len + 1);
    if (result == NULL) return RValue_makeOwnedString(safeStrdup(""));

    int digitCount = 0;
    for (int i = 0; str[i] != '\0'; i++) {
        if (isdigit((unsigned char) str[i])) result[digitCount++] = str[i];
    }

    free(str);
    result[digitCount] = '\0';

    if (digitCount == 0) {
        free(result);
        return RValue_makeOwnedString(safeStrdup(""));
    }

    char* exact_result = (char*)realloc(result, digitCount + 1);
    return RValue_makeOwnedString(exact_result ? exact_result : result);
}

RValue builtin_string_lettersdigits(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (1 > argCount) return RValue_makeOwnedString(safeStrdup(""));
    char* str = RValue_toString(args[0]);
    int len = strlen(str);
    char* result = (char*)malloc(len + 1);
    if (result == NULL) return RValue_makeOwnedString(safeStrdup(""));

    int count = 0;
    for (int i = 0; str[i] != '\0'; i++) {
        if (isalnum((unsigned char) str[i])) result[count++] = str[i];
    }

    free(str);
    result[count] = '\0';

    if (count == 0) {
        free(result);
        return RValue_makeOwnedString(safeStrdup(""));
    }

    char* exact_result = (char*)realloc(result, count + 1);
    return RValue_makeOwnedString(exact_result ? exact_result : result);
}

RValue builtin_string_byte_length(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (1 > argCount) return RValue_makeInt32(0);
    // GML converts non-string arguments to string before measuring length
    RValue value = args[0];
    // Fast path: If the RValue is already a string, just return its length instead of creating a copy
    if (value.type == RVALUE_STRING) {
        if (value.string == nullptr)
            return RValue_makeInt32(0);
        int32_t byteLen = (int32_t) strlen(value.string);
        return RValue_makeInt32(byteLen);
    }
    char* str = RValue_toString(value);
    int32_t byteLen = (int32_t) strlen(str);
    free(str);
    return RValue_makeInt32(byteLen);
}

RValue builtin_string(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (1 > argCount) return RValue_makeOwnedString(safeStrdup(""));
    char* result = RValue_toString(args[0]);
    return RValue_makeOwnedString(result);
}

RValue builtin_string_upper(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (1 > argCount) return RValue_makeOwnedString(safeStrdup(""));
    char* result = RValue_toString(args[0]);
    for (char* p = result; *p; p++) *p = (char) toupper((unsigned char) *p);
    return RValue_makeOwnedString(result);
}

RValue builtin_string_lower(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (1 > argCount) return RValue_makeOwnedString(safeStrdup(""));
    char* result = RValue_toString(args[0]);
    for (char* p = result; *p; p++) *p = (char) tolower((unsigned char) *p);
    return RValue_makeOwnedString(result);
}

RValue builtin_string_copy(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (3 > argCount) return RValue_makeOwnedString(safeStrdup(""));
    int32_t len = RValue_toInt32(args[2]);
    if (0 >= len) {
        return RValue_makeOwnedString(safeStrdup(""));
    }

    char* str = RValue_toString(args[0]);
    int32_t pos = RValue_toInt32(args[1]) - 1; // GMS is 1-based
    int32_t strLen = (int32_t) strlen(str);

    if (0 > pos) pos = 0;

    int32_t byteStart = TextUtils_utf8AdvanceCodepoints(str, strLen, pos);
    if (byteStart >= strLen) {
        free(str);
        return RValue_makeOwnedString(safeStrdup(""));
    }

    int32_t byteEnd = byteStart + TextUtils_utf8AdvanceCodepoints(str + byteStart, strLen - byteStart, len);
    if (byteEnd > strLen) byteEnd = strLen;

    int32_t nbytes = byteEnd - byteStart;
    char* result = (char *)safeMalloc(nbytes + 1);
    memcpy(result, str + byteStart, (size_t) nbytes);
    result[nbytes] = '\0';

    free(str);

    return RValue_makeOwnedString(result);
}

RValue builtin_string_pos(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (2 > argCount) return RValue_makeReal(0.0);
    char* needle = RValue_toString(args[0]);
    char* haystack = RValue_toString(args[1]);
    char* found = strstr(haystack, needle);
    if (found == nullptr) {
        free(haystack);
        free(needle);
        return RValue_makeReal(0.0);
    }
    int32_t byteIndex = (int32_t) (found - haystack);
    int32_t charIndex = TextUtils_utf8CodepointCount(haystack, byteIndex) + 1; // 1-based codepoint index
    free(haystack);
    free(needle);
    return RValue_makeReal((GMLReal) charIndex);
}

RValue builtin_string_char_at(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (2 > argCount) return RValue_makeOwnedString(safeStrdup(""));
    char* str = RValue_toString(args[0]);
    int32_t pos = RValue_toInt32(args[1]) - 1; // 1-based
    int32_t strLen = (int32_t) strlen(str);
    if (0 > pos || pos >= strLen) {
        free(str);
        return RValue_makeOwnedString(safeStrdup(""));
    }
    int32_t byteStart = TextUtils_utf8AdvanceCodepoints(str, strLen, pos);
    if (byteStart >= strLen) {
        free(str);
        return RValue_makeOwnedString(safeStrdup(""));
    }
    int32_t byteNext = byteStart;
    TextUtils_decodeUtf8(str, strLen, &byteNext);
    int32_t nbytes = byteNext - byteStart;
    char* out = (char *)safeMalloc(nbytes + 1);
    memcpy(out, str + byteStart, (size_t) nbytes);
    out[nbytes] = '\0';
    free(str);
    return RValue_makeOwnedString(out);
}

RValue builtin_string_ord_at(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (2 > argCount) return RValue_makeReal(-1.0);
    char* str = RValue_toString(args[0]);
    int32_t pos = RValue_toInt32(args[1]) - 1; // 1-based
    int32_t strLen = (int32_t) strlen(str);
    if (strLen == 0) {
        free(str);
        return RValue_makeReal(-1.0);
    }
    if (0 > pos) pos = 0; // native clamps negative indices to the first character
    int32_t byteStart = TextUtils_utf8AdvanceCodepoints(str, strLen, pos);
    if (byteStart >= strLen) {
        free(str);
        return RValue_makeReal(-1.0);
    }
    int32_t offset = byteStart;
    uint16_t codepoint = TextUtils_decodeUtf8(str, strLen, &offset);
    free(str);
    return RValue_makeReal((GMLReal) codepoint);
}

// Appends a copy of [start, start + len) to the array as an owned string, growing it by one slot.
static void appendSplitSegment(GMLArray* arr, int32_t* count, const char* start, int32_t len) {
    char* segment = (char *)safeMalloc((size_t) len + 1);
    if (len > 0) memcpy(segment, start, (size_t) len);
    segment[len] = '\0';
    GMLArray_growTo(arr, *count + 1);
    RValue* slot = GMLArray_slot(arr, *count);
    *slot = RValue_makeOwnedString(segment);
    (*count)++;
}

RValue builtin_string_split(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (2 > argCount) return RValue_makeArray(GMLArray_create(ctx->dataWin->gen8.wadVersion, 0));
    char* string = RValue_toString(args[0]);
    char* delimiter = RValue_toString(args[1]);
    bool removeEmpty = argCount > 2 ? RValue_toBool(args[2]) : false;
    // maxSplits is actually a real (the native runner compares it as a double), but how are you going to split something by... 0.5?
    GMLReal maxSplits = argCount > 3 ? RValue_toReal(args[3]) : (GMLReal) INT32_MAX;

    int32_t delimiterLen = (int32_t) strlen(delimiter);

    // Native runner returns an empty array when maxSplits was explicitly given and is <= 0, or when the delimiter is empty.
    if ((argCount > 3 && 0.0 >= maxSplits) || delimiterLen == 0) {
        free(string);
        free(delimiter);
        return RValue_makeArray(GMLArray_create(ctx->dataWin->gen8.wadVersion, 0));
    }

    GMLArray* out = GMLArray_create(ctx->dataWin->gen8.wadVersion, 0);
    int32_t count = 0;

    int32_t stringLen = (int32_t) strlen(string);
    const char* end = string + stringLen;
    const char* segmentStart = string; // Start of the current (not yet emitted) segment
    const char* cursor = string;
    int32_t splits = 0;

    // Keep splitting until we run out of room for another delimiter or hit maxSplits.
    // Like the native runner, we only test for the delimiter at UTF-8 codepoint boundaries.
    while (maxSplits > (GMLReal) splits && end - delimiterLen >= cursor) {
        if (memcmp(cursor, delimiter, (size_t) delimiterLen) == 0) {
            int32_t segmentLen = (int32_t) (cursor - segmentStart);
            if (!(removeEmpty && segmentLen == 0)) appendSplitSegment(out, &count, segmentStart, segmentLen);
            cursor += delimiterLen;
            segmentStart = cursor;
            splits++;
        } else {
            // Advance one codepoint so the next strncmp lands on a codepoint boundary.
            int32_t consumed = 0;
            TextUtils_decodeUtf8(cursor, (int32_t) (end - cursor), &consumed);
            if (0 >= consumed) consumed = 1;
            cursor += consumed;
        }
    }

    // Whatever is left becomes the final segment.
    int32_t tailLen = (int32_t) (end - segmentStart);
    if (!(removeEmpty && tailLen == 0)) appendSplitSegment(out, &count, segmentStart, tailLen);

    free(string);
    free(delimiter);
    return RValue_makeArray(out);
}

RValue builtin_string_delete(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (3 > argCount) return RValue_makeOwnedString(safeStrdup(""));
    char* str = RValue_toString(args[0]);
    int32_t pos = RValue_toInt32(args[1]) - 1; // 1-based
    int32_t count = RValue_toInt32(args[2]);
    int32_t strLen = (int32_t) strlen(str);

    if (0 > pos || pos >= strLen || 0 >= count) return RValue_makeOwnedString(str);

    int32_t byteStart = TextUtils_utf8AdvanceCodepoints(str, strLen, pos);
    if (byteStart >= strLen) return RValue_makeOwnedString(str);

    int32_t byteEnd = byteStart + TextUtils_utf8AdvanceCodepoints(str + byteStart, strLen - byteStart, count);
    if (byteEnd > strLen) byteEnd = strLen;

    int32_t removeLen = byteEnd - byteStart;
    char* result = (char *)safeMalloc(strLen - removeLen + 1);
    memcpy(result, str, (size_t) byteStart);
    memcpy(result + byteStart, str + byteEnd, (size_t) (strLen - byteEnd));
    result[strLen - removeLen] = '\0';

    free(str);

    return RValue_makeOwnedString(result);
}

RValue builtin_string_insert(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (3 > argCount) return RValue_makeOwnedString(safeStrdup(""));
    char* substr = RValue_toString(args[0]);
    char* str = RValue_toString(args[1]);
    int32_t pos = RValue_toInt32(args[2]) - 1; // 1-based
    int32_t strLen = (int32_t) strlen(str);
    int32_t subLen = (int32_t) strlen(substr);

    if (0 > pos) pos = 0;
    int32_t bytePos = TextUtils_utf8AdvanceCodepoints(str, strLen, pos);
    if (bytePos > strLen) bytePos = strLen;

    char* result = (char *)safeMalloc(strLen + subLen + 1);
    memcpy(result, str, (size_t) bytePos);
    memcpy(result + bytePos, substr, (size_t) subLen);
    memcpy(result + bytePos + subLen, str + bytePos, (size_t) (strLen - bytePos));
    result[strLen + subLen] = '\0';

    free(substr);
    free(str);

    return RValue_makeOwnedString(result);
}

RValue builtin_string_replace(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (3 > argCount) return RValue_makeOwnedString(safeStrdup(""));
    char* str = RValue_toString(args[0]);
    char* needle = RValue_toString(args[1]);
    int32_t strLen = (int32_t) strlen(str);
    int32_t needleLen = (int32_t) strlen(needle);
    if (0 == needleLen) {
        free(needle);
        return RValue_makeOwnedString(str);
    }

    char* replacement = RValue_toString(args[2]);
    int32_t replacementLen = (int32_t) strlen(replacement);

    // There can be only ONE.
    char *appearance = strstr(str, needle);
    if (!appearance) {
        free(needle);
        free(replacement);
        return RValue_makeOwnedString(str);
    }

    int32_t newLen = strLen - needleLen + replacementLen;
    int32_t before = (int32_t) (appearance - str);
    char *outputString = (char *)safeMalloc(newLen + 1);

    memcpy(outputString, str, before);
    memcpy(outputString + before, replacement, replacementLen);
    strcpy(outputString + before + replacementLen, appearance + needleLen);

    free(str);
    free(needle);
    free(replacement);

    return RValue_makeOwnedString(outputString);
}

RValue builtin_string_replace_all(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (3 > argCount) return RValue_makeOwnedString(safeStrdup(""));
    char* str = RValue_toString(args[0]);
    char* needle = RValue_toString(args[1]);
    int32_t needleLen = (int32_t) strlen(needle);
    if (0 == needleLen) {
        free(needle);
        return RValue_makeOwnedString(str);
    }

    char* replacement = RValue_toString(args[2]);
    int32_t replacementLen = (int32_t) strlen(replacement);

    // Count occurrences to pre-allocate
    int32_t count = 0;
    const char* p = str;
    while ((p = strstr(p, needle)) != nullptr) { count++; p += needleLen; }

    int32_t strLen = (int32_t) strlen(str);
    int32_t resultLen = strLen + count * (replacementLen - needleLen);
    char* result = (char *)safeMalloc(resultLen + 1);
    char* out = result;
    p = str;
    const char* match;
    while ((match = strstr(p, needle)) != nullptr) {
        int32_t before = (int32_t) (match - p);
        memcpy(out, p, before);
        out += before;
        memcpy(out, replacement, replacementLen);
        out += replacementLen;
        p = match + needleLen;
    }
    strcpy(out, p);

    free(replacement);
    free(needle);
    free(str);

    return RValue_makeOwnedString(result);
}

RValue builtin_string_repeat(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (2 > argCount) return RValue_makeOwnedString(safeStrdup(""));
    char* str = RValue_toString(args[0]);
    int32_t count = RValue_toInt32(args[1]);
    if (0 >= count || str[0] == '\0') {
        free(str);
        return RValue_makeOwnedString(safeStrdup(""));
    }

    size_t strLen = strlen(str);
    size_t totalLen = strLen * (size_t) count;
    char* result = (char *)safeMalloc(totalLen + 1);
    repeat(count, i) {
        memcpy(result + i * strLen, str, strLen);
    }
    result[totalLen] = '\0';
    free(str);
    return RValue_makeOwnedString(result);
}

RValue builtin_string_format(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (3 > argCount) return RValue_makeOwnedString(safeStrdup(""));
    if (args[0].type == RVALUE_UNDEFINED) return RValue_makeOwnedString(safeStrdup("undefined"));

    GMLReal val = RValue_toReal(args[0]);
    int32_t tot = RValue_toInt32(args[1]);
    int32_t dec = RValue_toInt32(args[2]);
    if (0 > dec) dec = 0;
    if (15 < dec) dec = 15;

    char numBuf[64];
    snprintf(numBuf, sizeof(numBuf), "%.*f", (int) dec, (double) val);

    const char* dot = strchr(numBuf, '.');
    int32_t intLen = (int32_t) (dot ? (dot - numBuf) : (int32_t) strlen(numBuf));

    int32_t leftPad = (tot > intLen) ? (tot - intLen) : 0;
    int32_t numLen = (int32_t) strlen(numBuf);
    int32_t totalLen = leftPad + numLen;

    char* result = (char *)safeMalloc(totalLen + 1);
    for (int32_t i = 0; leftPad > i; i++) result[i] = ' ';
    memcpy(result + leftPad, numBuf, (size_t) numLen);
    result[totalLen] = '\0';
    return RValue_makeOwnedString(result);
}

RValue builtin_string_count(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (2 > argCount) return RValue_makeInt32(0);
    char* substr = RValue_toString(args[0]);
    char* str = RValue_toString(args[1]);
    size_t strLen = strlen(str);
    size_t substrLen = strlen(substr);
    int32_t count = 0;

    if (substrLen > strLen) {
        free(substr);
        free(str);
        return RValue_makeInt32(0);
    }

    repeat(strLen, i) {
        if (strncmp(str + i, substr, substrLen) == 0)
            count++;
    }

    free(substr);
    free(str);
    return RValue_makeInt32(count);
}

// Source - https://stackoverflow.com/a/15515276
RValue builtin_string_starts_with(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (2 > argCount) return RValue_makeInt32(0);
    char* substr = RValue_toString(args[0]);
    char* str = RValue_toString(args[1]);

    bool ret = (strncmp(str, substr, strlen(substr)) == 0);

    free(substr);
    free(str);
    return RValue_makeBool(ret);
}

RValue builtin_ord(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (1 > argCount || args[0].type != RVALUE_STRING || args[0].string == nullptr || args[0].string[0] == '\0') {
        return RValue_makeReal(0.0);
    }
    const char* str = args[0].string;
    int32_t pos = 0;
    uint16_t cp = TextUtils_decodeUtf8(str, (int32_t)strlen(str), &pos);
    return RValue_makeReal((GMLReal) cp);
}

RValue builtin_chr(MAYBE_UNUSED VMContext* ctx, RValue* args, int32_t argCount) {
    if (1 > argCount) return RValue_makeOwnedString(safeStrdup(""));
    uint32_t cp = (uint32_t) RValue_toInt32(args[0]);
    char buf[5];
    int32_t n = TextUtils_utf8EncodeCodepoint(cp, buf);
    if (0 >= n) return RValue_makeOwnedString(safeStrdup(""));
    buf[n] = '\0';
    return RValue_makeOwnedString(safeStrdup(buf));
}