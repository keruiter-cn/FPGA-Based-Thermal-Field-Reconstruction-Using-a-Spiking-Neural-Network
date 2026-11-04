"""Immutable facts and request identity; no GUI or model-service dependency."""
import json
from dataclasses import dataclass


@dataclass(frozen=True)
class FrameContext:
    batch_id: str
    frame_id: str
    sample_id: str
    metrics_json: str

    @classmethod
    def snapshot(cls, batch_id, frame_id, sample_id, metrics):
        if not batch_id or not frame_id or not sample_id:
            raise ValueError('Explicit batch, frame and sample identities are required')
        return cls(str(batch_id), str(frame_id), str(sample_id),
                   json.dumps(metrics, ensure_ascii=False, sort_keys=True, allow_nan=False))

    @property
    def key(self):
        return self.batch_id, self.frame_id

    def metrics(self):
        return json.loads(self.metrics_json)

    def attach_answer(self, answer):
        return {'batch_id': self.batch_id, 'frame_id': self.frame_id,
                'sample_id': self.sample_id, 'metrics': self.metrics(), 'answer': str(answer),
                'identity_source': 'caller_supplied_not_board_verified'}
