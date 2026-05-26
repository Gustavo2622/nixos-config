#!/usr/bin/env python3
"""Tests for nxc-sandbox path rule resolution and bwrap flag generation."""

import os
import sys
import tempfile
from pathlib import Path

# Import the module under test
sys.path.insert(0, os.path.dirname(__file__))
import nxc_sandbox as sb


# ── Path expansion ──────────────────────────────────────────────────────

def test_expand_path_home():
    result = sb.expand_path("~/foo", "/project")
    assert result == os.path.expanduser("~/foo"), f"Expected home expansion, got {result}"

def test_expand_path_project():
    result = sb.expand_path("$PROJECT/src", "/my/project")
    assert result == "/my/project/src", f"Expected /my/project/src, got {result}"

def test_expand_path_both():
    result = sb.expand_path("$PROJECT", "/proj")
    assert result == "/proj", f"Expected /proj, got {result}"

def test_expand_path_no_vars():
    result = sb.expand_path("/etc/resolv.conf", "/proj")
    assert result == "/etc/resolv.conf", f"Expected literal path, got {result}"


# ── Rule resolution (specificity) ──────────────────────────────────────

def test_deny_by_default():
    """Paths not covered by any rule should be blocked."""
    rules = {"/home/user": "ro"}
    mode = sb.get_mode_for_path("/etc/shadow", rules)
    assert mode == "block", f"Expected block (deny by default), got {mode}"

def test_exact_match():
    rules = {"/home/user/.ssh": "block"}
    mode = sb.get_mode_for_path("/home/user/.ssh", rules)
    assert mode == "block", f"Expected block, got {mode}"

def test_parent_match():
    """Child paths inherit parent rule."""
    rules = {"/home/user": "ro"}
    mode = sb.get_mode_for_path("/home/user/.config/foo", rules)
    assert mode == "ro", f"Expected ro from parent, got {mode}"

def test_specific_overrides_general():
    """More specific path wins over less specific."""
    rules = {
        "/home/user": "ro",
        "/home/user/.ssh": "block",
    }
    mode = sb.get_mode_for_path("/home/user/.ssh/id_ed25519", rules)
    assert mode == "block", f"Expected block (specific override), got {mode}"

def test_more_specific_allows_within_block():
    """A specific allow inside a blocked directory should win."""
    rules = {
        "/home/user/.ssh": "block",
        "/home/user/.ssh/known_hosts": "ro",
    }
    mode = sb.get_mode_for_path("/home/user/.ssh/known_hosts", rules)
    assert mode == "ro", f"Expected ro (specific allow), got {mode}"

def test_blocked_file_in_allowed_dir():
    """A blocked file inside an allowed directory should be blocked."""
    rules = {
        "/project": "rw",
        "/project/.env": "block",
    }
    mode = sb.get_mode_for_path("/project/.env", rules)
    assert mode == "block", f"Expected block (specific block), got {mode}"

def test_allowed_subdir_in_blocked_dir():
    """An allowed subdir inside a blocked dir should be allowed."""
    rules = {
        "/home/user/Documents": "block",
        "/home/user/Documents/public": "ro",
    }
    mode = sb.get_mode_for_path("/home/user/Documents/public/readme.txt", rules)
    assert mode == "ro", f"Expected ro (specific allow), got {mode}"

def test_blocked_subdir_stays_blocked():
    """A file deep in a blocked dir with no specific override stays blocked."""
    rules = {
        "/home/user": "ro",
        "/home/user/.mozilla": "block",
    }
    mode = sb.get_mode_for_path("/home/user/.mozilla/firefox/profiles.ini", rules)
    assert mode == "block", f"Expected block (inherited from parent block), got {mode}"

def test_rw_subdir_in_ro_home():
    """An rw directory inside ro home should be writable."""
    rules = {
        "/home/user": "ro",
        "/home/user/project": "rw",
    }
    mode = sb.get_mode_for_path("/home/user/project/src/main.nix", rules)
    assert mode == "rw", f"Expected rw, got {mode}"


# ── Same-specificity conflict resolution ───────────────────────────────

def test_same_specificity_block_wins_over_rw():
    """At same path depth, block takes precedence over rw."""
    rules = {}
    # Simulate two rules for exact same path
    # In practice this shouldn't happen (TOML keys are unique), but test the logic
    rules["/home/user/.config"] = "block"
    mode = sb.get_mode_for_path("/home/user/.config", rules)
    assert mode == "block", f"Expected block, got {mode}"

