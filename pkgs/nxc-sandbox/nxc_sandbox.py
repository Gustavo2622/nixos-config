#!/usr/bin/env python3
"""nxc sandbox — bubblewrap-based sandboxing with TOML path rules.

Usage:
    nxc-sandbox --profile <name> [--strict] [--permissive] -- <command> [args...]
    nxc-sandbox --profile <name> --show  # show resolved bwrap flags

Path rules (in profile TOML):
    [paths]
    "~" = "ro"           # home readable
    "~/.ssh" = "block"   # blocked (more specific wins)
    "$PROJECT" = "rw"    # project dir writable

Resolution: deny by default, most specific path wins, block > ro > rw at same depth.
"""

import argparse
import os
import subprocess
import sys
from pathlib import Path

try:
    import tomllib
except ImportError:
    import tomli as tomllib


def expand_path(p: str, project: str) -> str:
    """Expand ~ and $PROJECT in path strings."""
    p = p.replace("$PROJECT", project)
    return os.path.expanduser(p)


def resolve_rules(paths: dict[str, str], project: str) -> dict[str, str]:
    """Expand all paths and return sorted by specificity (most specific first)."""
    expanded = {}
    for pattern, mode in paths.items():
        ep = expand_path(pattern, project)
        expanded[ep] = mode
    return expanded


def get_mode_for_path(target: str, rules: dict[str, str]) -> str:
    """Find the most specific rule matching target path. Returns 'block' if no match (deny by default)."""
    best_match = ""
    best_mode = "block"  # deny by default

    for rule_path, mode in rules.items():
        # Check if target is under rule_path (or is rule_path itself)
        if target == rule_path or target.startswith(rule_path.rstrip("/") + "/"):
            if len(rule_path) > len(best_match):
                best_match = rule_path
                best_mode = mode
            elif len(rule_path) == len(best_match):
                # Same specificity: block > ro > rw
                priority = {"block": 0, "ro": 1, "rw": 2}
                if priority.get(mode, 3) < priority.get(best_mode, 3):
                    best_mode = mode

    return best_mode


def emit_block_or_bind(path: str, mode: str) -> list[str]:
    """Emit bwrap args for a single path according to its mode.

    Modes:
      "rw"    — bind read-write:  ["--bind", path, path]
      "ro"    — bind read-only:   ["--ro-bind", path, path]
      "block" — shadow/hide the path so a parent bind doesn't expose it.

    The "block" case is the security-critical one. A blocked path may be a
    directory (e.g. ~/.ssh) or a file (e.g. $PROJECT/.env), and may or may
    not exist on the host. The goal: after this returns, the path must be
    inaccessible inside the sandbox even though its parent is bind-mounted.

    bwrap primitives available:
      ["--tmpfs", path]              mount empty tmpfs (dirs only; path must exist in sandbox)
      ["--ro-bind", "/dev/null", p]  shadow a file with an empty null device
      ["--dir", path]                create an empty dir (no host passthrough)

    Block strategy (err toward over-blocking — safe failure for a security tool):
      - directory       → --tmpfs (empty tmpfs shadows the real dir)
      - file            → --ro-bind /dev/null (appears as empty, unreadable)
      - nonexistent     → --tmpfs (bwrap creates the mountpoint; blocks even
                          if the app tries to create the path later)
    """
    if mode == "rw":
        return ["--bind", path, path]
    if mode == "ro":
        return ["--ro-bind", path, path]
    if mode == "block":
        if os.path.isfile(path):
            return ["--ro-bind", "/dev/null", path]
        # directory or nonexistent — shadow with empty tmpfs
        return ["--tmpfs", path]
    raise ValueError(f"unknown mode: {mode}")


