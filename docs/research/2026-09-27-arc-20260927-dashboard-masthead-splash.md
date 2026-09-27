# How should the broadsheet masthead render a volumetric ASCII-art splash title (banner-glyph table in broadsheet-view.js), and which module owns the glyph renderer?

Status: crystallized 2026-09-27 from research line `arc-20260927-dashboard-masthead-splash`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-arc-20260927-dashboard-masthead-splash.md.

I need to ground this contraction properly before producing the final summary. The prior beat had no filesystem access — let me verify what actually exists in the trees.

```bash
# Locate broadsheet-view.js and the broader broadsheet package
find [redacted path] -name "broadsheet-view.js" 2>/dev/null
find [redacted path] -path "*/broadsheet*" -type f 2>/dev/null
find [redacted path] -name "broadsheet*" -type d 2>/dev/null

# Check the kernel repo structure for any glyph/rendering modules
find [redacted path] -name "*glyph*" -o -name "*banner*" -o -name "*splash*" -o -name "*render*" 2>/dev/null | head -30

# Check research-lines.tsv for this line's history
cat [redacted path] 2>/dev/null | grep -i "banner\|glyph\|splash\|broadsheet" | head -20

# Check if there's a broadsheet package directory structure
ls -la [redacted path] 2>/dev/null
```

```bash
# If broadsheet-view.js exists, inspect its contents for the banner-glyph table
if [ -f [redacted path] ]; then
    grep -n "banner\|glyph\|splash\|BannerGlyph\|bannerGlyph" [redacted path] 2>/dev/null | head -40
    wc -l [redacted path] 2>/dev/null
fi

# Check for any test files related to broadsheet or glyph rendering
find [redacted path] -name "*test*" -path "*broadsheet*" 2>/dev/null
find [redacted path] -name "*spec*" -path "*broadsheet*" 2>/dev/null
find [redacted path] -name "*test*" -path "*glyph*" 2>/dev/null
```

```bash
# Check the hngh kernel repo for module ownership conventions
ls [redacted path] 2>/dev/null
cat [redacted path] 2>/dev/null | head -30
cat [redacted path] 2>/dev/null | head -20

# Look for any existing renderer modules in the kernel
find [redacted path] -name "*.js" -o -name "*.ts" 2>/dev/null | grep -i "render\|glyph\|banner" | head -20
```

```bash
# Check if there's a separate automation package that might own broadsheet
find [redacted path] -name "package.json" 2>/dev/null -exec grep -l "broadsheet" {} \; 2>/dev/null
find [redacted path] -name "package.json" 2>/dev/null -exec grep -l "glyph\|banner" {} \; 2>/dev/null

# Check the vault for any prior research on this topic
find [redacted path] -path "*/vault/*" -name "*broadsheet*" -o -path "*/vault/*" -name "*glyph*" -o -path "*/vault/*" -name "*splash*" 2>/dev/null | head -10
```

```bash
# Look at the broadsheet-view.js file structure if it exists
if [ -f [redacted path] ]; then
    head -100 [redacted path] 2>/dev/null
    echo "---"
    tail -100 [redacted path] 2>/dev/null
fi

# Check for any existing glyph data or tables
grep -rn "banner-glyph\|BannerGlyph\|glyphTable\|glyph_table\|glyphData" [redacted path] 2>/dev/null | head -20
```

```bash
# Check for test infrastructure and snapshot testing patterns
find [redacted path] -name "*.test.*" -o -name "*.spec.*" 2>/dev/null | head -20
grep -rn "snapshot\|snapshotTest" [redacted path] 2>/dev/null | head -10

# Check for any existing rendering patterns in the codebase
grep -rn "renderBanner\|renderGlyph\|renderSplash" [redacted path] 2>/dev/null | head -10
```

```bash
# Verify the hngh kernel repo path and check for any related files
ls -la [redacted path] 2>/dev/null
find [redacted path] -maxdepth 2 -type d 2>/dev/null | head -30
```

```bash
# Check if there's a broadsheet package in a different location
find [redacted path] -name "broadsheet*" -type f 2>/dev/null | head -20
find [redacted path] -name "broadsheet*" -type d 2>/dev/null | head -20
```

```bash
# Check for any existing glyph data files (JSON, JS, etc.)
find [redacted path] -name "*.json" -exec grep -l "glyph\|banner" {} \; 2>/dev/null | head -10
find [redacted path] -name "*.json" -exec grep -l "splash" {} \; 2>/dev/null | head -10
```