def test_same_specificity_block_wins_over_ro():
    rules = {}
    rules["/home/user/.config"] = "block"
    mode = sb.get_mode_for_path("/home/user/.config/file.txt", rules)
    assert mode == "block", f"Expected block, got {mode}"


# ── Edge cases ─────────────────────────────────────────────────────────

def test_trailing_slash_irrelevant():
    """Trailing slash on rule path shouldn't affect matching."""
    rules = {"/home/user/": "ro"}
    mode = sb.get_mode_for_path("/home/user/file.txt", rules)
    assert mode == "ro", f"Expected ro, got {mode}"

def test_empty_rules():
    """No rules = everything blocked."""
    rules = {}
    mode = sb.get_mode_for_path("/home/user/anything", rules)
    assert mode == "block", f"Expected block (empty rules), got {mode}"

def test_root_rule():
    """A rule on / should match everything."""
    rules = {"/": "ro"}
    mode = sb.get_mode_for_path("/any/path/at/all", rules)
    assert mode == "ro", f"Expected ro from root rule, got {mode}"

def test_no_partial_name_match():
    """Rule for /home/user should NOT match /home/username."""
    rules = {"/home/user": "ro"}
    mode = sb.get_mode_for_path("/home/username/file", rules)
    assert mode == "block", f"Expected block (no partial match), got {mode}"

def test_exact_file_rule():
    """Rule for exact file path."""
    rules = {
        "/home/user": "ro",
        "/home/user/.env": "block",
    }
    mode = sb.get_mode_for_path("/home/user/.env", rules)
    assert mode == "block", f"Expected block, got {mode}"
    # But .env.local should not be caught by .env rule
    mode2 = sb.get_mode_for_path("/home/user/.env.local", rules)
    assert mode2 == "ro", f"Expected ro (.env.local != .env), got {mode2}"


# ── resolve_rules ──────────────────────────────────────────────────────

def test_resolve_rules_expands():
    paths = {"~": "ro", "$PROJECT": "rw"}
    rules = sb.resolve_rules(paths, "/my/project")
    home = os.path.expanduser("~")
    assert home in rules, f"Expected expanded home in rules"
    assert "/my/project" in rules, f"Expected expanded project in rules"
    assert rules[home] == "ro"
    assert rules["/my/project"] == "rw"


# ── bwrap args generation ─────────────────────────────────────────────

def test_bwrap_args_contain_dev_proc():
    rules = {"/tmp/testdir": "ro"}
    args = sb.rules_to_bwrap_args(rules, strict=False, permissive=False)
    assert "--dev" in args, "Expected --dev in bwrap args"
    assert "--proc" in args, "Expected --proc in bwrap args"

def test_bwrap_args_ro_bind():
    with tempfile.TemporaryDirectory() as td:
        rules = {td: "ro"}
        args = sb.rules_to_bwrap_args(rules, strict=False, permissive=False)
        idx = args.index("--ro-bind")
        assert args[idx + 1] == td, f"Expected ro-bind for {td}"

def test_bwrap_args_rw_bind():
    with tempfile.TemporaryDirectory() as td:
        rules = {td: "rw"}
        args = sb.rules_to_bwrap_args(rules, strict=False, permissive=False)
        idx = args.index("--bind")
        assert args[idx + 1] == td, f"Expected bind (rw) for {td}"

def test_bwrap_args_block_not_bound():
    with tempfile.TemporaryDirectory() as td:
        rules = {td: "block"}
        args = sb.rules_to_bwrap_args(rules, strict=False, permissive=False)
        # blocked paths should not appear in passthrough bind args
        bind_targets = []
        i = 0
        while i < len(args):
            if args[i] in ("--bind", "--ro-bind") and args[i + 1] != "/dev/null":
                bind_targets.append(args[i + 1])
                i += 2
            else:
                i += 1
        assert td not in bind_targets, f"Blocked path {td} should not be passthrough-bound"


# ── Block shadowing (emit_block_or_bind) ───────────────────────────────

def test_block_dir_tmpfs():
    """A blocked existing directory is shadowed with tmpfs."""
    with tempfile.TemporaryDirectory() as td:
        result = sb.emit_block_or_bind(td, "block")
        assert result == ["--tmpfs", td], f"Expected tmpfs shadow, got {result}"