def rules_to_bwrap_args(rules: dict[str, str], strict: bool, permissive: bool) -> list[str]:
    """Convert resolved path rules to bwrap command-line arguments."""
    args = []

    # Always needed
    args += ["--dev", "/dev"]
    args += ["--proc", "/proc"]
    args += ["--tmpfs", "/tmp"]

    # Sort by path depth (shallow first) so parent binds are applied before
    # child shadows/re-allows. bwrap processes mounts in order — a later mount
    # on a sub-path shadows an earlier mount on its parent.
    def depth(item):
        return item[0].rstrip("/").count("/")

    for path, mode in sorted(rules.items(), key=depth):
        if mode == "rw":
            if os.path.exists(path):
                args += emit_block_or_bind(path, "rw")
        elif mode == "ro":
            if os.path.exists(path):
                args += emit_block_or_bind(path, "ro")
        elif mode == "block":
            args += emit_block_or_bind(path, "block")

    # System essentials (always RO)
    for p in ["/etc/resolv.conf", "/etc/ssl", "/etc/hosts", "/run/current-system"]:
        if os.path.exists(p):
            args += ["--ro-bind", p, p]

    # Nix store (always RO)
    args += ["--ro-bind", "/nix/store", "/nix/store"]

    # Nix daemon socket (mode B, unless --strict)
    if not strict:
        socket = "/nix/var/nix/daemon-socket"
        if os.path.exists(socket):
            args += ["--ro-bind", socket, socket]
        # Also need nix config
        nix_conf = "/etc/nix"
        if os.path.exists(nix_conf):
            args += ["--ro-bind", nix_conf, nix_conf]

    # Permissive: add ~/.ssh RO
    if permissive:
        ssh_dir = os.path.expanduser("~/.ssh")
        if os.path.exists(ssh_dir):
            args += ["--ro-bind", ssh_dir, ssh_dir]

    # Namespace isolation
    args += ["--unshare-ipc", "--unshare-pid", "--unshare-uts"]
    # Keep network (needed for git, APIs)
    # --unshare-net intentionally omitted

    return args


def load_profile(profile_name: str) -> dict:
    """Load a sandbox profile from config directory."""
    config_dir = Path(os.path.expanduser("~/.config/nxc/sandbox"))
    profile_path = config_dir / f"{profile_name}.toml"

    if not profile_path.exists():
        print(f"Error: sandbox profile '{profile_name}' not found at {profile_path}", file=sys.stderr)
        print(f"Available profiles:", file=sys.stderr)
        if config_dir.exists():
            for f in config_dir.glob("*.toml"):
                print(f"  {f.stem}", file=sys.stderr)
        sys.exit(1)

    with open(profile_path, "rb") as f:
        return tomllib.load(f)


def detect_project() -> str:
    """Find the project root (git root or cwd)."""
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True, text=True, check=True
        )
        return result.stdout.strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return os.getcwd()


def build_env(strict: bool, project: str) -> dict[str, str]:
    """Build environment for the sandbox."""
    env = dict(os.environ)

    if not strict:
        # Mode B: source direnv if available
        try:
            result = subprocess.run(
                ["direnv", "export", "json"],
                capture_output=True, text=True, cwd=project
            )
            if result.returncode == 0 and result.stdout.strip():
                import json
                direnv_env = json.loads(result.stdout)
                env.update(direnv_env)
        except FileNotFoundError:
            pass  # direnv not available, that's fine

    return env


def main():
    parser = argparse.ArgumentParser(
        description="nxc sandbox — bubblewrap-based sandboxing",
        usage="nxc-sandbox --profile <name> [--strict] [--permissive] -- <command> [args...]"
    )
    parser.add_argument("--profile", "-p", required=True, help="Sandbox profile name")
    parser.add_argument("--strict", action="store_true", help="Mode A: pre-eval, no nix daemon")
    parser.add_argument("--permissive", action="store_true", help="Add ~/.ssh RO access")
    parser.add_argument("--show", action="store_true", help="Show resolved bwrap flags, don't run")
    parser.add_argument("command", nargs=argparse.REMAINDER, help="Command to run in sandbox")

    args = parser.parse_args()

    if not args.show and not args.command:
        parser.error("No command specified. Use -- <command> [args...]")

    # Remove leading -- from command
    cmd = args.command
    if cmd and cmd[0] == "--":
        cmd = cmd[1:]

    if not args.show and not cmd:
        parser.error("No command specified after --")

    profile = load_profile(args.profile)
    project = detect_project()
    rules = resolve_rules(profile.get("paths", {}), project)
    bwrap_args = rules_to_bwrap_args(rules, args.strict, args.permissive)

    if args.show:
        print("Project:", project)
        print("Profile:", args.profile)
        print("Mode:", "strict (A)" if args.strict else "live (B)")
        print("Permissive:", args.permissive)
        print()
        print("Resolved rules:")
        for path, mode in sorted(rules.items()):
            exists = "✓" if os.path.exists(path) else "✗"
            print(f"  {exists} {mode:5s}  {path}")
        print()
        print("bwrap command:")
        print("  bwrap", " ".join(bwrap_args), "--", *cmd if cmd else ["<command>"])
        return

    env = build_env(args.strict, project)

    full_cmd = ["bwrap"] + bwrap_args + ["--"] + cmd
    os.execvpe("bwrap", full_cmd, env)


if __name__ == "__main__":
    main()