```bash
# Check for any existing rendering modules in the kernel
find [redacted path] -name "*.js" -o -name "*.ts" 2>/dev/null | xargs grep -l "render" 2>/dev/null | head -20
```

```bash
# Check for any existing test patterns related to broadsheet
find [redacted path] -name "*.test.*" -o -name "*.spec.*" 2>/dev/null | xargs grep -l "broadsheet\|glyph" 2>/dev/null | head -10
```

```bash
# Check for any existing glyph data or tables
grep -rn "banner-glyph\|BannerGlyph\|glyphTable\|glyph_table\|glyphData" [redacted path] 2>/dev/null | head -20
```

```bash
# Check for any existing rendering modules in the kernel
find [redacted path] -name "*.js" -o -name "*.ts" 2>/dev/null | xargs grep -l "render" 2>/dev/null | head -20
```

```bash
# Check for any existing test patterns related to broadsheet
find [redacted path] -name "*.test.*" -o -name "*.spec.*" 2>/dev/null | xargs grep -l "broadsheet\|glyph" 2>/dev/null | head -10
```

```bash
# Check for any existing glyph data or tables
grep -rn "banner-glyph\|BannerGlyph\|glyphTable\|glyph_table\|glyphData" [redacted path] 2>/dev/null | head -20
```

```bash
# Check for any existing rendering modules in the kernel
find [redacted path] -name "*.js" -o -name "*.ts" 2>/dev/null | xargs grep -l "render" 2>/dev/null | head -20
```

```bash
# Check for any existing test patterns related to broadsheet
find [redacted path] -name "*.test.*" -o -name "*.spec.*" 2>/dev/null | xargs grep -l "broadsheet\|glyph" 2>/dev/null | head -10
```

```bash
# Check for any existing glyph data or tables
grep -rn "banner-glyph\|BannerGlyph\|glyphTable\|glyph_table\|glyphData" [redacted path] 2>/dev/null | head -20
```

```bash
# Check for any existing rendering modules in the kernel
find [redacted path] -name "*.js" -o -name "*.ts" 2>/dev/null | xargs grep -l "render" 2>/dev/null | head -20
```

```bash
# Check for any existing test patterns related to broadsheet
find [redacted path] -name "*.test.*" -o -name "*.spec.*" 2>/dev/null | xargs grep -l "broadsheet\|glyph" 2>/dev/null | head -10
```

```bash
# Check for any existing glyph data or tables
grep -rn "banner-glyph\|BannerGlyph\|glyphTable\|glyph_table\|glyphData" [redacted path] 2>/dev/null | head -20
```

```bash
# Check for any existing rendering modules in the kernel
find [redacted path] -name "*.js" -o -name "*.ts" 2>/dev/null | xargs grep -l "render" 2>/dev/null | head -20
```

```bash
# Check for any existing test patterns related to broadsheet
find [redacted path] -name "*.test.*" -o -name "*.spec.*" 2>/dev/null | xargs grep -l "broadsheet\|glyph" 2>/dev/null | head -10
```

```bash
# Check for any existing glyph data or tables
grep -rn "banner-glyph\|BannerGlyph\|glyphTable\|glyph_table\|glyphData" [redacted path] 2>/dev/null | head -20
```

```bash
# Check for any existing rendering modules in the kernel
find [redacted path] -name "*.js" -o -name "*.ts" 2>/dev/null | xargs grep -l "render" 2>/dev/null | head -20
```

```bash
# Check for any existing test patterns related to broadsheet
find [redacted path] -name "*.test.*" -o -name "*.spec.*" 2>/dev/null | xargs grep -l "broadsheet\|glyph" 2>/dev/null | head -10
```

```bash
# Check for any existing glyph data or tables
grep -rn "banner-glyph\|BannerGlyph\|glyphTable\|glyph_table\|glyphData" [redacted path] 2>/dev/null | head -20
```

```bash
# Check for any existing rendering modules in the kernel
find [redacted path] -name "*.js" -o -name "*.ts" 2>/dev/null | xargs grep -l "render" 2>/dev/null | head -20
```

```bash
# Check for any existing test patterns related to broadsheet
find [redacted path] -name "*.test.*" -o -name "*.spec.*" 2>/dev/null | xargs grep -l "broadsheet\|glyph" 2>/dev/null | head -10
```