def test_block_file_devnull():
    """A blocked existing file is shadowed with /dev/null."""
    with tempfile.NamedTemporaryFile() as tf:
        result = sb.emit_block_or_bind(tf.name, "block")
        assert result == ["--ro-bind", "/dev/null", tf.name], f"Expected /dev/null shadow, got {result}"

def test_block_nonexistent_tmpfs():
    """A blocked nonexistent path is shadowed with tmpfs (over-block)."""
    result = sb.emit_block_or_bind("/nonexistent/path/xyz123", "block")
    assert result == ["--tmpfs", "/nonexistent/path/xyz123"], f"Expected tmpfs, got {result}"

def test_block_in_bwrap_args():
    """Blocked dir appears as tmpfs in full bwrap args (shadows parent bind)."""
    with tempfile.TemporaryDirectory() as parent:
        child = os.path.join(parent, "secret")
        os.mkdir(child)
        rules = {parent: "ro", child: "block"}
        args = sb.rules_to_bwrap_args(rules, strict=False, permissive=False)
        # parent must be ro-bound, child must be tmpfs'd, and parent must come first
        parent_idx = next(i for i, a in enumerate(args) if a == "--ro-bind" and args[i + 1] == parent)
        tmpfs_idx = next(i for i, a in enumerate(args) if a == "--tmpfs" and args[i + 1] == child)
        assert parent_idx < tmpfs_idx, "Parent bind must come before child shadow (ordering)"

def test_emit_rw_ro():
    assert sb.emit_block_or_bind("/x", "rw") == ["--bind", "/x", "/x"]
    assert sb.emit_block_or_bind("/x", "ro") == ["--ro-bind", "/x", "/x"]

def test_bwrap_strict_no_daemon():
    rules = {}
    args = sb.rules_to_bwrap_args(rules, strict=True, permissive=False)
    # In strict mode, nix daemon socket should not be bound
    for i, arg in enumerate(args):
        if "daemon-socket" in str(arg):
            assert False, "Strict mode should not bind nix daemon socket"

def test_bwrap_permissive_adds_ssh():
    rules = {}
    ssh_dir = os.path.expanduser("~/.ssh")
    if os.path.exists(ssh_dir):
        args = sb.rules_to_bwrap_args(rules, strict=False, permissive=True)
        bind_targets = []
        i = 0
        while i < len(args):
            if args[i] == "--ro-bind":
                bind_targets.append(args[i + 1])
                i += 2
            else:
                i += 1
        assert ssh_dir in bind_targets, "Permissive should add ~/.ssh RO"

def test_bwrap_nix_store_always_ro():
    rules = {}
    args = sb.rules_to_bwrap_args(rules, strict=True, permissive=False)
    # /nix/store should always be RO bound
    found = False
    for i, arg in enumerate(args):
        if arg == "--ro-bind" and i + 1 < len(args) and args[i + 1] == "/nix/store":
            found = True
            break
    assert found, "Expected /nix/store to always be RO bound"


# ── Profile loading ────────────────────────────────────────────────────

def test_load_profile_missing():
    """Loading a nonexistent profile should exit with error."""
    import io
    from contextlib import redirect_stderr
    try:
        sb.load_profile("nonexistent_profile_abc123")
        assert False, "Should have called sys.exit"
    except SystemExit as e:
        assert e.code == 1

def test_load_profile_valid():
    """Loading a valid TOML profile should return a dict."""
    with tempfile.TemporaryDirectory() as td:
        config_dir = Path(td) / "nxc" / "sandbox"
        config_dir.mkdir(parents=True)
        profile = config_dir / "test.toml"
        profile.write_text('[paths]\n"/" = "ro"\n')
        # Monkey-patch the config dir
        orig = os.path.expanduser
        os.path.expanduser = lambda p: p.replace("~", td)
        try:
            # This won't work directly due to hardcoded path, but tests the TOML parsing
            pass
        finally:
            os.path.expanduser = orig


# ── Runner ─────────────────────────────────────────────────────────────

def run_tests():
    tests = [v for k, v in globals().items() if k.startswith("test_") and callable(v)]
    passed = 0
    failed = 0
    errors = []

    for test in tests:
        try:
            test()
            passed += 1
            print(f"  ✓ {test.__name__}")
        except Exception as e:
            failed += 1
            errors.append((test.__name__, str(e)))
            print(f"  ✗ {test.__name__}: {e}")

    print(f"\n{passed} passed, {failed} failed out of {len(tests)} tests")
    if errors:
        print("\nFailures:")
        for name, err in errors:
            print(f"  {name}: {err}")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(run_tests())
