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


// ---------------------------------------------------------------------------
// Profile suggestions (company, school, hobby, place ... search-as-you-type).
//
// `joined` is every candidate, lowercase and accent-free, separated by '\n'.
// `query` is already lowercase and accent-free (Dart folds both sides).
// Scores (higher is better), kept identical to NativeCore._dartSuggest:
//   1000 exact | 900 starts with | 700 a later word starts with
//    500 contains | 450 every query word starts a word | 320 one typo
//    150 letters appear in order (only for queries of 3+ letters)
// Ties keep the list order, so each dataset's popularity order still counts.
// ---------------------------------------------------------------------------
namespace swifly {

bool is_word_break(char c) {
    return c == ' ' || c == '-' || c == '.' || c == '/' || c == '&' || c == '(' ||
           c == ',' || c == ':' || c == '+';
}

// True if some word in `c` starts with `w`.
bool has_word_prefix(const std::string& c, const std::string& w) {
    if (w.empty()) return true;
    size_t pos = 0;
    while ((pos = c.find(w, pos)) != std::string::npos) {
        if (pos == 0 || is_word_break(c[pos - 1])) return true;
        ++pos;
    }
    return false;
}

bool one_typo_prefix(const std::string& c, const std::string& q) {
    const size_t n = q.size();
    if (n < 4 || c.size() < n) return false;
    int diff = 0;
    size_t first = 0;
    for (size_t i = 0; i < n; ++i) {
        if (c[i] != q[i]) {
            if (diff == 0) first = i;
            ++diff;
            if (diff > 2) return false;
        }
    }
    if (diff == 1) return true;
    // Two neighbouring letters swapped ("googel" for "google").
    return diff == 2 && first + 1 < n && c[first] == q[first + 1] && c[first + 1] == q[first];
}

bool is_subsequence(const std::string& c, const std::string& q) {
    size_t qi = 0;
    for (size_t ci = 0; ci < c.size() && qi < q.size(); ++ci) {
        if (c[ci] == q[qi]) ++qi;
    }
    return qi == q.size();
}

int32_t suggest_score(const std::string& c, const std::string& q,
                      const std::vector<std::string>& words) {
    if (c == q) return 1000;
    const int32_t extra = static_cast<int32_t>(c.size() - std::min(c.size(), q.size()));
    if (c.size() > q.size() && c.compare(0, q.size(), q) == 0) {
        return 900 - std::min<int32_t>(extra, 60);
    }
    size_t pos = 0;
    while ((pos = c.find(q, pos)) != std::string::npos) {
        if (pos > 0 && is_word_break(c[pos - 1])) {
            return 700 - std::min<int32_t>(static_cast<int32_t>(pos), 60);
        }
        ++pos;
    }
    pos = c.find(q);
    if (pos != std::string::npos) {
        return 500 - std::min<int32_t>(static_cast<int32_t>(pos), 60);
    }
    if (words.size() >= 2) {
        bool all = true;
        for (const std::string& w : words) {
            if (!has_word_prefix(c, w)) { all = false; break; }
        }
        if (all) return 450;
    }
    if (one_typo_prefix(c, q)) return 320 - std::min<int32_t>(extra, 40);
    if (q.size() >= 3 && is_subsequence(c, q)) return 150;
    return 0;
}

}  // namespace swifly

// Fills out_idx / out_scores with the best matches (best first).
// Returns how many were written (at most max_results).
SWIFLY_EXPORT int32_t swifly_suggest_search(const char* joined, const char* query,
                                            int32_t max_results, int32_t* out_idx,
                                            int32_t* out_scores) {
    if (joined == nullptr || query == nullptr || out_idx == nullptr ||
        out_scores == nullptr || max_results <= 0) {
        return 0;
    }
    const std::string q(query);
    if (q.empty()) return 0;

    std::vector<std::string> words;
    {
        std::string cur;
        for (char ch : q) {
            if (ch == ' ') {
                if (!cur.empty()) words.push_back(cur);
                cur.clear();
            } else {
                cur += ch;
            }
        }
        if (!cur.empty()) words.push_back(cur);
    }

    struct Hit { int32_t index; int32_t score; };
    std::vector<Hit> hits;
    int32_t index = 0;
    const char* p = joined;
    while (true) {
        const char* end = std::strchr(p, '\n');
        const size_t len = end ? static_cast<size_t>(end - p) : std::strlen(p);
        const std::string candidate(p, len);
        const int32_t score = swifly::suggest_score(candidate, q, words);
        if (score > 0) hits.push_back({index, score});
        ++index;
        if (end == nullptr) break;
        p = end + 1;
    }

    std::stable_sort(hits.begin(), hits.end(),
                     [](const Hit& a, const Hit& b) { return a.score > b.score; });
    const int32_t n = std::min<int32_t>(max_results, static_cast<int32_t>(hits.size()));
    for (int32_t i = 0; i < n; ++i) {
        out_idx[i] = hits[static_cast<size_t>(i)].index;
        out_scores[i] = hits[static_cast<size_t>(i)].score;
    }
    return n;
}


// ---------------------------------------------------------------------------
// Direct messages (inbox, requests, filters, ordering).
// Every function has an identical pure-Dart fallback in lib/native_bridge.dart.
// ---------------------------------------------------------------------------

