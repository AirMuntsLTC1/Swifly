// swifly_core.cpp - native helpers for the Swifly app.
// Built by CMake into libswifly_core.so and called from Dart via dart:ffi.
#include <algorithm>
#include <cctype>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <numeric>
#include <vector>

#define SWIFLY_EXPORT extern "C" __attribute__((visibility("default"))) __attribute__((used))

namespace swifly {

// Engagement score with time decay: newer posts with more activity rank higher.
double engagement_score(int32_t likes, int32_t comments, int32_t saves, double hours) {
    const double points = static_cast<double>(likes) + 2.0 * comments + 3.0 * saves + 1.0;
    const double age = hours < 0.0 ? 0.0 : hours;
    return points / std::pow(age + 2.0, 1.5);
}

}  // namespace swifly

// Formats 1234 -> "1.2K", 1000 -> "1K", 2500000 -> "2.5M".
SWIFLY_EXPORT int32_t swifly_format_count(int64_t n, char* out, int32_t out_len) {
    if (out == nullptr || out_len <= 0) return 0;
    if (n < 0) n = 0;

    char buf[32];
    int len = 0;
    if (n < 1000) {
        len = std::snprintf(buf, sizeof(buf), "%lld", static_cast<long long>(n));
    } else if (n < 1000000) {
        const double v = static_cast<double>(n) / 1000.0;
        if (v < 10.0) {
            len = std::snprintf(buf, sizeof(buf), "%.1fK", v);
        } else {
            len = std::snprintf(buf, sizeof(buf), "%.0fK", v);
        }
    } else {
        const double v = static_cast<double>(n) / 1000000.0;
        if (v < 10.0) {
            len = std::snprintf(buf, sizeof(buf), "%.1fM", v);
        } else {
            len = std::snprintf(buf, sizeof(buf), "%.0fM", v);
        }
    }

    // Turn "1.0K" into "1K"
    char* dot = std::strchr(buf, '.');
    if (dot != nullptr && dot[1] == '0' && (dot[2] == 'K' || dot[2] == 'M')) {
        dot[1] = dot[2];
        dot[2] = '\0';
        len -= 1;
    }

    const int32_t copy = std::min<int32_t>(len, out_len - 1);
    std::memcpy(out, buf, static_cast<size_t>(copy));
    out[copy] = '\0';
    return copy;
}

// Ranks n posts by engagement score (highest first).
// out_order receives the post indexes in ranked order.
SWIFLY_EXPORT void swifly_rank(const int32_t* likes, const int32_t* comments,
                               const int32_t* saves, const double* hours,
                               int32_t n, int32_t* out_order) {
    if (!likes || !comments || !saves || !hours || !out_order || n <= 0) return;

    std::vector<double> scores(static_cast<size_t>(n));
    for (int32_t i = 0; i < n; ++i) {
        scores[i] = swifly::engagement_score(likes[i], comments[i], saves[i], hours[i]);
    }

    std::vector<int32_t> idx(static_cast<size_t>(n));
    std::iota(idx.begin(), idx.end(), 0);
    std::stable_sort(idx.begin(), idx.end(), [&scores](int32_t a, int32_t b) {
        return scores[a] > scores[b];
    });
    std::copy(idx.begin(), idx.end(), out_order);
}

// Case-insensitive "contains". Returns 1 if needle is inside haystack.
SWIFLY_EXPORT int32_t swifly_contains_ci(const char* haystack, const char* needle) {
    if (haystack == nullptr || needle == nullptr) return 0;
    const size_t hn = std::strlen(haystack);
    const size_t nn = std::strlen(needle);
    if (nn == 0) return 1;
    if (nn > hn) return 0;

    for (size_t i = 0; i + nn <= hn; ++i) {
        size_t j = 0;
        while (j < nn &&
               std::tolower(static_cast<unsigned char>(haystack[i + j])) ==
                   std::tolower(static_cast<unsigned char>(needle[j]))) {
            ++j;
        }
        if (j == nn) return 1;
    }
    return 0;
}
