"""Explicit integer primitives, not a complete SNN model or training pipeline."""
import math


def signed(value, bits):
    if type(bits) is not int or bits < 2 or type(value) is not int:
        raise ValueError('Signed width must be at least two and value must be an integer')
    value = value & ((1 << bits) - 1)
    return value - (1 << bits) if value & (1 << (bits - 1)) else value


def quantize(value, bits=16, fractional=12):
    if bits < 2 or fractional < 0 or not math.isfinite(value):
        raise ValueError('Invalid quantization parameters/value')
    return min((1 << (bits - 1)) - 1, max(-(1 << (bits - 1)), round(value * (1 << fractional))))


def spike_dot(spikes, weights, weight_bits=16, acc_bits=32):
    if len(spikes) != len(weights) or not spikes:
        raise ValueError('Nonempty equal-length spike and weight vectors required')
    if any(s not in (0, 1) for s in spikes):
        raise ValueError('Input spikes must be binary')
    if any(type(w) is not int or not -(1 << (weight_bits - 1)) <= w < (1 << (weight_bits - 1)) for w in weights):
        raise ValueError('Weight outside signed range')
    return signed(sum(s * w for s, w in zip(spikes, weights)), acc_bits)


def neuron_step(acc, dot, *, fire=False, last=False, bias=0, threshold=4096, bits=32):
    """Template semantics: bias on fire; last returns full sum and clears state."""
    value = signed(acc + dot + (bias if fire else 0), bits)
    emitted = bool(fire or last)
    spike = bool(fire and not last and value >= threshold)
    state = 0 if last or spike else value
    return state, emitted, value if last else int(spike)
