<?php
// common.php - shared helpers for the Swifly media pipeline (PHP).
// Run by C++ (cpp/media_bridge.cpp) through the bundled PHP runtime.

const SWIFLY_PHOTO_MAX_EDGE = 1440;               // longest side of the cached photo
const SWIFLY_THUMB_EDGE = 480;                    // longest side of every thumbnail
const SWIFLY_CACHE_LIMIT_BYTES = 400 * 1024 * 1024; // local cache size before old items are removed

function swifly_emit(array $data): void
{
    echo json_encode($data, JSON_UNESCAPED_SLASHES), "\n";
}

function swifly_fail(string $message): void
{
    swifly_emit(['ok' => false, 'error' => $message]);
    exit(0);
}

/** Looks at the first bytes of the file. Returns photo, video or unknown. */
function swifly_detect_kind(string $path): string
{
    $fh = @fopen($path, 'rb');
    if (!$fh) {
        return 'unknown';
    }
    $head = (string) fread($fh, 32);
    fclose($fh);

    if (strncmp($head, "\xFF\xD8\xFF", 3) === 0) return 'photo';       // JPEG
    if (strncmp($head, "\x89PNG", 4) === 0) return 'photo';            // PNG
    if (strncmp($head, 'GIF8', 4) === 0) return 'photo';               // GIF
    if (strncmp($head, 'RIFF', 4) === 0 && substr($head, 8, 4) === 'WEBP') return 'photo';
    if (strncmp($head, "\x1A\x45\xDF\xA3", 4) === 0) return 'video';   // WebM / MKV
    if (substr($head, 4, 4) === 'ftyp') {
        $brand = substr($head, 8, 4);
        if (in_array($brand, ['heic', 'heix', 'mif1', 'msf1', 'heim', 'heis', 'avif'], true)) {
            return 'photo';
        }
        return 'video';                                                // MP4 / MOV / 3GP
    }

    $ext = strtolower(pathinfo($path, PATHINFO_EXTENSION));
    if (in_array($ext, ['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'heif', 'bmp'], true)) return 'photo';
    if (in_array($ext, ['mp4', 'mov', 'm4v', '3gp', 'webm', 'mkv', 'avi'], true)) return 'video';
    return 'unknown';
}

function swifly_extension(string $path, string $fallback): string
{
    $ext = strtolower(pathinfo($path, PATHINFO_EXTENSION));
    if ($ext === '' || strlen($ext) > 5 || strspn($ext, 'abcdefghijklmnopqrstuvwxyz0123456789') !== strlen($ext)) {
        return $fallback;
    }
    return $ext;
}

function swifly_file_size(string $path): int
{
    $size = @filesize($path);
    return $size === false ? 0 : (int) $size;
}


