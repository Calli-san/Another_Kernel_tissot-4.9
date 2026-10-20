#!/usr/bin/env python3
"""Check the final DTB, not just an overlay that might be overridden later."""
import re
import struct
import sys
from pathlib import Path


def read_dtb(path):
    data = Path(path).read_bytes()
    header = struct.unpack_from('>10I', data)
    magic, total, off_struct, off_strings = header[:4]
    if magic != 0xd00dfeed or total > len(data):
        raise ValueError('invalid or truncated flattened device tree')
    strings = data[off_strings:off_strings + header[8]]
    pos = off_struct
    stack, nodes = [], {}
    while pos < off_struct + header[9]:
        token, = struct.unpack_from('>I', data, pos)
        pos += 4
        if token == 1:
            end = data.index(b'\0', pos)
            stack.append(data[pos:end].decode())
            pos = (end + 4) & ~3
            nodes['/' + '/'.join(stack[1:])] = {}
        elif token == 2:
            stack.pop()
        elif token == 3:
            length, offset = struct.unpack_from('>II', data, pos)
            pos += 8
            end = strings.index(b'\0', offset)
            name = strings[offset:end].decode()
            nodes['/' + '/'.join(stack[1:])][name] = data[pos:pos + length]
            pos = (pos + length + 3) & ~3
        elif token == 4:
            pass
        elif token == 9:
            return nodes
        else:
            raise ValueError(f'invalid FDT token {token}')
    raise ValueError('missing FDT end token')


def ints(node, prop):
    raw = node[prop]
    assert len(raw) % 4 == 0, prop
    return list(struct.unpack('>' + 'I' * (len(raw) // 4), raw))


def unique(nodes, suffix):
    matches = [v for p, v in nodes.items() if p.endswith(suffix)]
    assert len(matches) == 1, (suffix, len(matches))
    return matches[0]


def check(path):
    nodes = read_dtb(path)
    cpu = unique(nodes, '/qcom,cpu-clock-8953@b116000')
    plan = ints(cpu, 'qcom,speed2-bin-v0-cl')
    expected = [0, 652800000, 1036800000, 1401600000, 1689600000,
                1804800000, 1958400000, 2016000000, 2150400000,
                2208000000, 2304000000]
    assert plan[::2] == expected, plan
    assert plan[1::2] == [0, 1, 2, 3, 4, 5, 6, 7, 7, 7, 7], plan
    assert expected[-1] % 19200000 == 0
    cci = ints(cpu, 'qcom,speed2-bin-v0-cci')
    assert cci[::2] == [f * 2 // 5 for f in expected], cci
    assert cci[1::2] == plan[1::2], cci
    for bin_id in (0, 6, 7):
        assert max(ints(cpu, f'qcom,speed{bin_id}-bin-v0-cl')[::2]) <= 2208000000
    freq = unique(nodes, '/qcom,msm-cpufreq')
    assert ints(freq, 'qcom,cpufreq-table') == [f // 1000 for f in expected[1:]]
    cpr = next(n for n in nodes.values() if n.get('regulator-name') == b'apc_corner\0')
    bins = ints(cpr, 'qcom,cpr-speed-bin-corners')
    assert bins == [9, 0, 7, 0, 0, 0, 7, 9], bins
    count = sum(bins)
    for prop in ('qcom,cpr-voltage-ceiling', 'qcom,cpr-voltage-floor',
                 'qcom,corner-frequencies', 'qcom,mem-acc-voltage'):
        assert len(ints(cpr, prop)) == count, prop
    assert max(ints(cpr, 'qcom,cpr-voltage-ceiling')) == 1065000
    for prop in ('qcom,cpr-open-loop-voltage-adjustment',
                 'qcom,cpr-closed-loop-voltage-adjustment'):
        values = ints(cpr, prop)
        assert len(values) == count, prop
        assert values == [25000 if i == 15 else 0 for i in range(count)], prop
    anchors = ints(cpr, 'qcom,corner-frequencies')
    assert anchors[9:16] == expected[1:8], anchors
    gpu = unique(nodes, '/qcom,kgsl-3d0@1c00000')
    assert ints(gpu, 'qcom,initial-pwrlevel') == [4]
    assert ints(gpu, 'qcom,idle-timeout') == [80]
    levels = [ints(unique(nodes, f'/qcom,kgsl-3d0@1c00000/qcom,gpu-pwrlevels/qcom,gpu-pwrlevel@{i}'),
                   'qcom,gpu-freq')[0] for i in range(8)]
    assert levels == [680000000, 560000000, 510000000, 400000000,
                      320000000, 216000000, 133300000, 19200000], levels
    gfx = unique(nodes, '/qcom,gcc-gfx@1800000')
    voltage_map = ints(gfx, 'qcom,gfxfreq-corner')
    assert voltage_map[-4:] == [650000000, 7, 680000000, 7]
    root = Path(__file__).resolve().parents[1]
    clock = (root / 'drivers/clk/msm/clock-gcc-8953.c').read_text()
    assert re.search(r'F_MM\(\s*680000000,\s*1360000000,\s*gpll3,\s*1,', clock)
    cpu_clock = (root / 'drivers/clk/msm/clock-cpu-8953.c').read_text()
    assert '.max_rate = 2304000000UL,' in cpu_clock
    print('OC-Test compiled DTB checks passed: CPU2304/bin2, CCI921.6, bounded CPR +25mV, GPU680/TURBO.')


if __name__ == '__main__':
    check(sys.argv[1])
