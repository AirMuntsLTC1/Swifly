// swifly_core.cpp - native helpers for the Swifly app.
// Built by CMake into libswifly_core.so and called from Dart via dart:ffi.
#include <algorithm>
#include <cctype>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <numeric>
#include <string>
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


// Counts how many lines in joined_texts (separated by newline) contain the hashtag.
// The hashtag must not be glued to a word character on either side.
SWIFLY_EXPORT int32_t swifly_count_hashtag(const char* joined_texts, const char* tag) {
    if (joined_texts == nullptr || tag == nullptr) return 0;
    std::string needle(tag);
    if (needle.empty()) return 0;
    if (needle[0] != '#') needle.insert(needle.begin(), '#');
    std::transform(needle.begin(), needle.end(), needle.begin(),
                   [](unsigned char c) { return static_cast<char>(std::tolower(c)); });

    int32_t count = 0;
    const char* p = joined_texts;
    while (*p) {
        const char* line_end = std::strchr(p, '\n');
        const size_t len = line_end ? static_cast<size_t>(line_end - p) : std::strlen(p);
        std::string line(p, len);
        std::transform(line.begin(), line.end(), line.begin(),
                       [](unsigned char c) { return static_cast<char>(std::tolower(c)); });

        size_t pos = 0;
        while ((pos = line.find(needle, pos)) != std::string::npos) {
            bool left_ok = true;
            bool right_ok = true;
            if (pos > 0) {
                const unsigned char c = static_cast<unsigned char>(line[pos - 1]);
                if (std::isalnum(c) || c == '_') left_ok = false;
            }
            const size_t end = pos + needle.size();
            if (end < line.size()) {
                const unsigned char c = static_cast<unsigned char>(line[end]);
                if (std::isalnum(c) || c == '_') right_ok = false;
            }
            if (left_ok && right_ok) {
                ++count;
                break;
            }
            pos = end;
        }

        if (line_end == nullptr) break;
        p = line_end + 1;
    }
    return count;
}

// Extracts hashtags from text as lowercase tokens separated by spaces.
SWIFLY_EXPORT int32_t swifly_extract_hashtags(const char* text, char* out, int32_t out_len) {
    if (out == nullptr || out_len <= 0) return 0;
    out[0] = '\0';
    if (text == nullptr) return 0;

    std::string result;
    const char* p = text;
    while (*p) {
        if (*p == '#') {
            const char* start = p;
            ++p;
            while (*p && (std::isalnum(static_cast<unsigned char>(*p)) || *p == '_')) {
                ++p;
            }
            const size_t len = static_cast<size_t>(p - start);
            if (len > 1) {
                if (!result.empty()) result += ' ';
                for (size_t i = 0; i < len; ++i) {
                    result += static_cast<char>(
                        std::tolower(static_cast<unsigned char>(start[i])));
                }
            }
        } else {
            ++p;
        }
    }

    const int32_t copy = std::min<int32_t>(
        static_cast<int32_t>(result.size()), out_len - 1);
    if (copy > 0) {
        std::memcpy(out, result.data(), static_cast<size_t>(copy));
    }
    out[copy] = '\0';
    return copy;
}


// Resolves follow status: 0 = None, 1 = Following, 2 = Followers (Follow Back), 3 = Mutual
SWIFLY_EXPORT int32_t swifly_get_follow_status(int32_t is_following, int32_t is_follower) {
    if (is_following && is_follower) return 3;
    if (is_following) return 1;
    if (is_follower) return 2;
    return 0;
}


// Age in whole years on the given date. Returns -1 for an invalid or future birth date.
SWIFLY_EXPORT int32_t swifly_age_years(int32_t by, int32_t bm, int32_t bd,
                                       int32_t ty, int32_t tm, int32_t td) {
    if (by <= 0 || bm < 1 || bm > 12 || bd < 1 || bd > 31) return -1;
    if (ty < by) return -1;
    if (ty == by && (tm < bm || (tm == bm && td < bd))) return -1;
    int32_t age = ty - by;
    if (tm < bm || (tm == bm && td < bd)) age -= 1;
    return age;
}

// Privacy rule for a profile field. audience: 0 = only me, 1 = followers, 2 = everyone.
// Returns 1 if the viewer may see the field.
SWIFLY_EXPORT int32_t swifly_can_see(int32_t audience, int32_t is_owner, int32_t viewer_follows_owner) {
    if (is_owner) return 1;
    if (audience == 0) return 0;
    if (audience == 1) return viewer_follows_owner ? 1 : 0;
    return 1;
}
