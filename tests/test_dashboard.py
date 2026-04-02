"""test_dashboard.py — pytest tests for token-diet-dashboard data layer."""
import json
from unittest.mock import patch, MagicMock


# ---------------------------------------------------------------------------
# Cycle 1.3 — collect() structure
# ---------------------------------------------------------------------------

def test_collect_returns_required_keys(dashboard_mod):
    """collect() always returns a dict with rtk, tilth, serena keys."""
    with patch.object(dashboard_mod, "run", return_value=None):
        result = dashboard_mod.collect()
    assert isinstance(result, dict)
    assert "rtk" in result
    assert "tilth" in result
    assert "serena" in result


def test_collect_returns_none_when_tools_absent(dashboard_mod):
    """When no tools respond, all values are None."""
    with patch.object(dashboard_mod, "run", return_value=None):
        result = dashboard_mod.collect()
    assert result["rtk"] is None
    assert result["tilth"] is None
    assert result["serena"] is None


# ---------------------------------------------------------------------------
# rtk_stats
# ---------------------------------------------------------------------------

def test_rtk_stats_parses_json(dashboard_mod):
    """rtk_stats() parses the summary and daily fields from rtk gain output."""
    fake_json = json.dumps({
        "summary": {
            "total_commands": 10,
            "total_input": 5000,
            "total_saved": 3500,
            "avg_savings_pct": 70.0,
            "total_time_ms": 250,
        },
        "daily": [],
    })
    with patch.object(dashboard_mod, "run", return_value=fake_json):
        result = dashboard_mod.rtk_stats()
    assert result is not None
    assert result["summary"]["total_commands"] == 10
    assert result["summary"]["avg_savings_pct"] == 70.0
    assert isinstance(result["daily"], list)


def test_rtk_stats_returns_none_when_rtk_missing(dashboard_mod):
    """rtk_stats() returns None when rtk is not installed."""
    with patch.object(dashboard_mod, "run", return_value=None):
        assert dashboard_mod.rtk_stats() is None


def test_rtk_stats_daily_capped_at_14(dashboard_mod):
    """rtk_stats() only keeps the last 14 days of daily data."""
    daily = [{"date": f"2026-03-{i:02d}", "saved": i * 100} for i in range(1, 30)]
    fake_json = json.dumps({
        "summary": {"total_commands": 1, "total_input": 1, "total_saved": 1,
                    "avg_savings_pct": 1.0, "total_time_ms": 1},
        "daily": daily,
    })
    with patch.object(dashboard_mod, "run", return_value=fake_json):
        result = dashboard_mod.rtk_stats()
    assert len(result["daily"]) == 14


# ---------------------------------------------------------------------------
# tilth_stats
# ---------------------------------------------------------------------------

def test_tilth_stats_returns_version(dashboard_mod, tmp_home):
    """tilth_stats() extracts the version string from 'tilth --version' output."""
    with patch.object(dashboard_mod, "run", return_value="tilth 0.5.7-mock"):
        result = dashboard_mod.tilth_stats()
    assert result is not None
    assert result["version"] == "0.5.7-mock"


def test_tilth_stats_returns_none_when_tilth_missing(dashboard_mod, tmp_home):
    """tilth_stats() returns None when tilth is not installed."""
    with patch.object(dashboard_mod, "run", return_value=None):
        assert dashboard_mod.tilth_stats() is None


# ---------------------------------------------------------------------------
# _registered_hosts
# ---------------------------------------------------------------------------

def test_registered_hosts_empty_when_no_configs(dashboard_mod, tmp_home):
    """_registered_hosts() returns [] when no MCP config files exist."""
    hosts = dashboard_mod._registered_hosts("tilth")
    assert hosts == []


def test_registered_hosts_detects_claude_code(dashboard_mod, tmp_home):
    """_registered_hosts() finds claude-code when tilth is in settings.json."""
    cfg = tmp_home / ".claude" / "settings.json"
    cfg.write_text(json.dumps({"mcpServers": {"tilth": {"command": "tilth"}}}))

    hosts = dashboard_mod._registered_hosts("tilth")
    assert "claude-code" in hosts


def test_registered_hosts_deduplicates(dashboard_mod, tmp_home):
    """_registered_hosts() deduplicates host labels."""
    cfg = tmp_home / ".claude" / "settings.json"
    cfg.write_text(json.dumps({"mcpServers": {"tilth": {}, "tilth-extra": {}}}))

    hosts = dashboard_mod._registered_hosts("tilth")
    assert hosts.count("claude-code") == 1
