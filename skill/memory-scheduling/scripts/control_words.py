"""Strict MSB-first control-ROM codec, independently usable with a new schema."""
import argparse
import json
import re
import sys
from pathlib import Path

SCHEMA = Path(__file__).resolve().parents[1] / 'assets/layer-fields.json'


def load_schema(path=SCHEMA):
    schema = json.loads(Path(path).read_text(encoding='utf-8'))
    fields = schema['fields']
    if schema['order'] != 'msb-first' or not fields or len({n for n, _ in fields}) != len(fields):
        raise ValueError('Invalid field order or duplicate/empty fields')
    if any(type(w) is not int or w <= 0 for _, w in fields):
        raise ValueError('Field widths must be positive integers')
    return fields


def pack(row, fields):
    if set(row) != {name for name, _ in fields}:
        raise ValueError('Control row must contain exactly the schema fields')
    word = 0
    for name, width in fields:
        value = row[name]
        if type(value) is not int or not 0 <= value < (1 << width):
            raise ValueError(f'Field {name} outside unsigned {width}-bit range: {value}')
        word = (word << width) | value
    return word


def unpack(word, fields):
    if type(word) is not int or not 0 <= word < (1 << sum(w for _, w in fields)):
        raise ValueError('Control word outside schema width')
    row = {}
    for name, width in reversed(fields):
        row[name] = word & ((1 << width) - 1)
        word >>= width
    return {name: row[name] for name, _ in fields}


def read_coe(path, width):
    text = Path(path).read_text(encoding='utf-8-sig')
    match = re.fullmatch(r'\s*memory_initialization_radix\s*=\s*(2|10|16)\s*;\s*memory_initialization_vector\s*=\s*(.*?)\s*;\s*', text, re.I | re.S)
    if not match:
        raise ValueError('Unsupported/incomplete COE')
    tokens = [s.strip() for s in match[2].split(',')]
    if not tokens or any(not s for s in tokens):
        raise ValueError('Empty COE data/word')
    radix = int(match[1])
    alphabet = {2: '[01]+', 10: '[0-9]+', 16: '[0-9a-fA-F]+'}[radix]
    if any(not re.fullmatch(alphabet, s) for s in tokens):
        raise ValueError('COE word not valid for declared radix')
    words = [int(s, radix) for s in tokens]
    if any(w >= 1 << width for w in words) or (radix == 2 and any(len(s) != width for s in tokens)):
        raise ValueError('COE word width mismatch')
    return words


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('operation', choices=['encode', 'decode'])
    parser.add_argument('--schema', type=Path, default=SCHEMA)
    parser.add_argument('--coe', type=Path)
    parser.add_argument('--rows', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    try:
        fields = load_schema(args.schema)
        width = sum(w for _, w in fields)
        if args.operation == 'decode':
            if not args.coe:
                raise ValueError('decode requires --coe')
            words = read_coe(args.coe, width)
            result = {'width': width, 'rows': [unpack(w, fields) for w in words]}
            text = json.dumps(result, ensure_ascii=False, indent=2) + '\n'
        else:
            if not args.rows:
                raise ValueError('encode requires --rows')
            data = json.loads(args.rows.read_text(encoding='utf-8'))
            rows = data['rows'] if isinstance(data, dict) else data
            if not isinstance(rows, list) or not rows:
                raise ValueError('Nonempty row list required')
            words = [pack(row, fields) for row in rows]
            text = 'memory_initialization_radix=2;\nmemory_initialization_vector=\n' + ',\n'.join(format(w, f'0{width}b') for w in words) + ';\n'
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(text, encoding='utf-8')
        print(json.dumps({'status': 'pass', 'words': len(words), 'width': width}))
        return 0
    except (OSError, ValueError, KeyError, TypeError) as exc:
        print(json.dumps({'status': 'error', 'error': str(exc)}, ensure_ascii=True))
        return 2


if __name__ == '__main__':
    sys.exit(main())
