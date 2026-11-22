"""The WebSocket protocol, with the mock backend"""

from __future__ import annotations

from conftest import EXPERT_A, PERSONAS, expert_answers
from elicito_app_server.app import PROTOCOL_VERSION


def test_health(mock_client):
    assert mock_client.get("/health").json() == {
        "status": "ok",
        "backend": "mock",
        "case_studies": ["bart"],
        "version": PROTOCOL_VERSION,
    }


def test_websocket_fit_roundtrip(mock_client):
    answers = expert_answers(*EXPERT_A.values(), n=2000)
    with mock_client.websocket_connect("/ws") as ws:
        hello = ws.receive_json()
        assert hello["type"] == "hello" and hello["version"] == PROTOCOL_VERSION
        ws.send_json(
            {"type": "fit", "request_id": "r1", "case_study": "bart", "expert": answers, "replay_n": 12}
        )
        progress = 0
        while True:
            msg = ws.receive_json()
            assert msg["request_id"] == "r1"
            if msg["type"] == "progress":
                progress += 1
                continue
            if msg["type"] == "heartbeat":
                continue
            break
        assert msg["type"] == "result", msg
        assert progress > 0
        assert len(msg["replay"]) == 12
        assert set(msg["priors"]) == {"gammap", "beta"}
        assert set(msg["simulated_quantiles"]) == {"pumps", "omega"}
        assert set(msg["bound_history"]) == {"gammap", "beta"}
        assert len(msg["bound_history"]["beta"]["lower"]) == len(msg["loss_history"])


def test_websocket_reports_bad_answers(mock_client):
    with mock_client.websocket_connect("/ws") as ws:
        ws.receive_json()
        ws.send_json({"type": "fit", "request_id": "r2", "case_study": "bart", "expert": {}})
        msg = ws.receive_json()
        while msg["type"] in ("progress", "heartbeat"):
            msg = ws.receive_json()
        assert msg["type"] == "error"
        assert "missing" in msg["message"]


def test_websocket_panel_roundtrip(mock_client):
    experts = {n: expert_answers(g, b, n=2000) for n, (g, b) in PERSONAS.items()}
    with mock_client.websocket_connect("/ws") as ws:
        ws.receive_json()
        ws.send_json({"type": "fit_panel", "request_id": "p1", "case_study": "bart",
                      "experts": experts, "replay_n": 10})
        msg = ws.receive_json()
        stages = []
        while msg["type"] in ("progress", "heartbeat"):
            if msg["type"] == "progress":
                stages.append((msg["stage"], msg["phase"], msg["phases"], msg["loss"]))
            msg = ws.receive_json()
    assert msg["type"] == "result" and msg["panel"] is True, msg
    # the warm-up comes first, has no loss, and only the real fit reports a loss
    assert stages[0][:3] == ("Warm-up", 1, 2) and stages[-1][:3] == ("Training", 2, 2)
    assert all(loss is None for st, *_, loss in stages if st == "Warm-up")
    assert len(msg["loss_history"]) == sum(st == "Training" for st, *_ in stages)
    hist = msg["expert_bound_history"]["Mila"]["gammap"]
    assert len(hist["lower"]) == len(hist["upper"]) > 1
    assert all(lo <= hi for lo, hi in zip(hist["lower"], hist["upper"]))
    assert set(msg["expert_simulated"]["Sam"]) == {"pumps", "omega"}
    assert set(msg["probs"]) == {"pumps", "omega"}
    assert msg["experts"] == ["Mila", "Sam", "Jonas"]
    assert set(msg["expert_priors"]["Jonas"]) == {"gammap", "beta"}
    pop = msg["population"]["gammap"]
    assert len(pop["edges"]) == len(pop["density"]) + 1 and pop["q05"] < pop["q95"]
    assert len(msg["replay"]) == 10
    assert list(msg["expert_replays"]) == ["Mila", "Sam", "Jonas"]
    assert all(len(r) == 12 for r in msg["expert_replays"].values())


def test_settings_reach_the_result(mock_client):
    answers = expert_answers(*EXPERT_A.values(), n=500)
    with mock_client.websocket_connect("/ws") as ws:
        ws.receive_json()
        ws.send_json({"type": "fit", "request_id": "s1", "case_study": "bart", "expert": answers,
                      "settings": {"epochs": 600, "seed": 7}})
        msg = ws.receive_json()
        while msg["type"] in ("progress", "heartbeat"):
            msg = ws.receive_json()
        assert msg["settings"]["epochs"] == 600 and msg["settings"]["seed"] == 7
        ws.send_json({"type": "fit", "request_id": "s2", "case_study": "bart", "expert": answers,
                      "settings": {"epochs": 1}})
        msg = ws.receive_json()
        while msg["type"] in ("progress", "heartbeat"):
            msg = ws.receive_json()
        assert msg["type"] == "error" and "epochs" in msg["message"]


def test_websocket_independent_panel(mock_client):
    experts = {n: expert_answers(g, b, n=2000) for n, (g, b) in PERSONAS.items()}
    with mock_client.websocket_connect("/ws") as ws:
        ws.receive_json()
        ws.send_json({"type": "fit_panel", "request_id": "p2", "case_study": "bart",
                      "experts": experts, "replay_n": 10, "pooling": "independent"})
        msg = ws.receive_json()
        phases = set()
        while msg["type"] in ("progress", "heartbeat"):
            if msg["type"] == "progress":
                phases.add((msg["phase"], msg["phases"]))
            msg = ws.receive_json()
    assert msg["type"] == "result" and msg["panel"] is True, msg
    assert msg["pooling"] == "independent"
    assert phases == {(1, 3), (2, 3), (3, 3)}, "one step per expert"
    assert msg["panel_priors"] == {} and msg["tau"] == {}
    assert set(msg["expert_priors"]) == set(PERSONAS)


def test_unknown_pooling_is_an_error(mock_client):
    experts = {n: expert_answers(g, b, n=500) for n, (g, b) in PERSONAS.items()}
    with mock_client.websocket_connect("/ws") as ws:
        ws.receive_json()
        ws.send_json({"type": "fit_panel", "request_id": "p3", "case_study": "bart",
                      "experts": experts, "pooling": "complete"})
        msg = ws.receive_json()
        while msg["type"] in ("progress", "heartbeat"):
            msg = ws.receive_json()
    assert msg["type"] == "error" and "pooling" in msg["message"]
