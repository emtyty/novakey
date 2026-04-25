#!/bin/bash
# NovaKey demo recorder.
# Prereqs: NovaKey running & enabled, ffmpeg installed (brew install ffmpeg),
# Accessibility permission granted to Terminal/iTerm for System Events.

set -e
cd "$(dirname "$0")"

OUT_MOV="novakey-demo.mov"
OUT_GIF="novakey-demo.gif"
DURATION=18   # seconds

echo "Opening TextEdit..."
osascript <<'EOF'
tell application "TextEdit"
    activate
    if (count of documents) = 0 then
        make new document
    end if
    set bounds of front window to {200, 150, 1000, 600}
end tell
delay 1
EOF

echo "Starting screen recording for ${DURATION}s..."
# Record the TextEdit window area. Adjust -i "1:none" if you have multiple displays.
ffmpeg -y -f avfoundation -framerate 30 -i "1:none" -t $DURATION \
    -vf "crop=800:450:200:150" -c:v h264 "$OUT_MOV" &
FFPID=$!
sleep 2  # give ffmpeg time to initialize

echo "Typing demo..."
osascript <<'EOF'
tell application "System Events"
    tell application "TextEdit" to activate
    delay 0.5

    -- Phrase 1: "xin chào" via Telex: xin chaof
    keystroke "xin chaof "
    delay 1.2

    -- Phrase 2: "Tiếng Việt" via Telex: Tieengs Vieetj
    keystroke "Tieengs Vieetj"
    delay 1.2
    keystroke return

    -- Phrase 3: "Cảm ơn bạn" via Telex: Carm own banj
    keystroke "Carm own banj"
    delay 1.2
    keystroke return

    -- Phrase 4: "đây là NovaKey" via Telex: dday laf NovaKey
    keystroke "dday laf NovaKey"
    delay 1.2
end tell
EOF

wait $FFPID
echo "Converting to GIF..."
ffmpeg -y -i "$OUT_MOV" -vf "fps=15,scale=720:-1:flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse" \
    -loop 0 "$OUT_GIF"

echo "Done: $(pwd)/$OUT_GIF"
