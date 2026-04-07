from __future__ import annotations

import contextlib
import os
import shutil
import subprocess
import tempfile
import textwrap
import unittest
from dataclasses import dataclass
from pathlib import Path


HOOK_ID = "rip0005-gitflow"
PROTECTED_BRANCHES = ("main", "master", "develop")


def _command_text(cmd: list[str]) -> str:
    return " ".join(cmd)


def _result_message(proc: subprocess.CompletedProcess[str]) -> str:
    return textwrap.dedent(
        f"""\
        command: {_command_text(proc.args)}
        returncode: {proc.returncode}
        stdout:
        {proc.stdout}
        stderr:
        {proc.stderr}
        """
    )


def run(
    cmd: list[str],
    *,
    cwd: Path,
    env: dict[str, str] | None = None,
    check: bool = True,
) -> subprocess.CompletedProcess[str]:
    merged_env = os.environ.copy()
    if env:
        merged_env.update(env)

    proc = subprocess.run(
        cmd,
        cwd=cwd,
        env=merged_env,
        text=True,
        capture_output=True,
        check=False,
    )

    if check and proc.returncode != 0:
        raise AssertionError(_result_message(proc))

    return proc


def git(
    cwd: Path,
    *args: str,
    env: dict[str, str] | None = None,
    check: bool = True,
) -> subprocess.CompletedProcess[str]:
    return run(["git", *args], cwd=cwd, env=env, check=check)


def pre_commit(
    cwd: Path,
    *args: str,
    env: dict[str, str] | None = None,
    check: bool = True,
) -> subprocess.CompletedProcess[str]:
    return run(["pre-commit", *args], cwd=cwd, env=env, check=check)


