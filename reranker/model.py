"""Tiny context/subtoken and candidate/byte CNN with a listwise scoring MLP."""
import torch
from torch import nn
from features import NUM_FEATURES


class Ranker(nn.Module):
    def __init__(self, width=32):
        super().__init__()
        self.context_embedding = nn.Embedding(4096, width, padding_idx=0)
        self.candidate_embedding = nn.Embedding(257, width, padding_idx=0)
        self.context_conv = nn.Conv1d(width, width, 3, padding=1)
        self.candidate_conv = nn.Conv1d(width, width, 3, padding=1)
        self.mlp = nn.Sequential(nn.Linear(width * 2 + NUM_FEATURES, 64), nn.ReLU(), nn.Linear(64, 1))

    def forward(self, context_ids, candidate_ids, features):
        context = torch.relu(self.context_conv(self.context_embedding(context_ids).transpose(1, 2))).amax(2)
        candidate = torch.relu(self.candidate_conv(self.candidate_embedding(candidate_ids).transpose(1, 2))).amax(2)
        return self.mlp(torch.cat((context.expand(candidate.shape[0], -1), candidate, features), 1)).squeeze(1)
