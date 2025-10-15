#!/bin/bash
set -e

CONFIG_FILE="./config.yaml"
VENV_PATH="./venv"

# ✅ Virtual environment setup
if [[ ! -d "$VENV_DIR" ]]; then
    echo "⚙️  Creating virtual environment at $VENV_DIR"
    python3 -m venv "$VENV_DIR"
    source "$VENV_DIR/bin/activate"
    pip install --upgrade pip
    pip install -r "$BASE_DIR/requirements.txt"
else
    source "$VENV_DIR/bin/activate"
fi

# Simple YAML parser
function yget() {
  grep "^$1:" "$CONFIG_FILE" | awk '{print $2}' | tr -d '"'
}

STREAM_URL=$(yget stream_url)
TMP_FILE=$(yget tmp_file)
RECORD_DURATION=$(yget record_duration)
LOOP=$(yget loop)
SLEEP_INTERVAL=$(yget sleep_interval)
CLEANUP=$(yget cleanup_temp_files)

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

  # Background Python processing with optional cleanup
  (
    echo "🔊 Processing $TMP_SEGMENT..."
    "$VENV_PATH/bin/python" split_on_silence.py "$TMP_SEGMENT" "$CONFIG_FILE"

    if [ "$CLEANUP" == "true" ]; then
        echo "🧹 Cleaning up temp file $TMP_SEGMENT"
        rm -f "$TMP_SEGMENT"
    else
        echo "ℹ️ Keeping temp file $TMP_SEGMENT"
    fi
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

# Wait for all background processes to finish
wait
echo "✅ All processing complete."
