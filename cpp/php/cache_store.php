<?php
// cache_store.php - the local media cache (PHP).
//
// Layout inside the cache folder:
//   originals/<key>.<ext>   processed photo or copied video
//   thumbs/<key>.jpg        small preview that shows instantly
//   index.json              one entry per key, with last-use time for cleanup
//
// The key comes from the source path, size and modified time, so the same file is
// never processed twice.

final class SwiflyCache
{
    private string $dir;
    private string $indexFile;

    public function __construct(string $dir)
    {
        $this->dir = rtrim($dir, '/');
        foreach (['', '/originals', '/thumbs'] as $sub) {
            if (!is_dir($this->dir . $sub)) {
                @mkdir($this->dir . $sub, 0775, true);
            }
        }
        $this->indexFile = $this->dir . '/index.json';
    }

    public function keyFor(string $src): string
    {
        $st = @stat($src);
        if ($st === false) {
            return '';
        }
        return sha1($src . '|' . $st['size'] . '|' . $st['mtime']);
    }

    public function path(string $folder, string $key, string $ext): string
    {
        return $this->dir . '/' . $folder . '/' . $key . '.' . $ext;
    }

    /** Runs $fn with the index (by reference) while holding a file lock, then saves it. */
    private function withIndex(callable $fn)
    {
        $fh = @fopen($this->indexFile, 'c+');
        if (!$fh) {
            $idx = [];
            return $fn($idx);
        }
        flock($fh, LOCK_EX);
        $raw = stream_get_contents($fh);
        $idx = json_decode($raw === false || $raw === '' ? '{}' : $raw, true);
        if (!is_array($idx)) {
            $idx = [];
        }
        $result = $fn($idx);
        ftruncate($fh, 0);
        rewind($fh);
        fwrite($fh, json_encode($idx, JSON_UNESCAPED_SLASHES));
        fflush($fh);
        flock($fh, LOCK_UN);
        fclose($fh);
        return $result;
    }

    /** Returns the cached entry if its files are still there, and marks it as used now. */
    public function find(string $key): ?array
    {
        return $this->withIndex(function (array &$idx) use ($key) {
            if (!isset($idx[$key])) {
                return null;
            }
            $e = $idx[$key];
            $thumbOk = ($e['thumb'] ?? '') === '' || is_file($e['thumb']);
            if (!is_file($e['path'] ?? '') || !$thumbOk) {
                unset($idx[$key]);
                return null;
            }
            $idx[$key]['last'] = time();
            return $idx[$key];
        });
    }

    public function put(string $key, array $entry): void
    {
        $entry['last'] = time();
        $this->withIndex(function (array &$idx) use ($key, $entry) {
            $idx[$key] = $entry;
            return null;
        });
    }

    /** Removes the least recently used items until the cache is under the limit. */
    public function evict(int $limitBytes): int
    {
        return $this->withIndex(function (array &$idx) use ($limitBytes) {
            $total = 0;
            foreach ($idx as $key => $e) {
                if (!is_file($e['path'] ?? '')) {
                    unset($idx[$key]);
                    continue;
                }
                $total += (int) ($e['bytes'] ?? 0);
            }
            if ($total <= $limitBytes) {
                return 0;
            }
            uasort($idx, fn($a, $b) => ($a['last'] ?? 0) <=> ($b['last'] ?? 0));
            $target = (int) ($limitBytes * 0.85);
            $removed = 0;
            foreach ($idx as $key => $e) {
                if ($total <= $target) {
                    break;
                }
                @unlink($e['path']);
                if (($e['thumb'] ?? '') !== '' && strpos($e['thumb'], '/thumbs/') !== false) {
                    @unlink($e['thumb']);
                }
                $total -= (int) ($e['bytes'] ?? 0);
                unset($idx[$key]);
                $removed++;
            }
            return $removed;
        });
    }
}



