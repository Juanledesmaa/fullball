#!/usr/bin/env bash
# Fetch the 32 WC nation-tag flags from lipis/flag-icons (MIT, public-domain art)
# and scaffold one asset-catalog imageset per tag, preserving the SVG vector data.
# Idempotent: re-run to refresh. No API key, no api-football, fully offline after.
set -euo pipefail

ASSETS="$(cd "$(dirname "$0")/.." && pwd)/Fullball/Resources/Assets.xcassets/Flags"
BASE="https://cdn.jsdelivr.net/gh/lipis/flag-icons@7/flags/4x3"

# Fullball nation tag  ->  flag-icons file code (ISO 3166-1 alpha-2, + GB subdivisions)
declare -a MAP=(
  "ARG:ar" "AUS:au" "BEL:be" "BRA:br" "CAM:cm" "CAN:ca" "COS:cr" "CRO:hr"
  "DEN:dk" "ECU:ec" "ENG:gb-eng" "ESP:es" "FRA:fr" "GER:de" "GHA:gh" "IRN:ir"
  "JPN:jp" "KOR:kr" "KSA:sa" "MAR:ma" "MEX:mx" "NED:nl" "POL:pl" "POR:pt"
  "QAT:qa" "SEN:sn" "SER:rs" "SUI:ch" "TUN:tn" "URU:uy" "USA:us" "WAL:gb-wls"
)

mkdir -p "$ASSETS"
# Top-level Contents.json so Xcode treats Flags/ as a namespaced group.
cat > "$ASSETS/Contents.json" <<'EOF'
{ "info" : { "author" : "xcode", "version" : 1 } }
EOF

for pair in "${MAP[@]}"; do
  tag="${pair%%:*}"; code="${pair##*:}"
  set="$ASSETS/flag_${tag}.imageset"
  mkdir -p "$set"
  echo "↓ $tag ($code)"
  curl -fsSL "$BASE/${code}.svg" -o "$set/flag_${tag}.svg"
  cat > "$set/Contents.json" <<EOF
{
  "images" : [ { "filename" : "flag_${tag}.svg", "idiom" : "universal" } ],
  "info" : { "author" : "xcode", "version" : 1 },
  "properties" : { "preserves-vector-representation" : true }
}
EOF
done
echo "✓ ${#MAP[@]} flags written to $ASSETS"
