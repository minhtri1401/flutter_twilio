#!/usr/bin/env python3
"""Synthesize bundled call tones as 16-bit mono 44.1 kHz WAV, then convert
to .ogg (Android assets, Vorbis via oggenc) and .caf (iOS resources, PCM
via ffmpeg).

Run from repo root:
    python3 tool/generate_tones.py

Requires: oggenc (vorbis-tools) and ffmpeg on PATH.
"""
import math
import os
import struct
import subprocess
import sys
import wave

SAMPLE_RATE = 44100

def synth(freqs, duration_sec, gain=0.4):
    """Sum of sinusoids, returns list of int16 samples."""
    n = int(SAMPLE_RATE * duration_sec)
    out = []
    for i in range(n):
        t = i / SAMPLE_RATE
        s = sum(math.sin(2 * math.pi * f * t) for f in freqs) / max(1, len(freqs))
        # 5 ms linear fade in/out to avoid clicks
        fade = min(1.0, i / (SAMPLE_RATE * 0.005), (n - i) / (SAMPLE_RATE * 0.005))
        out.append(int(max(-1, min(1, s * gain * fade)) * 32767))
    return out

def silence(duration_sec):
    return [0] * int(SAMPLE_RATE * duration_sec)

def write_wav(path, samples):
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        w.writeframes(b''.join(struct.pack('<h', s) for s in samples))

def convert(wav_path, ogg_path, caf_path):
    subprocess.run(
        ['oggenc', '-Q', '-q', '4', '-o', ogg_path, wav_path],
        check=True,
    )
    # IMA4 ADPCM @ 16 kHz mono — small (~8 KB/s) and natively decoded by
    # AVAudioPlayer. Plenty of bandwidth for tones up to 800 Hz.
    subprocess.run(
        ['ffmpeg', '-y', '-loglevel', 'error', '-i', wav_path,
         '-ar', '16000', '-ac', '1', '-c:a', 'adpcm_ima_qt', caf_path],
        check=True,
    )

def main():
    repo_root = os.path.abspath(os.path.dirname(os.path.dirname(__file__)))
    tmp = os.path.join(repo_root, 'tool', '_tones_tmp')
    os.makedirs(tmp, exist_ok=True)

    android_dir = os.path.join(repo_root, 'android', 'src', 'main', 'assets', 'flutter_twilio')
    ios_dir = os.path.join(repo_root, 'ios', 'Resources')
    os.makedirs(android_dir, exist_ok=True)
    os.makedirs(ios_dir, exist_ok=True)

    # NA ringback: 440+480 Hz, 2s on, 4s off, total 6s loop unit
    ring_on = synth([440, 480], 2.0)
    ring_off = silence(4.0)
    ringback = ring_on + ring_off

    connect = synth([800], 0.15)
    disconnect = synth([600], 0.12) + silence(0.05) + synth([400], 0.12)

    for name, samples in (
        ('ringback_na', ringback),
        ('connect_tone', connect),
        ('disconnect_tone', disconnect),
    ):
        wav = os.path.join(tmp, f'{name}.wav')
        write_wav(wav, samples)
        convert(wav, os.path.join(android_dir, f'{name}.ogg'),
                     os.path.join(ios_dir, f'{name}.caf'))

    print('Tones generated.')

if __name__ == '__main__':
    sys.exit(main())
