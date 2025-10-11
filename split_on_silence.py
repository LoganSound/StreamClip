#!/usr/bin/env python3
import os
import sys
import yaml
from pydub import AudioSegment, silence
from datetime import datetime, timedelta

def load_config(config_path="config.yaml"):
    """Load configuration from YAML file."""
    with open(config_path, "r") as f:
        return yaml.safe_load(f)

def main():
    if len(sys.argv) < 2:
        print("Usage: split_on_silence.py input.wav [config.yaml]")
        sys.exit(1)

    input_file = sys.argv[1]
    config_path = sys.argv[2] if len(sys.argv) > 2 else "config.yaml"

    cfg = load_config(config_path)
    output_dir = cfg.get("output_dir", "./recordings")
    os.makedirs(output_dir, exist_ok=True)

    prefix = cfg.get("file_prefix", "segment")
    min_silence = cfg.get("min_silence_len", 1500)
    silence_thresh = cfg.get("silence_thresh", -35)
    keep_silence = cfg.get("keep_silence", 300)
    min_non_silence_dBFS = cfg.get("min_non_silence_dBFS", -50)

    # Load audio
    print(f"🎚 Loading {input_file}")
    sound = AudioSegment.from_file(input_file, format="wav")

    dynamic_thresh = sound.dBFS + silence_thresh
    print(f"🔍 Detecting silence: min={min_silence}ms, thresh={dynamic_thresh:.1f} dBFS")

    # Split on silence
    chunks = silence.split_on_silence(
        sound,
        min_silence_len=min_silence,
        silence_thresh=dynamic_thresh,
        keep_silence=keep_silence
    )

    print(f"🎧 Found {len(chunks)} segments.")

    # Compute start offset of each chunk
    current_offset_ms = 0
    exported = 0
    recording_start = datetime.now()  # timestamp of start of original file

    for i, chunk in enumerate(chunks):
        # Skip completely silent chunks
        if chunk.dBFS < min_non_silence_dBFS:
            print(f"⚠️ Skipping silent chunk {i+1} (dBFS={chunk.dBFS:.1f})")
            current_offset_ms += len(chunk)
            continue

        # Timestamp offset by how far into the file this chunk occurs
        segment_time = recording_start + timedelta(milliseconds=current_offset_ms)
        timestamp_str = segment_time.strftime("%Y%m%d_%H%M%S")

        out_path = os.path.join(output_dir, f"{prefix}_{timestamp_str}_{i+1:03}.wav")
        chunk.export(out_path, format="wav")
        print(f"💾 Saved {out_path}")
        exported += 1

        current_offset_ms += len(chunk)

    print(f"✅ Done splitting audio. Exported {exported} segments.\n")

if __name__ == "__main__":
    main()

