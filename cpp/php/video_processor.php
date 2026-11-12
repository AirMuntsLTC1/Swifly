<?php
// video_processor.php - everything that happens to a video (PHP).
// Reads size and length from the MP4 header, makes the thumbnail, and keeps a local copy.
//
// Thumbnail order: ffmpeg (if the app ships one) -> the picker's preview ($hint) -> none.
// The player in the app still shows the first frame, so a video never stays blank.

/** Finds duration and picture size inside the 'moov' box of an MP4 / MOV file. */
function swifly_mp4_probe(string $path): array
{
    $out = ['durationMs' => 0, 'w' => 0, 'h' => 0];
    $fh = @fopen($path, 'rb');
    if (!$fh) return $out;
    $size = (int) filesize($path);
    $pos = 0;

    while ($pos + 8 <= $size) {
        fseek($fh, $pos);
        $hdr = (string) fread($fh, 16);
        if (strlen($hdr) < 8) break;
        $len = unpack('N', substr($hdr, 0, 4))[1];
        $type = substr($hdr, 4, 4);
        $hlen = 8;
        if ($len === 1) {
            if (strlen($hdr) < 16) break;
            $len = unpack('J', substr($hdr, 8, 8))[1];
            $hlen = 16;
        } elseif ($len === 0) {
            $len = $size - $pos;
        }
        if ($len < $hlen) break;

        if ($type === 'moov') {
            $body = $len - $hlen;
            if ($body > 0 && $body <= 16 * 1024 * 1024) {
                fseek($fh, $pos + $hlen);
                swifly_mp4_scan((string) fread($fh, $body), $out);
            }
            break;
        }
        $pos += $len;
    }
    fclose($fh);
    return $out;
}

function swifly_mp4_scan(string $data, array &$out): void
{
    $pos = 0;
    $n = strlen($data);
    while ($pos + 8 <= $n) {
        $len = unpack('N', substr($data, $pos, 4))[1];
        $type = substr($data, $pos + 4, 4);
        if ($len < 8 || $pos + $len > $n) break;
        $body = substr($data, $pos + 8, $len - 8);

        if ($type === 'mvhd' && strlen($body) >= 28) {
            if (ord($body[0]) === 1) {
                $ts = unpack('N', substr($body, 20, 4))[1];
                $dur = unpack('J', substr($body, 24, 8))[1];
            } else {
                $ts = unpack('N', substr($body, 12, 4))[1];
                $dur = unpack('N', substr($body, 16, 4))[1];
            }
            if ($ts > 0) {
                $out['durationMs'] = (int) round($dur * 1000 / $ts);
            }
        } elseif ($type === 'tkhd' && $out['w'] === 0) {
            $off = (ord($body[0]) === 1) ? 88 : 76;
            if (strlen($body) >= $off + 8) {
                $w = unpack('N', substr($body, $off, 4))[1] >> 16;
                $h = unpack('N', substr($body, $off + 4, 4))[1] >> 16;
                $matrixA = unpack('N', substr($body, $off - 36, 4))[1];
                $matrixB = unpack('N', substr($body, $off - 32, 4))[1];
                if ($w > 0 && $h > 0) {
                    if ($matrixA === 0 && $matrixB !== 0) {
                        [$w, $h] = [$h, $w]; // recorded sideways, shown upright
                    }
                    $out['w'] = $w;
                    $out['h'] = $h;
                }
            }
        } elseif ($type === 'trak' || $type === 'mdia') {
            swifly_mp4_scan($body, $out);
        }
        $pos += $len;
    }
}

/** Tries ffmpeg for a frame at 0.3 seconds. Returns true when the thumbnail file exists. */
function swifly_video_ffmpeg_thumb(string $src, string $thumb): bool
{
    $ffmpeg = getenv('SWIFLY_FFMPEG');
    if (!$ffmpeg || !is_executable($ffmpeg) || !function_exists('exec')) {
        return false;
    }
    $cmd = escapeshellarg($ffmpeg) . ' -y -loglevel error -ss 0.3 -i ' . escapeshellarg($src)
        . ' -frames:v 1 -vf ' . escapeshellarg('scale=' . SWIFLY_THUMB_EDGE . ':-2')
        . ' -q:v 4 ' . escapeshellarg($thumb) . ' 2>&1';
    @exec($cmd);
    return is_file($thumb) && filesize($thumb) > 0;
}

/** Shrinks the picker's preview picture into the cache thumbnail. */
function swifly_video_hint_thumb(string $hint, string $thumb): bool
{
    if ($hint === '' || !is_file($hint)) {
        return false;
    }
    if (swifly_gd_available()) {
        $info = @getimagesize($hint);
        if ($info) {
            $img = swifly_gd_open($hint, (int) $info[2]);
            if ($img) {
                $small = swifly_gd_fit($img, SWIFLY_THUMB_EDGE);
                imagedestroy($img);
                $ok = imagejpeg($small, $thumb, 75);
                imagedestroy($small);
                if ($ok) return true;
            }
        }
    }
    return @copy($hint, $thumb);
}

/** Processes one video into the cache. Returns the cache entry. */
function swifly_process_video(string $src, string $hint, SwiflyCache $cache, string $key): array
{
    $probe = swifly_mp4_probe($src);
    $dest = $cache->path('originals', $key, swifly_extension($src, 'mp4'));
    $thumb = $cache->path('thumbs', $key, 'jpg');

    if (!@copy($src, $dest)) {
        swifly_fail('could not copy video into cache');
    }

    if (!swifly_video_ffmpeg_thumb($dest, $thumb) && !swifly_video_hint_thumb($hint, $thumb)) {
        $thumb = '';
    }

    return [
        'ok' => true,
        'engine' => 'php',
        'kind' => 'video',
        'key' => $key,
        'path' => $dest,
        'thumb' => $thumb,
        'w' => $probe['w'],
        'h' => $probe['h'],
        'durationMs' => $probe['durationMs'],
        'bytes' => swifly_file_size($dest) + ($thumb !== '' ? swifly_file_size($thumb) : 0),
    ];
}