// Which inbox tab a conversation belongs to.
//   0 = Primary, 1 = Requests, 2 = General
// A chat is a REQUEST while I do not follow that person, I never replied and I
// never pressed Accept. A chat that has been quiet for 7+ days with nothing
// unread moves to General. Everything else is Primary.
SWIFLY_EXPORT int32_t swifly_dm_bucket(int32_t is_following, int32_t i_replied,
                                       int32_t accepted, int32_t hours_since_last,
                                       int32_t unread) {
    if (!is_following && !i_replied && !accepted) return 1;
    if (unread == 0 && hours_since_last >= 24 * 7) return 2;
    return 0;
}

// Filter flags: 1 unread, 2 unanswered, 4 story replies, 8 following, 16 follows me.
// A conversation passes when it has EVERY flag that is turned on in mask.
SWIFLY_EXPORT int32_t swifly_dm_filter_pass(int32_t flags, int32_t mask) {
    return (flags & mask) == mask ? 1 : 0;
}

// Orders conversations newest message first. Ties keep their original order.
SWIFLY_EXPORT void swifly_dm_sort_threads(const int64_t* last_ms, int32_t n,
                                          int32_t* out_order) {
    if (!last_ms || !out_order || n <= 0) return;
    std::vector<int32_t> idx(static_cast<size_t>(n));
    std::iota(idx.begin(), idx.end(), 0);
    std::stable_sort(idx.begin(), idx.end(), [last_ms](int32_t a, int32_t b) {
        return last_ms[a] > last_ms[b];
    });
    std::copy(idx.begin(), idx.end(), out_order);
}

// Short relative label: now, 5m, 3h, 2d, 3w.
SWIFLY_EXPORT int32_t swifly_dm_time_label(int64_t seconds, char* out, int32_t out_len) {
    if (out == nullptr || out_len <= 0) return 0;
    if (seconds < 0) seconds = 0;
    char buf[24];
    int len;
    if (seconds < 60) {
        len = std::snprintf(buf, sizeof(buf), "now");
    } else if (seconds < 3600) {
        len = std::snprintf(buf, sizeof(buf), "%lldm", static_cast<long long>(seconds / 60));
    } else if (seconds < 86400) {
        len = std::snprintf(buf, sizeof(buf), "%lldh", static_cast<long long>(seconds / 3600));
    } else if (seconds < 86400LL * 7) {
        len = std::snprintf(buf, sizeof(buf), "%lldd", static_cast<long long>(seconds / 86400));
    } else {
        len = std::snprintf(buf, sizeof(buf), "%lldw", static_cast<long long>(seconds / (86400LL * 7)));
    }
    const int32_t copy = std::min<int32_t>(len, out_len - 1);
    std::memcpy(out, buf, static_cast<size_t>(copy));
    out[copy] = '\0';
    return copy;
}

// Cuts text to max_chars characters (not bytes, so emoji and accents stay whole),
// turns line breaks into spaces and adds "..." when something was cut.
// Used for the inbox preview and for the quoted message above a reply.
SWIFLY_EXPORT int32_t swifly_dm_clip(const char* text, int32_t max_chars,
                                     char* out, int32_t out_len) {
    if (out == nullptr || out_len <= 0) return 0;
    out[0] = '\0';
    if (text == nullptr || max_chars <= 0) return 0;

    std::string result;
    int32_t chars = 0;
    bool cut = false;
    const unsigned char* p = reinterpret_cast<const unsigned char*>(text);
    while (*p) {
        size_t step = 1;
        if ((*p & 0xF8) == 0xF0) step = 4;
        else if ((*p & 0xF0) == 0xE0) step = 3;
        else if ((*p & 0xE0) == 0xC0) step = 2;
        if (chars >= max_chars) { cut = true; break; }
        if (*p == '\n' || *p == '\r') {
            if (result.empty() || result.back() != ' ') result += ' ';
            ++p;
        } else {
            size_t k = 0;
            while (k < step && p[k] != 0) ++k;   // never read past the end
            result.append(reinterpret_cast<const char*>(p), k);
            p += k;
        }
        ++chars;
    }
    if (cut) result += "...";

    const size_t room = static_cast<size_t>(out_len - 1);
    size_t copy = std::min(result.size(), room);
    // Do not leave half of a multi-byte character at the end.
    while (copy > 0 && copy < result.size() &&
           (static_cast<unsigned char>(result[copy]) & 0xC0) == 0x80) {
        --copy;
    }
    std::memcpy(out, result.data(), copy);
    out[copy] = '\0';
    return static_cast<int32_t>(copy);
}

// Ranks "accounts to follow". People who already follow me come first
// (so the button says "Follow back"), then the rest in their original order.
SWIFLY_EXPORT void swifly_dm_rank_people(const int32_t* follows_me, const int32_t* mutual_count,
                                         int32_t n, int32_t* out_order) {
    if (!follows_me || !mutual_count || !out_order || n <= 0) return;
    std::vector<int32_t> score(static_cast<size_t>(n));
    for (int32_t i = 0; i < n; ++i) {
        score[i] = (follows_me[i] ? 1000 : 0) + std::min<int32_t>(mutual_count[i], 99);
    }
    std::vector<int32_t> idx(static_cast<size_t>(n));
    std::iota(idx.begin(), idx.end(), 0);
    std::stable_sort(idx.begin(), idx.end(), [&score](int32_t a, int32_t b) {
        return score[a] > score[b];
    });
    std::copy(idx.begin(), idx.end(), out_order);
}
