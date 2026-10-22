<?php
// Functional smoke endpoint for the EOL-PHP backport.
// Exercises the surfaces the security patch touches:
//   - session start / persistence across requests
//   - a real multipart/form-data file upload ($_FILES, move_uploaded_file)
// Returns a compact JSON verdict the smoke runner asserts on.

session_start();

$r = ['ok' => false, 'php' => PHP_VERSION, 'checks' => []];

// 1. Session round-trip: increment a per-session counter.
$_SESSION['hits'] = ($_SESSION['hits'] ?? 0) + 1;
$r['checks']['session_counter'] = $_SESSION['hits'];
$r['checks']['session_id_present'] = session_id() !== '';

// 2. File upload: confirm the uploaded file arrived and can be moved.
if (!empty($_FILES['f']['tmp_name']) && is_uploaded_file($_FILES['f']['tmp_name'])) {
    $dest = sys_get_temp_dir() . '/smoke_upload_' . bin2hex(random_bytes(4));
    $moved = move_uploaded_file($_FILES['f']['tmp_name'], $dest);
    $r['checks']['upload_received'] = true;
    $r['checks']['upload_size'] = $_FILES['f']['size'];
    $r['checks']['upload_moved'] = (bool)$moved;
    $r['checks']['upload_bytes_on_disk'] = $moved ? filesize($dest) : 0;
    if ($moved) { @unlink($dest); }
} else {
    $r['checks']['upload_received'] = false;
}

// 3. Confirm the patched behavior: upload-progress tracking is OFF.
//    (The minimal EOL backport hard-disables it. This is informational.)
$prefix = ini_get('session.upload_progress.prefix') ?: 'upload_progress_';
$r['checks']['upload_progress_keys'] = 0;
foreach ($_SESSION as $k => $_) {
    if (strpos($k, $prefix) === 0) { $r['checks']['upload_progress_keys']++; }
}

$r['ok'] = ($r['checks']['session_id_present']
    && ($_SERVER['REQUEST_METHOD'] !== 'POST'
        || ($r['checks']['upload_received'] && $r['checks']['upload_moved']
            && $r['checks']['upload_bytes_on_disk'] === $r['checks']['upload_size'])));

header('Content-Type: application/json');
echo json_encode($r);
