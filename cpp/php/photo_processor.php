<?php
// photo_processor.php - everything that happens to a photo (PHP).
// Fixes the phone's rotation, makes a smaller cached photo and a tiny thumbnail.
// Uses GD when the PHP runtime has it; otherwise copies the file and keeps going.

/** Reads the EXIF orientation (1-8) of a JPEG without any extension. */
function swifly_jpeg_orientation(string $path): int
{
    $fh = @fopen($path, 'rb');
    if (!$fh) return 1;
    $data = (string) fread($fh, 65536);
    fclose($fh);
    $len = strlen($data);
    if ($len < 12 || substr($data, 0, 2) !== "\xFF\xD8") return 1;

    $pos = 2;
    while ($pos + 4 <= $len) {
        if ($data[$pos] !== "\xFF") break;
        $marker = ord($data[$pos + 1]);
        if ($marker === 0xD8 || ($marker >= 0xD0 && $marker <= 0xD7) || $marker === 0x01) {
            $pos += 2;
            continue;
        }
        if ($marker === 0xDA) break;
        $size = unpack('n', substr($data, $pos + 2, 2))[1];

        if ($marker === 0xE1 && substr($data, $pos + 4, 6) === "Exif\0\0") {
            $tiff = $pos + 10;
            $order = substr($data, $tiff, 2);
            if ($order !== 'II' && $order !== 'MM') return 1;
            $little = ($order === 'II');
            $u16 = function (int $o) use ($data, $little): int {
                $r = unpack($little ? 'v' : 'n', substr($data, $o, 2));
                return $r ? $r[1] : 0;
            };
            $u32 = function (int $o) use ($data, $little): int {
                $r = unpack($little ? 'V' : 'N', substr($data, $o, 4));
                return $r ? $r[1] : 0;
            };
            $ifd = $tiff + $u32($tiff + 4);
            if ($ifd + 2 > $len) return 1;
            $count = $u16($ifd);
            for ($i = 0; $i < $count; $i++) {
                $entry = $ifd + 2 + $i * 12;
                if ($entry + 12 > $len) break;
                if ($u16($entry) === 0x0112) {
                    $v = $u16($entry + 8);
                    return ($v >= 1 && $v <= 8) ? $v : 1;
                }
            }
            return 1;
        }
        $pos += 2 + $size;
    }
    return 1;
}

function swifly_gd_available(): bool
{
    return function_exists('imagecreatetruecolor') && function_exists('imagejpeg');
}

/** Opens a picture with GD, or returns null if this format is not supported. */
function swifly_gd_open(string $path, int $type)
{
    switch ($type) {
        case IMAGETYPE_JPEG:
            return function_exists('imagecreatefromjpeg') ? @imagecreatefromjpeg($path) : null;
        case IMAGETYPE_PNG:
            return function_exists('imagecreatefrompng') ? @imagecreatefrompng($path) : null;
        case IMAGETYPE_GIF:
            return function_exists('imagecreatefromgif') ? @imagecreatefromgif($path) : null;
        case IMAGETYPE_WEBP:
            return function_exists('imagecreatefromwebp') ? @imagecreatefromwebp($path) : null;
    }
    return null;
}

function swifly_gd_orient($img, int $orientation)
{
    switch ($orientation) {
        case 2: imageflip($img, IMG_FLIP_HORIZONTAL); return $img;
        case 3: return imagerotate($img, 180, 0) ?: $img;
        case 4: imageflip($img, IMG_FLIP_VERTICAL); return $img;
        case 5: imageflip($img, IMG_FLIP_HORIZONTAL); return imagerotate($img, 90, 0) ?: $img;
        case 6: return imagerotate($img, -90, 0) ?: $img;
        case 7: imageflip($img, IMG_FLIP_HORIZONTAL); return imagerotate($img, -90, 0) ?: $img;
        case 8: return imagerotate($img, 90, 0) ?: $img;
    }
    return $img;
}

/** Returns a new picture whose longest side is at most $maxEdge (white behind transparency). */
function swifly_gd_fit($img, int $maxEdge)
{
    $w = imagesx($img);
    $h = imagesy($img);
    $scale = min(1.0, $maxEdge / max($w, $h));
    $nw = max(1, (int) round($w * $scale));
    $nh = max(1, (int) round($h * $scale));
    $out = imagecreatetruecolor($nw, $nh);
    imagefill($out, 0, 0, imagecolorallocate($out, 255, 255, 255));
    imagecopyresampled($out, $img, 0, 0, 0, 0, $nw, $nh, $w, $h);
    return $out;
}

/**
 * Processes one photo into the cache. Returns the cache entry.
 * $hint is an optional ready-made thumbnail (used only when GD is missing).
 */
function swifly_process_photo(string $src, string $hint, SwiflyCache $cache, string $key): array
{
    $info = @getimagesize($src);
    $w = $info ? (int) $info[0] : 0;
    $h = $info ? (int) $info[1] : 0;
    $type = $info ? (int) $info[2] : 0;

    $engine = 'php';
    $dest = $cache->path('originals', $key, 'jpg');
    $thumb = $cache->path('thumbs', $key, 'jpg');
    $done = false;

    if ($info && swifly_gd_available()) {
        $img = swifly_gd_open($src, $type);
        if ($img) {
            if ($type === IMAGETYPE_JPEG) {
                $img = swifly_gd_orient($img, swifly_jpeg_orientation($src));
            }
            $main = swifly_gd_fit($img, SWIFLY_PHOTO_MAX_EDGE);
            imagedestroy($img);
            $small = swifly_gd_fit($main, SWIFLY_THUMB_EDGE);
            $done = imagejpeg($main, $dest, 82) && imagejpeg($small, $thumb, 75);
            $w = imagesx($main);
            $h = imagesy($main);
            imagedestroy($main);
            imagedestroy($small);
            $engine = 'php-gd';
        }
    }

    if (!$done) {
        // No GD (or an unsupported format such as HEIC): keep the original bytes.
        $dest = $cache->path('originals', $key, swifly_extension($src, 'jpg'));
        if (!@copy($src, $dest)) {
            swifly_fail('could not copy photo into cache');
        }
        if ($hint !== '' && is_file($hint) && @copy($hint, $thumb)) {
            // use the ready-made thumbnail
        } else {
            $thumb = $dest; // the photo itself is the preview
        }
    }

    return [
        'ok' => true,
        'engine' => $engine,
        'kind' => 'photo',
        'key' => $key,
        'path' => $dest,
        'thumb' => $thumb,
        'w' => $w,
        'h' => $h,
        'durationMs' => 0,
        'bytes' => swifly_file_size($dest) + ($thumb !== $dest ? swifly_file_size($thumb) : 0),
    ];
}
