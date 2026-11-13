<?php
// main.php - entry point. C++ runs:  php main.php <op> <src> <hint> <cacheDir>
// Prints exactly one JSON line.
//   process : photo or video -> cache (instant if it was processed before)
//   lookup  : cache entry for a source file, or ok:false
//   evict   : remove old items when the cache is over its size limit

@ini_set('display_errors', '0');
@set_time_limit(120);

$dir = __DIR__;
require_once $dir . '/common.php';
require_once $dir . '/cache_store.php';
require_once $dir . '/photo_processor.php';
require_once $dir . '/video_processor.php';

$op = $argv[1] ?? '';
$src = $argv[2] ?? '';
$hint = $argv[3] ?? '';
$cacheDir = $argv[4] ?? '';

if ($cacheDir === '') {
    swifly_fail('missing cache folder');
}
$cache = new SwiflyCache($cacheDir);

if ($op === 'evict') {
    swifly_emit(['ok' => true, 'removed' => $cache->evict(SWIFLY_CACHE_LIMIT_BYTES)]);
    exit(0);
}

if ($src === '' || !is_file($src)) {
    swifly_fail('source file not found');
}
$key = $cache->keyFor($src);
if ($key === '') {
    swifly_fail('cannot read source file');
}

$hit = $cache->find($key);
if ($op === 'lookup') {
    if ($hit === null) swifly_fail('not cached');
    $hit['ok'] = true;
    $hit['cached'] = true;
    swifly_emit($hit);
    exit(0);
}

if ($op !== 'process') {
    swifly_fail('unknown operation');
}
if ($hit !== null) {
    $hit['ok'] = true;
    $hit['cached'] = true;
    swifly_emit($hit);
    exit(0);
}

$kind = swifly_detect_kind($src);
if ($kind === 'photo') {
    $entry = swifly_process_photo($src, $hint, $cache, $key);
} elseif ($kind === 'video') {
    $entry = swifly_process_video($src, $hint, $cache, $key);
} else {
    swifly_fail('unsupported file type');
}

$cache->put($key, $entry);
$cache->evict(SWIFLY_CACHE_LIMIT_BYTES);
$entry['cached'] = false;
swifly_emit($entry);



