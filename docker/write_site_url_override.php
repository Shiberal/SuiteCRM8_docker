#!/usr/bin/env php
<?php
/**
 * Write site_url and trusted_hosts to SuiteCRM config_override.php from SITE_URL env.
 * Run from startup.sh so Coolify/reverse-proxy deployments use the correct public URL.
 */
$siteUrl = getenv('SITE_URL');
if ($siteUrl === false || $siteUrl === '') {
    exit(0);
}
$siteUrl = trim($siteUrl);
$siteUrl = rtrim($siteUrl, '/');

$legacyDir = '/var/www/html/SuiteCRM/public/legacy';
$overrideFile = $legacyDir . '/config_override.php';

if (!is_dir($legacyDir)) {
    exit(0);
}

// Build trusted_hosts regex from host part of SITE_URL
$host = parse_url($siteUrl, PHP_URL_HOST);
if ($host === null || $host === '') {
    exit(1);
}
$hostRegex = '^' . preg_quote($host, '/') . '$';

$block = "// Docker SITE_URL override (do not edit)\n"
    . "\$sugar_config['site_url'] = " . var_export($siteUrl, true) . ";\n"
    . "\$sugar_config['trusted_hosts'] = [" . var_export($hostRegex, true) . "];\n";

$marker = '// Docker SITE_URL override';
$existing = is_file($overrideFile) ? file_get_contents($overrideFile) : '';

// Remove previous Docker override block (between marker and next // or end)
$pattern = '/\n?' . preg_quote($marker, '/') . '.*?(?=\n\s*\/\/[^\n]*|\n\s*\?\>|\z)/s';
$cleaned = preg_replace($pattern, '', $existing);
$cleaned = rtrim($cleaned);

$phpOpen = "<?php\n";
if (strpos($cleaned, '<?php') !== 0) {
    $cleaned = $phpOpen . $cleaned;
}
if ($cleaned !== $phpOpen) {
    $cleaned .= "\n";
}
$cleaned .= "\n" . $block;

if (!file_put_contents($overrideFile, $cleaned)) {
    fwrite(STDERR, "Failed to write $overrideFile\n");
    exit(1);
}
@chown($overrideFile, 'www-data');
@chmod($overrideFile, 0644);