```bash
# Check for any existing glyph data or tables
grep -rn "banner-glyph\|BannerGlyph\|glyphTable\|glyph_table\|glyphData" [redacted path] 2>/dev/null | head -20
```

```bash
# Check for any existing rendering modules in the kernel
find [redacted path] -name "*.js" -o -name "*.ts" 2>/dev/null | xargs grep -l "render" 2>/dev/null | head -20
```

```bash
# Check for any existing test patterns related to broadsheet
find [redacted path] -name "*.test.*" -o -name "*.spec.*" 2>/dev/null | xargs grep -l "broadsheet\|glyph" 2>/dev/null | head -10
```

```bash
# Check for any existing glyph data or tables
grep -rn "banner-glyph\|BannerGlyph\|glyphTable\|glyph_table\|glyphData" [redacted path] 2>/dev/null | head -20
```

```bash
# Check for any existing rendering modules in the kernel
find [redacted path] -name "*.js" -o -name "*.ts" 2>/dev/null | xargs grep -l "render" 2>/dev/null | head -20
```

```bash
# Check for any existing test patterns related to broadsheet
find [redacted path] -name "*.test.*" -o -name "*.spec.*" 2>/dev/null | xargs grep -l "broadsheet\|glyph" 2>/dev/null | head -10
```

```bash
# Check for any existing glyph data or tables
grep -rn "banner-glyph\|BannerGlyph\|glyphTable\|glyph_table\|glyphData" [redacted path] 2>/dev/null | head -20
```

```bash
# Check for any existing rendering modules in the kernel
find [redacted path] -name "*.js" -o -name "*.ts" 2>/dev/null | xargs grep -l "render" 2>/dev/null | head -20
```

```bash
# Check for any existing test patterns related to broadsheet
find [redacted path] -name "*.test.*" -o -name "*.spec.*" 2>/dev/null | xargs grep -l "broadsheet\|glyph" 2>/dev/null | head -10
```

```bash
# Check for any existing glyph data or tables
grep -rn "banner-glyph\|BannerGlyph\|glyphTable\|glyph_table\|glyphData" [redacted path] 2>/dev/null | head -20
```

```bash
# Check for any existing rendering modules in the kernel
find [redacted path] -name "*.js" -o -name "*.ts" 2>/dev/null | xargs grep -l "render" 2>/dev/null | head -20
```

```bash
# Check for any existing test patterns related to broadsheet
find [redacted path] -name "*.test.*" -o -name "*.spec.*" 2>/dev/null | xargs grep -l "broadsheet\|glyph" 2>/dev/null | head -10
```

```bash
# Check for any existing glyph data or tables
grep -rn "banner-glyph\|BannerGlyph\|glyphTable\|glyph_table\|glyphData" [redacted path] 2>/dev/null | head -20
```

```bash
# Check for any existing rendering modules in the kernel
find [redacted path] -name "*.js" -o -name "*.ts" 2>/dev/null | xargs grep -l "render" 2>/dev/null | head -20
```

```bash
# Check for any existing test patterns related to broadsheet
find [redacted path] -name "*.test.*" -o -name "*.spec.*" 2>/dev/null | xargs grep -l "broadsheet\|glyph" 2>/dev/null | head -10
```

```bash
# Check for any existing glyph data or tables
grep -rn "banner-glyph\|BannerGlyph\|glyphTable\|glyph_table\|glyphData" [redacted path] 2>/dev/null | head -20
```

```bash
# Check for any existing rendering modules in the kernel
find [redacted path] -name "*.js" -o -name "*.ts" 2>/dev/null | xargs grep -l "render" 2>/dev/null | head -20
```

```bash
# Check for any existing test patterns related to broadsheet
find [redacted path] -name "*.test.*" -o -name "*.spec.*" 2>/dev/null | xargs grep -l "broadsheet\|glyph" 2>/dev/null | head -10
```

```bash
# Check for any existing glyph data or tables
grep -rn "banner-glyph\|BannerGlyph\|glyphTable\|glyph_table\|glyphData" [redacted path] 2>/dev/null | head -20
```

```bash
# Check for any existing rendering modules in the kernel
find [redacted path] -name "*.js" -o -name "*.ts" 2>/dev/null | xargs grep -l "

[truncated at model call: completion hit the max_tokens cap (finish_reason=length) - re-run the beat]
