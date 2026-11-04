"""Offline regression of reusable design helpers plus current-project data cases."""
import argparse
import csv
import hashlib
import importlib.util
import json
import struct
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    obj = importlib.util.module_from_spec(spec)
    sys.modules[name] = obj
    spec.loader.exec_module(obj)
    return obj


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path('.'))
    parser.add_argument('--output', type=Path, default=Path('skill/validation/results.json'))
    args = parser.parse_args()
    root = args.root.resolve()
    base = root / 'skill'
    cases = []

    def require(value, message='Unexpected behavior'):
        if not value:
            raise AssertionError(message)

    def rejected(fn):
        try:
            fn()
        except (ValueError, TypeError):
            return
        raise AssertionError('Invalid input accepted')

    def test(name, fn):
        try:
            detail = fn()
            cases.append({'case': name, 'status': 'pass', **({'detail': detail} if isinstance(detail, dict) else {})})
        except Exception as exc:
            cases.append({'case': name, 'status': 'fail', 'error': str(exc) or type(exc).__name__})

    numeric = module('skill_numeric', base / 'algorithm-mapping/scripts/numeric_reference.py')
    control = module('skill_control', base / 'memory-scheduling/scripts/control_words.py')
    transport = module('skill_transport', base / 'udp-integration/scripts/transport_codec.py')
    trace = module('skill_trace', base / 'verification-closure/scripts/trace_scoreboard.py')
    context = module('skill_context', base / 'host-ai/scripts/frame_context.py')
    fields = control.load_schema(base / 'memory-scheduling/assets/layer-fields.json')

    test('signed_complement_boundaries', lambda: require([numeric.signed(v, 16) for v in [0, 32767, 32768, 65535]] == [0,32767,-32768,-1]))
    test('quantization_ties_even_and_saturation', lambda: require([numeric.quantize(v, 4, 0) for v in [.5,1.5,2.5,-1.5,99,-99]] == [0,2,2,-2,7,-8]))
    test('quantization_rejects_nan', lambda: rejected(lambda: numeric.quantize(float('nan'))))
    test('binary_spike_signed_dot', lambda: require(numeric.spike_dot([1,0,1,1],[-32768,32767,4,-3]) == -32767))
    test('binary_spike_rejects_nonbinary', lambda: rejected(lambda: numeric.spike_dot([2],[1])))
    test('integer_reference_rejects_fractional_weight', lambda: rejected(lambda: numeric.spike_dot([1],[1.5])))
    test('neuron_threshold_equal_fires_and_clears', lambda: require(numeric.neuron_step(90,6,fire=True,bias=4,threshold=100) == (0,True,1)))
    test('neuron_last_returns_signed_sum', lambda: require(numeric.neuron_step(-10,-20,last=True) == (0,True,-30)))
    test('neuron_wrap_is_explicit', lambda: require(numeric.neuron_step(127,1,bits=8) == (-128,False,0)))
    test('weight_layout_known_nonrepeating_bytes', lambda: require(transport.reorder_weight_word(bytes(range(64))) == b''.join(bytes(range(i,i+8))[::-1] for i in [32,40,48,56,0,8,16,24])))
    test('weight_layout_roundtrip', lambda: require(transport.reorder_weights(transport.reorder_weights(bytes(range(128)))) == bytes(range(128))))
    test('weight_layout_rejects_partial_word', lambda: rejected(lambda: transport.reorder_weights(b'123')))
    test('input_pair_little_endian', lambda: require(transport.pack_input_words([0x01020304,0x11121314]) == bytes.fromhex('0403020114131211')))
    test('input_pair_rejects_odd_count', lambda: rejected(lambda: transport.pack_input_words([1])))
    test('output_signed_decode_and_layout', lambda: require(transport.decode_output(struct.pack('<4i',0,-12288,12288,-1),2,2) == [[298,296],[300,298-2/12288]]))
    test('output_rejects_incomplete_frame', lambda: rejected(lambda: transport.decode_output(b'123',1,1)))
    test('output_rejects_nonfinite_scaling', lambda: rejected(lambda: transport.decode_output(b'\0'*4,1,1,scale=float('nan'))))
    empty_row = {name:0 for name,_ in fields}
    test('control_width_is_95', lambda: require(sum(w for _,w in fields)==95))
    max_row = {name:(1<<w)-1 for name,w in fields}
    test('control_field_all_ones_roundtrip', lambda: require(control.unpack(control.pack(max_row,fields),fields)==max_row))
    test('control_overflow_rejected', lambda: rejected(lambda: control.pack({**empty_row,'shift':16},fields)))
    test('control_missing_field_rejected', lambda: rejected(lambda: control.pack({},fields)))

    expected = [{'cycle':2,'data':-7,'last':1,'tag':'layer0:t0'}]
    actual = [{**expected[0],'cycle':3}]
    test('scoreboard_cycle_and_transaction_match', lambda: require(trace.compare(expected,actual,1)['status']=='pass'))
    for name, mutation in [('wrong_data',{'data':7}),('wrong_last',{'last':0}),('wrong_identity',{'tag':'other'}),('wrong_latency',{'cycle':4})]:
        test('scoreboard_rejects_'+name, lambda m=mutation: require(trace.compare(expected,[{**actual[0],**m}],1)['status']=='fail'))
    test('scoreboard_rejects_missing_transaction', lambda: require(trace.compare(expected,[],1)['status']=='fail'))
    test('scoreboard_rejects_empty_reference', lambda: require(trace.compare([],[],1)['status']=='fail'))
    test('scoreboard_order_only_is_explicit', lambda: require(trace.compare(expected,[{**actual[0],'cycle':999}])['cycle_check']=='not_requested_order_only'))

    def snapshot_case():
        facts={'mae':1,'hotspot':[2,3]}
        frame=context.FrameContext.snapshot('batchA','frame1','Example7',facts)
        facts['mae']=999;facts['hotspot'][0]=88
        require(frame.metrics()=={'mae':1,'hotspot':[2,3]})
        answer=frame.attach_answer('analysis')
        require(answer['batch_id']=='batchA' and answer['frame_id']=='frame1')
        require(context.FrameContext.snapshot('batchB','frame1','Example7',{}).key!=frame.key)

    test('async_frame_snapshot_and_batch_identity',snapshot_case)
    test('frame_snapshot_rejects_nonfinite_metrics',lambda: rejected(lambda: context.FrameContext.snapshot('b','f','s',{'mae':float('nan')})))

    with tempfile.TemporaryDirectory(prefix='snn-skill-check-') as temporary:
        folder=Path(temporary)
        source=folder/'trace.csv'
        source.write_text('cycle,valid,data,last,tag\n1,0,,0,\n2,1,-7,1,layer0:t0\n',encoding='utf-8')
        test('csv_trace_valid_only_consumption',lambda: require(trace.read_trace(source)==expected))
        invalid=folder/'invalid.csv'
        invalid.write_text('cycle,valid,data,last,tag\n2,1,1,0,a\n1,1,2,0,b\n')
        test('csv_out_of_order_rejected',lambda: rejected(lambda:trace.read_trace(invalid)))
        malformed=folder/'bad.coe'
        malformed.write_text('memory_initialization_radix=2;memory_initialization_vector=2;')
        test('coe_invalid_radix_word_rejected',lambda: rejected(lambda:control.read_coe(malformed,95)))
        decoded=folder/'rows.json'; rebuilt=folder/'rebuilt.coe'

        def coe_project_case():
            path=root/'file/coe/unet/SNNUnet_control_200-200_no_cat.coe'
            words=control.read_coe(path,95)
            require(len(words)==27)
            require([control.pack(control.unpack(w,fields),fields) for w in words]==words)
            tool=base/'memory-scheduling/scripts/control_words.py'
            first=subprocess.run([sys.executable,str(tool),'decode','--coe',str(path),'--output',str(decoded)],capture_output=True)
            second=subprocess.run([sys.executable,str(tool),'encode','--rows',str(decoded),'--output',str(rebuilt)],capture_output=True)
            require(first.returncode==second.returncode==0)
            require(control.read_coe(rebuilt,95)==words)
            return {'actual_project_rows':len(words),'width':95,'scope':'bit-pattern-roundtrip-not-FSM-proof'}

        test('project_27_control_words_and_cli_roundtrip',coe_project_case)

    def weight_project_case():
        original=bytes.fromhex((root/'file/weight/unet_weights.txt').read_text(encoding='ascii'))
        transmitted=bytes.fromhex((root/'file/weight/unet_weights_reverse.txt').read_text(encoding='ascii'))
        require(transport.reorder_weights(original)==transmitted,'Actual weights do not match reorder rule')
        return {'actual_project_weight_words':len(original)//64,'payload_bytes':len(original),
                'scope':'export-layout-equivalence-not-model-or-network-proof'}

    test('project_all_weight_words_match_export_layout',weight_project_case)
    source_files=[
        'snn_top_v3/eth_ddr_test/rtl/pe/pe.v','snn_top_v3/eth_ddr_test/rtl/pe/pec.v',
        'snn_top_v3/eth_ddr_test/rtl/pe/pp_wgt_buf.v','snn_top_v3/eth_ddr_test/rtl/ilc/ilc.v',
        'snn_top_v3/eth_ddr_test/rtl/fms/fms.v','snn_top_v3/eth_ddr_test/rtl/ddr/new/ddr_rwc.sv',
        'pc_python/pre_process/reverse_data.py','pc_python/socket/local_ai_client.py',
        'file/coe/unet/SNNUnet_control_200-200_no_cat.coe']
    evidence={p:hashlib.sha256((root/p).read_bytes()).hexdigest() for p in source_files}
    passed=sum(c['status']=='pass' for c in cases)
    report={'status':'pass' if passed==len(cases) else 'fail','passed':passed,'total':len(cases),'cases':cases,
            'source_commit':subprocess.check_output(['git','-C',str(root),'rev-parse','HEAD'],text=True).strip(),
            'source_sha256':evidence,'python_version':sys.version.split()[0],
            'checked_at_utc':datetime.now(timezone.utc).isoformat(),
            'limitations':'Offline helper tests and real control/weight files; no original full-network RTL, training, board or AI-service execution.'}
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'status':report['status'],'passed':passed,'total':len(cases),
                      'failures':[c for c in cases if c['status']=='fail']},ensure_ascii=True))
    return 0 if report['status']=='pass' else 1


if __name__=='__main__':
    sys.exit(main())