def write_file(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def append_file(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as handle:
        handle.write(content)


def configure_user(repo: Path) -> None:
    git(repo, "config", "user.name", "Test User")
    git(repo, "config", "user.email", "test@example.com")


@dataclass
class Scenario:
    scratch: Path
    origin: Path
    work: Path
    base_branch: str
    pre_commit_home: Path

    @property
    def hook_env(self) -> dict[str, str]:
        return {"PRE_COMMIT_HOME": str(self.pre_commit_home)}


class PreCommitIntegrationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        if shutil.which("git") is None:
            raise unittest.SkipTest("git is required for integration tests")
        if shutil.which("pre-commit") is None:
            raise unittest.SkipTest("pre-commit is required for integration tests")

        cls.repo_root = Path(__file__).resolve().parents[1]
        cls._hook_repo_tmp = tempfile.TemporaryDirectory()
        cls.hook_repo = Path(cls._hook_repo_tmp.name) / "hook-repo"
        shutil.copytree(
            cls.repo_root,
            cls.hook_repo,
            ignore=shutil.ignore_patterns(".git", ".venv", "__pycache__", ".pytest_cache"),
        )

        git(cls.hook_repo.parent, "init", "-q", str(cls.hook_repo))
        configure_user(cls.hook_repo)
        git(cls.hook_repo, "add", ".")
        git(cls.hook_repo, "commit", "-q", "-m", "Test snapshot")
        cls.hook_rev = git(cls.hook_repo, "rev-parse", "HEAD").stdout.strip()

    @classmethod
    def tearDownClass(cls) -> None:
        cls._hook_repo_tmp.cleanup()

    @contextlib.contextmanager
    def make_scenario(self, base_branch: str) -> Scenario:
        with tempfile.TemporaryDirectory() as tmpdir:
            scratch = Path(tmpdir)
            origin = scratch / "origin.git"
            work = scratch / "work"
            pre_commit_home = scratch / "pre-commit-home"

            git(scratch, "init", "--bare", "-q", str(origin))
            git(scratch, "init", "-q", f"--initial-branch={base_branch}", str(work))
            configure_user(work)
            git(work, "remote", "add", "origin", str(origin))

            write_file(work / "README.md", "# test repo\n")
            git(work, "add", "README.md")
            git(work, "commit", "-q", "-m", "Initial commit")

            write_file(
                work / ".pre-commit-config.yaml",
                textwrap.dedent(
                    f"""\
                    repos:
                      - repo: {self.hook_repo}
                        rev: {self.hook_rev}
                        hooks:
                          - id: {HOOK_ID}
                    """
                ),
            )
            git(work, "add", ".pre-commit-config.yaml")
            git(work, "commit", "-q", "-m", "Add pre-commit config")
            git(work, "push", "-q", "-u", "origin", base_branch)
            git(origin, "symbolic-ref", "HEAD", f"refs/heads/{base_branch}")

            pre_commit(
                work,
                "install",
                "--install-hooks",
                "--hook-type",
                "pre-push",
                "--hook-type",
                "commit-msg",
                env={"PRE_COMMIT_HOME": str(pre_commit_home)},
            )

            yield Scenario(
                scratch=scratch,
                origin=origin,
                work=work,
                base_branch=base_branch,
                pre_commit_home=pre_commit_home,
            )

    def clone_peer(self, scenario: Scenario, name: str = "peer") -> Path:
        peer = scenario.scratch / name
        git(scenario.scratch, "clone", "-q", str(scenario.origin), str(peer))
        configure_user(peer)
        git(peer, "checkout", "-q", scenario.base_branch)
        return peer

    def create_feature_commit(
        self,
        scenario: Scenario,
        *,
        branch_name: str = "feature/test",
        filename: str = "feature.txt",
        content: str = "feature change\n",
        message: str = "Feature change",
    ) -> str:
        git(scenario.work, "checkout", "-q", "-b", branch_name)
        write_file(scenario.work / filename, content)
        git(scenario.work, "add", filename)
        git(
            scenario.work,
            "commit",
            "-m",
            message,
            env=scenario.hook_env,
        )
        return branch_name

    def advance_base_branch_in_peer(
        self,
        scenario: Scenario,
        *,
        filename: str = "base.txt",
        content: str = "base branch change\n",
        message: str = "Advance base",
    ) -> Path:
        peer = self.clone_peer(scenario)
        write_file(peer / filename, content)
        git(peer, "add", filename)
        git(peer, "commit", "-q", "-m", message)
        git(peer, "push", "-q", "origin", scenario.base_branch)
        return peer

    def assert_failed(self, proc: subprocess.CompletedProcess[str], *snippets: str) -> None:
        self.assertNotEqual(proc.returncode, 0, _result_message(proc))
        combined = f"{proc.stdout}\n{proc.stderr}"
        for snippet in snippets:
            self.assertIn(snippet, combined, _result_message(proc))

    def test_direct_commits_to_protected_branches_are_rejected(self) -> None:
        for branch in PROTECTED_BRANCHES:
            with self.subTest(branch=branch):
                with self.make_scenario(branch) as scenario:
                    write_file(scenario.work / "protected.txt", f"{branch}\n")
                    git(scenario.work, "add", "protected.txt")

                    proc = git(
                        scenario.work,
                        "commit",
                        "-m",
                        "Direct commit on protected branch",
                        env=scenario.hook_env,
                        check=False,
                    )

                    self.assert_failed(
                        proc,
                        f"direct commits to '{branch}' are not allowed",
                    )

    def test_stale_branches_cannot_be_merged_into_protected_branches(self) -> None:
        for branch in PROTECTED_BRANCHES:
            with self.subTest(branch=branch):
                with self.make_scenario(branch) as scenario:
                    feature_branch = self.create_feature_commit(
                        scenario,
                        content=f"feature for {branch}\n",
                        message=f"Feature for {branch}",
                    )
                    self.advance_base_branch_in_peer(
                        scenario,
                        filename=f"{branch}-base.txt",
                        content=f"base advance for {branch}\n",
                        message=f"Advance {branch}",
                    )

                    git(scenario.work, "checkout", "-q", branch)
                    git(scenario.work, "pull", "-q", "--ff-only", "origin", branch)

                    proc = git(
                        scenario.work,
                        "merge",
                        "--no-ff",
                        "--no-edit",
                        feature_branch,
                        env=scenario.hook_env,
                        check=False,
                    )

                    self.assert_failed(
                        proc,
                        f"is behind 'origin/{branch}'",
                        f"Rebase onto 'origin/{branch}' before continuing.",
                    )

    def test_fast_forward_updates_to_protected_branches_are_rejected(self) -> None:
        for branch in PROTECTED_BRANCHES:
            with self.subTest(branch=branch):
                with self.make_scenario(branch) as scenario:
                    feature_branch = self.create_feature_commit(
                        scenario,
                        content=f"fast-forward for {branch}\n",
                        message=f"Fast-forward for {branch}",
                    )

                    git(scenario.work, "checkout", "-q", branch)
                    git(scenario.work, "merge", "-q", feature_branch)

                    proc = git(
                        scenario.work,
                        "push",
                        "origin",
                        branch,
                        env=scenario.hook_env,
                        check=False,
                    )

                    self.assert_failed(
                        proc,
                        f"non-merge update detected on '{branch}'",
                        "Use 'git merge --no-ff <source-branch>'",
                    )

    def test_feature_branch_push_is_rejected_when_origin_base_advances(self) -> None:
        with self.make_scenario("main") as scenario:
            feature_branch = self.create_feature_commit(
                scenario,
                content="feature branch not rebased\n",
                message="Feature branch work",
            )
            self.advance_base_branch_in_peer(
                scenario,
                filename="main-base.txt",
                content="origin main advanced\n",
                message="Advance main in peer",
            )

            proc = git(
                scenario.work,
                "push",
                "-u",
                "origin",
                feature_branch,
                env=scenario.hook_env,
                check=False,
            )

            self.assert_failed(
                proc,
                "is behind 'origin/main'",
                "Rebase onto 'origin/main' before continuing.",
            )

    def test_no_ff_merge_can_be_pushed_when_branch_is_rebased(self) -> None:
        with self.make_scenario("main") as scenario:
            feature_branch = self.create_feature_commit(
                scenario,
                content="ready for no-ff merge\n",
                message="Ready for merge",
            )

            git(scenario.work, "checkout", "-q", "main")
            merge_proc = git(
                scenario.work,
                "merge",
                "--no-ff",
                "--no-edit",
                feature_branch,
                env=scenario.hook_env,
            )
            self.assertEqual(merge_proc.returncode, 0, _result_message(merge_proc))

            push_proc = git(
                scenario.work,
                "push",
                "origin",
                "main",
                env=scenario.hook_env,
            )
            self.assertEqual(push_proc.returncode, 0, _result_message(push_proc))

    def test_feature_branch_push_succeeds_after_rebasing_onto_origin_base(self) -> None:
        with self.make_scenario("main") as scenario:
            feature_branch = self.create_feature_commit(
                scenario,
                content="feature branch before rebase\n",
                message="Feature before rebase",
            )
            self.advance_base_branch_in_peer(
                scenario,
                filename="origin-main.txt",
                content="origin advanced before feature push\n",
                message="Advance main before feature push",
            )

            git(scenario.work, "fetch", "-q", "origin")
            git(scenario.work, "rebase", "origin/main")

            push_proc = git(
                scenario.work,
                "push",
                "-u",
                "origin",
                feature_branch,
                env=scenario.hook_env,
            )
            self.assertEqual(push_proc.returncode, 0, _result_message(push_proc))


if __name__ == "__main__":
    unittest.main(verbosity=2)
