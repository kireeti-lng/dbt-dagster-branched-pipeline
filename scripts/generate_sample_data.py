"""
Generate raw sample event data for the multi-tenant gaming platform.

Two games, deliberately different schemas:
  - Game A (RPG):    player_id (int), username, level, xp, event_time
  - Game B (Racing): user_id (str), display_name, rank, score, timestamp

Design choices that make downstream work meaningful:
  - Players RECUR across events (so dedup / merge / "latest state" has meaning).
  - Events are spread over several days (so the incremental watermark has range).
  - We intentionally emit a few DUPLICATE event rows so dedup logic is exercised.
  - Output is newline-delimited JSON (JSONL), one file per game, mirroring how a
    landing zone / object store would hold raw extracts.

Run:  python scripts/generate_sample_data.py
"""

import json
import random
from datetime import datetime, timedelta, timezone
from pathlib import Path

RAW_DIR = Path(__file__).resolve().parents[1] / "data" / "raw"
RAW_DIR.mkdir(parents=True, exist_ok=True)

random.seed(42)  # deterministic output so runs are reproducible

START = datetime(2025, 1, 1, 8, 0, 0, tzinfo=timezone.utc)


def iso(dt: datetime) -> str:
    """Return an ISO-8601 string with a trailing Z, as game servers emit."""
    return dt.strftime("%Y-%m-%dT%H:%M:%SZ")


def gen_game_a(n_players: int = 15, n_events: int = 60) -> list[dict]:
    """RPG game. Integer player ids. Progress measured by level, value by xp."""
    usernames = [f"rpg_hero_{i:03d}" for i in range(1, n_players + 1)]
    rows = []
    for e in range(n_events):
        pid = random.randint(1, n_players)
        # progress grows over time; xp loosely tracks level
        level = random.randint(1, 60)
        ts = START + timedelta(minutes=e * 37 + random.randint(0, 20))
        rows.append(
            {
                "player_id": 1000 + pid,
                "username": usernames[pid - 1],
                "level": level,
                "xp": level * random.randint(1500, 2200),
                "event_time": iso(ts),
            }
        )
    # Inject 3 exact-duplicate rows to exercise dedup downstream
    rows.extend(random.sample(rows, 3))
    return rows


def gen_game_b(n_players: int = 12, n_events: int = 58) -> list[dict]:
    """Racing game. String user ids. Progress measured by rank, value by score."""
    rows = []
    for e in range(n_events):
        pid = random.randint(1, n_players)
        ts = START + timedelta(minutes=e * 41 + random.randint(0, 25))
        rows.append(
            {
                "user_id": f"USR_{pid:03d}",
                "display_name": f"racer_{pid:03d}",
                "rank": random.randint(1, 5000),
                "score": random.randint(2000, 25000),
                "timestamp": iso(ts),
            }
        )
    rows.extend(random.sample(rows, 2))  # 2 duplicates
    return rows


def write_jsonl(rows: list[dict], filename: str) -> None:
    path = RAW_DIR / filename
    with path.open("w") as f:
        for r in rows:
            f.write(json.dumps(r) + "\n")
    print(f"  wrote {len(rows):>3} records -> {path.relative_to(RAW_DIR.parents[1])}")


if __name__ == "__main__":
    print("Generating raw sample data...")
    a = gen_game_a()
    b = gen_game_b()
    write_jsonl(a, "game_a_events.jsonl")
    write_jsonl(b, "game_b_events.jsonl")
    print(f"Done. Game A: {len(a)} rows, Game B: {len(b)} rows.")
