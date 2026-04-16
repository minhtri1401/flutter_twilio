#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fvm dart run pigeon --input pigeons/voice_api.dart
