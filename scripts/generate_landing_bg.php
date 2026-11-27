<?php

$w = 1080;
$h = 1400;
$img = imagecreatetruecolor($w, $h);
imagealphablending($img, true);
imagesavealpha($img, true);

// Base dark slate background
for ($y = 0; $y < $h; $y++) {
    $c = intval(18 + ($y / $h) * 10);
    $color = imagecolorallocate($img, $c, $c + 2, $c + 6);
    imageline($img, 0, $y, $w, $y, $color);
}

// Function to draw a 3D banknote bundle
function drawBundle($img, $cx, $cy, $bw, $bh, $thick, $angle, $brightness = 1.0) {
    $rad = deg2rad($angle);
    $cos = cos($rad);
    $sin = sin($rad);
    
    // Corners of top face relative to center
    $hw = $bw / 2;
    $hh = $bh / 2;
    
    // 2D projection with isometric tilt (scale Y by 0.62)
    $project = function($rx, $ry, $rz) use ($cx, $cy, $cos, $sin) {
        $tx = $rx * $cos - $ry * $sin;
        $ty = ($rx * $sin + $ry * $cos) * 0.62 - $rz;
        return [$cx + $tx, $cy + $ty];
    };
    
    // Drop shadow
    $shadowColor = imagecolorallocatealpha($img, 0, 0, 0, 95);
    for ($dz = 0; $dz <= 8; $dz += 2) {
        $p0 = $project(-$hw - 4, -$hh - 4, -$dz);
        $p1 = $project($hw + 4, -$hh - 4, -$dz);
        $p2 = $project($hw + 4, $hh + 4, -$dz);
        $p3 = $project(-$hw - 4, $hh + 4, -$dz);
        $pts = [$p0[0], $p0[1], $p1[0], $p1[1], $p2[0], $p2[1], $p3[0], $p3[1]];
        imagefilledpolygon($img, $pts, $shadowColor);
    }
    
    // Side face (bottom)
    $cSide = max(5, intval(45 * $brightness));
    $sideColor = imagecolorallocate($img, $cSide, $cSide + 2, $cSide + 5);
    $p3 = $project(-$hw, $hh, $thick);
    $p2 = $project($hw, $hh, $thick);
    $p2_b = $project($hw, $hh, 0);
    $p3_b = $project(-$hw, $hh, 0);
    imagefilledpolygon($img, [$p3[0], $p3[1], $p2[0], $p2[1], $p2_b[0], $p2_b[1], $p3_b[0], $p3_b[1]], $sideColor);
    
    // Side face (right)
    $cRight = max(5, intval(35 * $brightness));
    $rightColor = imagecolorallocate($img, $cRight, $cRight + 2, $cRight + 4);
    $p1 = $project($hw, -$hh, $thick);
    $p1_b = $project($hw, -$hh, 0);
    imagefilledpolygon($img, [$p1[0], $p1[1], $p2[0], $p2[1], $p2_b[0], $p2_b[1], $p1_b[0], $p1_b[1]], $rightColor);
    
    // Side paper layer lines (stack of 100 notes)
    $lineCol = imagecolorallocatealpha($img, 255, 255, 255, 115);
    for ($z = 2; $z < $thick; $z += 3) {
        $pz1 = $project(-$hw, $hh, $z);
        $pz2 = $project($hw, $hh, $z);
        imageline($img, $pz1[0], $pz1[1], $pz2[0], $pz2[1], $lineCol);
    }
    
    // Top face
    $cTop = max(10, min(240, intval(85 * $brightness)));
    $topColor = imagecolorallocate($img, $cTop, $cTop + 4, $cTop + 8);
    $p0 = $project(-$hw, -$hh, $thick);
    imagefilledpolygon($img, [$p0[0], $p0[1], $p1[0], $p1[1], $p2[0], $p2[1], $p3[0], $p3[1]], $topColor);
    
    // Top face border (engraved banknote border)
    $cBorder = max(15, min(255, intval(140 * $brightness)));
    $borderColor = imagecolorallocate($img, $cBorder, $cBorder + 5, $cBorder + 10);
    $i0 = $project(-$hw + 8, -$hh + 8, $thick);
    $i1 = $project($hw - 8, -$hh + 8, $thick);
    $i2 = $project($hw - 8, $hh - 8, $thick);
    $i3 = $project(-$hw + 8, $hh - 8, $thick);
    imagepolygon($img, [$i0[0], $i0[1], $i1[0], $i1[1], $i2[0], $i2[1], $i3[0], $i3[1]], $borderColor);
    
    // Inner fine guilloche border
    $i0_b = $project(-$hw + 14, -$hh + 14, $thick);
    $i1_b = $project($hw - 14, -$hh + 14, $thick);
    $i2_b = $project($hw - 14, $hh - 14, $thick);
    $i3_b = $project(-$hw + 14, $hh - 14, $thick);
    imagepolygon($img, [$i0_b[0], $i0_b[1], $i1_b[0], $i1_b[1], $i2_b[0], $i2_b[1], $i3_b[0], $i3_b[1]], $borderColor);
    
    // Center emblem / oval
    $centerPt = $project(0, 0, $thick);
    imageellipse($img, $centerPt[0], $centerPt[1], 36 * $brightness, 22 * $brightness, $borderColor);
    imageellipse($img, $centerPt[0], $centerPt[1], 24 * $brightness, 14 * $brightness, $borderColor);
    
    // Currency Band / Strap (white/cream currency wrapper around the middle)
    $strapW = $bw * 0.22;
    $strapCol = imagecolorallocate($img, min(255, intval(180 * $brightness)), min(255, intval(180 * $brightness)), min(255, intval(175 * $brightness)));
    $s0 = $project(-$strapW/2, -$hh - 1, $thick + 0.5);
    $s1 = $project($strapW/2, -$hh - 1, $thick + 0.5);
    $s2 = $project($strapW/2, $hh + 1, $thick + 0.5);
    $s3 = $project(-$strapW/2, $hh + 1, $thick + 0.5);
    imagefilledpolygon($img, [$s0[0], $s0[1], $s1[0], $s1[1], $s2[0], $s2[1], $s3[0], $s3[1]], $strapCol);
    
    // Strap strap shadow & text line
    $strapLine = imagecolorallocate($img, intval(90 * $brightness), intval(90 * $brightness), intval(90 * $brightness));
    $sl0 = $project(-$strapW/2 + 4, 0, $thick + 0.6);
    $sl1 = $project($strapW/2 - 4, 0, $thick + 0.6);
    imageline($img, $sl0[0], $sl0[1], $sl1[0], $sl1[1], $strapLine);
    
    // Side strap continuation
    $ss0 = $project(-$strapW/2, $hh + 1, $thick + 0.5);
    $ss1 = $project($strapW/2, $hh + 1, $thick + 0.5);
    $ss2 = $project($strapW/2, $hh + 1, 0);
    $ss3 = $project(-$strapW/2, $hh + 1, 0);
    $strapSideCol = imagecolorallocate($img, intval(110 * $brightness), intval(110 * $brightness), intval(105 * $brightness));
    imagefilledpolygon($img, [$ss0[0], $ss0[1], $ss1[0], $ss1[1], $ss2[0], $ss2[1], $ss3[0], $ss3[1]], $strapSideCol);
}

