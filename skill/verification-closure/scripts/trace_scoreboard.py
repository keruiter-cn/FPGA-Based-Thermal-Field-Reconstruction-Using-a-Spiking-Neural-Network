"""Check ordered accepted transactions and optionally their exact cycle latency."""
import argparse
import csv
import json
import sys
from pathlib import Path


def read_trace(path):
    events, previous = [], -1
    with Path(path).open(encoding='utf-8-sig', newline='') as stream:
        reader = csv.DictReader(stream)
        if not {'cycle', 'valid', 'data', 'last', 'tag'}.issubset(reader.fieldnames or []):
            raise ValueError('CSV requires cycle,valid,data,last,tag columns')
        for line, row in enumerate(reader, 2):
            cycle = int(row['cycle'])
            if cycle <= previous or row['valid'] not in ('0', '1') or row['last'] not in ('0', '1'):
                raise ValueError(f'Invalid cycle ordering/valid/last at CSV line {line}')
            previous = cycle
            if row['valid'] == '1':
                try:
                    value = int(row['data'], 0)
                except ValueError:
                    value = int(row['data'], 10)
                events.append({'cycle': cycle, 'data': value, 'last': int(row['last']), 'tag': row['tag']})
    return events


def compare(expected, actual, latency=None):
    if latency is not None and latency < 0:
        raise ValueError('Latency cannot be negative')
    errors = []
    if len(expected) != len(actual):
        errors.append(f'Transaction count: expected {len(expected)}, actual {len(actual)}')
    for index, (e, a) in enumerate(zip(expected, actual)):
        for key in ('data', 'last', 'tag'):
            if e[key] != a[key]:
                errors.append(f'Transaction {index} {key}: {a[key]!r} != {e[key]!r}')
        if latency is not None and a['cycle'] != e['cycle'] + latency:
            errors.append(f'Transaction {index} cycle: {a["cycle"]} != {e["cycle"]} + {latency}')
    if not expected:
        errors.append('Empty golden transaction stream cannot establish correctness')
    return {'status': 'fail' if errors else 'pass', 'expected_transactions': len(expected),
            'actual_transactions': len(actual), 'latency': latency,
            'cycle_check': 'exact' if latency is not None else 'not_requested_order_only',
            'error_count': len(errors), 'errors': errors[:30]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--expected', type=Path, required=True)
    parser.add_argument('--actual', type=Path, required=True)
    parser.add_argument('--latency', type=int)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    try:
        report = compare(read_trace(args.expected), read_trace(args.actual), args.latency)
        code = 0 if report['status'] == 'pass' else 1
    except (OSError, ValueError, TypeError, KeyError, csv.Error) as exc:
        report, code = {'status': 'error', 'error': str(exc)}, 2
    text = json.dumps(report, ensure_ascii=True, indent=2)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(text + '\n', encoding='utf-8')
    print(text)
    return code


if __name__ == '__main__':
    sys.exit(main())
