#!/bin/bash
set -e

CONFIG_FILE="./config.yaml"
VENV_PATH="./venv"

# Helper: simple YAML parser
function yget() {
  grep "^$1:" "$CONFIG_FILE" | awk '{print $2}' | tr -d '"'
}

# Load config
STREAM_URL=$(yget stream_url)
TMP_FILE=$(yget tmp_file)
RECORD_DURATION=$(yget record_duration)
LOOP=$(yget loop)
SLEEP_INTERVAL=$(yget sleep_interval)

mkdir -p "$(dirname "$TMP_FILE")"
mkdir -p "$(yget output_dir)"

run_once() {
  TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
  TMP_SEGMENT="${TMP_FILE%.wav}_${TIMESTAMP}.wav"

  echo "🎧 Capturing $STREAM_URL for $RECORD_DURATION seconds..."
  ffmpeg -nostdin -y -hide_banner -loglevel info \
      -i "$STREAM_URL" \
      -t "$RECORD_DURATION" \
      -vn -acodec pcm_s16le -ar 44100 -ac 2 \
      "$TMP_SEGMENT"

  if [ -f "$TMP_SEGMENT" ]; then
      echo "✅ Recorded segment: $TMP_SEGMENT"
  else
      echo "❌ ERROR: Recording failed for $TMP_SEGMENT"
      return
  fi

  # Start Python processing in background and remove temp file after completion
  (
    echo "🔊 Processing $TMP_SEGMENT..."
    "$VENV_PATH/bin/python" split_on_silence.py "$TMP_SEGMENT" "$CONFIG_FILE"
    echo "🧹 Cleaning up temp file $TMP_SEGMENT"
    rm -f "$TMP_SEGMENT"
  ) &

}

if [ "$LOOP" == "true" ]; then
  echo "🔁 Continuous mode enabled. Starting loop..."
  while true; do
    run_once
    echo "⏸ Sleeping $SLEEP_INTERVAL seconds before next capture..."
    sleep "$SLEEP_INTERVAL"
  done
else
  echo "▶ Running single capture..."
  run_once
fi

# Wait for all background Python processes to finish
wait
echo "✅ All processing complete."