// Generate scattered bundles grid across top and middle
mt_srand(42891);
// Layer 1: Background bundles (smaller, darker)
for ($i = 0; $i < 35; $i++) {
    $x = mt_rand(40, $w - 40);
    $y = mt_rand(30, intval($h * 0.70));
    $ang = mt_rand(-45, 45);
    $scale = mt_rand(75, 95) / 100.0;
    drawBundle($img, $x, $y, 230 * $scale, 115 * $scale, 22 * $scale, $ang, 0.65);
}

// Layer 2: Midground bundles
for ($i = 0; $i < 28; $i++) {
    $x = mt_rand(60, $w - 60);
    $y = mt_rand(50, intval($h * 0.65));
    $ang = mt_rand(-35, 35);
    $scale = mt_rand(95, 115) / 100.0;
    drawBundle($img, $x, $y, 250 * $scale, 125 * $scale, 26 * $scale, $ang, 0.95);
}

// Layer 3: Foreground prominent bundles
for ($i = 0; $i < 18; $i++) {
    $x = mt_rand(80, $w - 80);
    $y = mt_rand(70, intval($h * 0.58));
    $ang = mt_rand(-25, 25);
    $scale = mt_rand(115, 135) / 100.0;
    drawBundle($img, $x, $y, 270 * $scale, 135 * $scale, 30 * $scale, $ang, 1.25);
}

// Seamless gradient fade to deep dark at bottom
for ($y = 0; $y < $h; $y++) {
    $progress = $y / $h;
    if ($progress > 0.28) {
        $t = min(1.0, ($progress - 0.28) / 0.40);
        // In GD, alpha: 0 is opaque, 127 is fully transparent.
        $gdAlpha = intval(127 * (1.0 - $t));
        $darkOverlay = imagecolorallocatealpha($img, 11, 15, 25, $gdAlpha);
        imageline($img, 0, $y, $w, $y, $darkOverlay);
    }
}

// Deep dark fill for the bottom 32%
$deepDark = imagecolorallocate($img, 11, 15, 25);
imagefilledrectangle($img, 0, intval($h * 0.68), $w, $h, $deepDark);

$outDir = __DIR__ . '/../assets/images';
if (!is_dir($outDir)) mkdir($outDir, 0777, true);
$outFile = $outDir . '/landing_hero_bg.png';
imagepng($img, $outFile, 8);
imagedestroy($img);
echo 'SUCCESS: Generated ' . realpath($outFile) . ' (' . filesize($outFile) . " bytes)\n";
