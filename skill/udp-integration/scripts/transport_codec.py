"""Pure application-payload transforms; no socket, board reset or network calls."""
import argparse
import hashlib
import json
import math
import struct
import sys
from pathlib import Path


def reorder_weight_word(word):
    if len(word) != 64:
        raise ValueError('A weight word must be 512 bits / 64 bytes')
    order = (4, 5, 6, 7, 0, 1, 2, 3)
    return b''.join(word[lane * 8:(lane + 1) * 8][::-1] for lane in order)


def reorder_weights(data):
    if not data or len(data) % 64:
        raise ValueError('Weight payload must contain complete 64-byte words')
    return b''.join(reorder_weight_word(data[i:i + 64]) for i in range(0, len(data), 64))


def pack_input_words(words):
    if not words or len(words) % 2 or any(type(w) is not int or not 0 <= w < 2**32 for w in words):
        raise ValueError('Input packing requires an even nonempty sequence of uint32 words')
    return b''.join(struct.pack('<II', words[i], words[i + 1]) for i in range(0, len(words), 2))


def decode_output(payload, height=200, width=200, timestep=3, divisor=4096, scale=2, offset=298):
    if not all(math.isfinite(v) for v in (timestep, divisor, scale, offset)) or min(height, width, timestep, divisor) <= 0 or len(payload) != height * width * 4:
        raise ValueError('Invalid dimensions/scaling or incomplete frame payload')
    values = [word[0] / timestep / divisor * scale + offset for word in struct.iter_unpack('<i', payload)]
    return [values[i * width:(i + 1) * width] for i in range(height)]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--original', type=Path, required=True)
    parser.add_argument('--transmitted', type=Path, required=True)
    args = parser.parse_args()
    try:
        original = bytes.fromhex(args.original.read_text(encoding='ascii'))
        transmitted = bytes.fromhex(args.transmitted.read_text(encoding='ascii'))
        expected = reorder_weights(original)
        ok = expected == transmitted
        print(json.dumps({'status': 'pass' if ok else 'fail', 'weight_words': len(original) // 64,
                          'payload_bytes': len(original), 'actual_bytes': len(transmitted),
                          'original_payload_sha256': hashlib.sha256(original).hexdigest(),
                          'transmitted_payload_sha256': hashlib.sha256(transmitted).hexdigest(),
                          'scope': 'layout_equivalence_not_network_or_model_accuracy'}))
        return 0 if ok else 1
    except (OSError, ValueError, TypeError) as exc:
        print(json.dumps({'status': 'error', 'error': str(exc)}))
        return 2


if __name__ == '__main__':
    sys.exit(main())
