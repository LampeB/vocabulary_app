import copy
import json
import os
import unittest
from unittest.mock import patch

import approve_validated_pr as approval


OWNER = "LampeB"
REPOSITORY = f"{OWNER}/vocabulary_app"
PULL = 2
HEAD = "a" * 40
BASE = "b" * 40
OLD = "c" * 40
PULL_PATH = f"/pulls/{PULL}"
REVIEWS_PATH = f"{PULL_PATH}/reviews"
MAIN_PATH = "/git/ref/heads/main"
STATUSES_PATH = f"/commits/{HEAD}/statuses"
CHECKS_PATH = f"/commits/{HEAD}/check-runs?filter=all"
PR_RUN = 2001
PUSH_RUN = 2002
PR_WORKFLOW = ".github/workflows/pr-validation.yml"
PUSH_WORKFLOW = ".github/workflows/test.yml"
WORKFLOW_PATHS = {PR_RUN: PR_WORKFLOW, PUSH_RUN: PUSH_WORKFLOW}


def clean_evidence(review_cycle=1, iterations=(19, 20)):
    return {
        "head_sha": HEAD,
        "base_sha": BASE,
        "review_cycle": review_cycle,
        "reviewers": {
            reviewer: [
                {
                    "cycle": review_cycle,
                    "iteration": iteration,
                    "instance_id": f"{reviewer}:{review_cycle}:{iteration}",
                    "verdict": "PROPRE",
                    "bloquant": 0,
                    "important": 0,
                }
                for iteration in iterations
            ]
            for reviewer in sorted(approval.REVIEWERS)
        },
    }


def evidence_body(payload):
    return f"Deliverable\n\n{approval.EVIDENCE_MARKER}\n{payload}\n-->\n"


def actions_review(head=HEAD, state="APPROVED"):
    return {
        "commit_id": head,
        "state": state,
        "user": {"login": approval.ACTIONS_BOT, "type": "Bot"},
    }


def paged(path, page):
    separator = "&" if "?" in path else "?"
    return f"{path}{separator}per_page=100&page={page}"


class FakeGitHub(approval.GitHub):
    def __init__(self, evidence=None):
        if evidence is None:
            evidence = clean_evidence()
        self.pull = {
            "number": PULL,
            "state": "open",
            "draft": False,
            "head": {"sha": HEAD, "repo": {"full_name": REPOSITORY}},
            "base": {"sha": BASE, "ref": "main", "repo": {"full_name": REPOSITORY}},
            "body": evidence_body(json.dumps(evidence)),
        }
        self.main = {"ref": "refs/heads/main", "object": {"type": "commit", "sha": BASE}}
        self.latest_status = {
            "context": approval.REVIEW_CONTEXT,
            "creator": {"login": OWNER},
            "state": "success",
            "description": approval.evidence_description(evidence),
        }
        self.pr_association = {
            "number": PULL,
            "head": {"sha": HEAD},
            "base": {"sha": BASE, "ref": "main"},
        }
        self.check_runs = []
        for index, name in enumerate(approval.REQUIRED_CHECKS, 1):
            run_id = PUSH_RUN if name == "test" else PR_RUN
            self.check_runs.append({
                "id": index,
                "name": name,
                "app": approval.ACTIONS_APP.copy(),
                "status": "completed",
                "conclusion": "success",
                "head_sha": HEAD,
                "details_url": f"https://github.com/{REPOSITORY}/actions/runs/{run_id}/job/{index}",
                "check_suite": {"id": run_id + 1000},
                "pull_requests": [] if run_id == PUSH_RUN else [copy.deepcopy(self.pr_association)],
            })
        self.responses = {
            MAIN_PATH: [(self.main, False)],
            PULL_PATH: [(self.pull, False)],
            paged(STATUSES_PATH, 1): [([self.latest_status], False)],
            paged(CHECKS_PATH, 1): [({"check_runs": self.check_runs}, False)],
            paged(REVIEWS_PATH, 1): [([], False)],
        }
        self.action_runs = {}
        for run_id, path in WORKFLOW_PATHS.items():
            workflow_id = run_id + 2000
            run = {
                "id": run_id,
                "check_suite_id": run_id + 1000,
                "workflow_id": workflow_id,
                "path": path,
                "event": "push" if run_id == PUSH_RUN else "pull_request",
                "head_sha": HEAD,
                "pull_requests": [] if run_id == PUSH_RUN else [copy.deepcopy(self.pr_association)],
                "display_title": "Push title" if run_id == PUSH_RUN else f"PR #{PULL} {HEAD} against {BASE}",
            }
            self.action_runs[run_id] = run
            self.responses[f"/actions/runs/{run_id}"] = [(run, False)]
            self.responses[f"/actions/workflows/{path.rsplit('/', 1)[1]}"] = [({"id": workflow_id, "path": path}, False)]
        self.requests = []
        self.posts = []
        self.review_response = actions_review()

    def request(self, path, body=None):
        self.requests.append(path)
        if body is not None:
            self.posts.append((path, body))
            return self.review_response, False
        responses = self.responses[path]
        if len(responses) > 1:
            return responses.pop(0)
        return responses[0]


class ApprovalTest(unittest.TestCase):
    def approve(self, api):
        return approval.approve(api, REPOSITORY, OWNER, PULL, HEAD)

    def assert_refused(self, api, message):
        with self.assertRaisesRegex(approval.ApprovalError, message):
            self.approve(api)
        self.assertEqual(api.posts, [])

    def test_approves_exact_head_once(self):
        api = FakeGitHub()
        self.assertTrue(self.approve(api))
        self.assertEqual(len(api.posts), 1)
        path, body = api.posts[0]
        self.assertEqual(path, REVIEWS_PATH)
        self.assertEqual(body["commit_id"], HEAD)
        self.assertEqual(body["event"], "APPROVE")
        self.assertIn(api.latest_status["description"], body["body"])
        self.assertEqual(api.requests[-2:], [PULL_PATH, REVIEWS_PATH])

    def test_approves_consecutive_iterations_one_and_two_of_cycle_two(self):
        api = FakeGitHub(clean_evidence(review_cycle=2, iterations=(1, 2)))
        self.assertTrue(self.approve(api))
        self.assertEqual(len(api.posts), 1)

    def test_wrong_review_returned_by_github_fails(self):
        api = FakeGitHub()
        api.review_response = actions_review(OLD)
        with self.assertRaisesRegex(approval.ApprovalError, "did not confirm"):
            self.approve(api)
        self.assertEqual(len(api.posts), 1)

    def test_deduplicates_only_undismissed_actions_approval_for_head(self):
        cases = (
            (actions_review(), False),
            (actions_review(OLD), True),
            (actions_review(state="DISMISSED"), True),
            ({**actions_review(), "user": {"login": OWNER, "type": "User"}}, True),
        )
        for review, submits in cases:
            with self.subTest(review=review):
                api = FakeGitHub()
                api.responses[paged(REVIEWS_PATH, 1)] = [([actions_review(OLD)], True)]
                api.responses[paged(REVIEWS_PATH, 2)] = [([review], False)]
                self.assertEqual(self.approve(api), submits)
                self.assertEqual(len(api.posts), int(submits))

    def test_rejects_closed_draft_fork_wrong_ref_head_and_base(self):
        for field, value, reason in (
            ("state", "closed", "closed or a draft"),
            ("draft", True, "closed or a draft"),
            ("number", 3, "different pull request"),
            ("head.repo", {"full_name": "fork/vocabulary_app"}, "originate from this repository"),
            ("head.repo", None, "Expected an object"),
            ("base.repo", {"full_name": "fork/vocabulary_app"}, "originate from this repository"),
            ("base.ref", "master", "target main"),
            ("head.sha", OLD, "head differs"),
            ("base.sha", OLD, "base differs"),
        ):
            with self.subTest(field=field, value=value):
                api = FakeGitHub()
                keys = field.split(".")
                target = api.pull if len(keys) == 1 else api.pull[keys[0]]
                target[keys[-1]] = value
                self.assert_refused(api, reason)

    def test_rejects_missing_untrusted_pending_and_altered_status(self):
        api = FakeGitHub()
        api.responses[paged(STATUSES_PATH, 1)] = [([], False)]
        self.assert_refused(api, "status is missing")

        current_description = approval.evidence_description(clean_evidence())
        for change, reason in (
            ({"creator": {"login": "another-user"}}, "not from the repository owner"),
            ({"state": "pending"}, "status is not successful"),
            ({"description": "reviews-v2:" + "a" * 64}, "does not attest"),
            ({"description": current_description.replace("reviews-v2:", "reviews-v1:", 1)}, "does not attest"),
        ):
            with self.subTest(change=change):
                api = FakeGitHub()
                newer = {**api.latest_status, **change}
                api.responses[paged(STATUSES_PATH, 1)] = [([newer, api.latest_status], False)]
                self.assert_refused(api, reason)

    def test_finds_current_owner_attestation_on_later_page(self):
        api = FakeGitHub()
        api.responses[paged(STATUSES_PATH, 1)] = [([{"context": "unrelated"}], True)]
        api.responses[paged(STATUSES_PATH, 2)] = [([api.latest_status], False)]
        self.assertTrue(self.approve(api))

    def test_rejects_every_missing_required_check(self):
        for index, name in enumerate(approval.REQUIRED_CHECKS):
            with self.subTest(name=name):
                api = FakeGitHub()
                del api.check_runs[index]
                self.assert_refused(api, f"{name} is missing")

    def test_rejects_untrusted_stale_failed_and_skipped_checks(self):
        for changes, reason in (
            ({"app": {"id": 90000, "slug": "github-actions"}}, "not from GitHub Actions"),
            ({"app": {"id": 15368, "slug": "other-app"}}, "not from GitHub Actions"),
            ({"head_sha": OLD}, "different head SHA"),
            ({"status": "in_progress"}, "no successful latest check run"),
            ({"conclusion": "failure"}, "no successful latest check run"),
            ({"conclusion": "neutral"}, "no successful latest check run"),
            ({"conclusion": "skipped"}, "no successful latest check run"),
        ):
            with self.subTest(changes=changes):
                api = FakeGitHub()
                api.check_runs[0].update(changes)
                self.assert_refused(api, reason)

    def test_latest_check_id_wins_across_pages(self):
        for old_conclusion, new_conclusion in (("success", "failure"), ("failure", "success")):
            with self.subTest(old=old_conclusion, new=new_conclusion):
                api = FakeGitHub()
                old = api.check_runs[0]
                old["conclusion"] = old_conclusion
                new = {
                    **old,
                    "id": 1000,
                    "details_url": old["details_url"].rsplit("/", 1)[0] + "/1000",
                    "conclusion": new_conclusion,
                }
                api.responses[paged(CHECKS_PATH, 1)] = [({"check_runs": api.check_runs}, True)]
                api.responses[paged(CHECKS_PATH, 2)] = [({"check_runs": [new]}, False)]
                if new_conclusion == "failure":
                    self.assert_refused(api, "no successful latest check run")
                else:
                    self.assertTrue(self.approve(api))

    def test_refuses_conflicting_same_check_id(self):
        api = FakeGitHub()
        first = api.check_runs[0]
        api.check_runs.append({**first, "conclusion": "failure"})
        self.assert_refused(api, "conflicting results")

    def test_success_from_wrong_pr_or_base_cannot_satisfy_pr_checks(self):
        for source in ("check", "workflow run"):
            for field, value in (("number", PULL + 1), ("base", {"sha": OLD, "ref": "main"}), ("head", {"sha": OLD})):
                with self.subTest(source=source, field=field):
                    api = FakeGitHub()
                    metadata = api.check_runs[0] if source == "check" else api.action_runs[PR_RUN]
                    metadata["pull_requests"][0][field] = value
                    self.assert_refused(api, "did not validate this pull request head against the current main base")

    def test_homonymous_workflows_and_wrong_events_cannot_supply_checks(self):
        for run_id, changes in (
            (PR_RUN, {"path": ".github/workflows/homonym.yml"}),
            (PR_RUN, {"workflow_id": 90000}),
            (PR_RUN, {"event": "pull_request_target"}),
            (PUSH_RUN, {"path": ".github/workflows/homonym.yml"}),
            (PUSH_RUN, {"event": "workflow_dispatch"}),
        ):
            with self.subTest(run_id=run_id, changes=changes):
                api = FakeGitHub()
                api.action_runs[run_id].update(changes)
                self.assert_refused(api, f"is not from {WORKFLOW_PATHS[run_id]}")

    def test_current_pull_metadata_does_not_mask_an_older_tested_base(self):
        api = FakeGitHub()
        api.action_runs[PR_RUN]["display_title"] = f"PR #{PULL} {HEAD} against {OLD}"
        self.assert_refused(api, "run did not record this pull request head and base in its event title")

    def test_checks_must_belong_to_the_reported_run_and_head(self):
        api = FakeGitHub()
        api.check_runs[0]["details_url"] = f"https://other.invalid/{REPOSITORY}/actions/runs/{PR_RUN}/job/1"
        self.assert_refused(api, "does not identify a GitHub Actions job in this repository")

        api = FakeGitHub()
        api.action_runs[PR_RUN]["check_suite_id"] = 90000
        self.assert_refused(api, "does not belong to the reported GitHub Actions run")

        api = FakeGitHub()
        api.action_runs[PUSH_RUN]["head_sha"] = OLD
        self.assert_refused(api, "workflow ran on a different head SHA")

    def test_rejects_missing_ambiguous_unterminated_and_duplicate_json_data(self):
        known = json.dumps(clean_evidence())
        for body, reason in (
            ("No evidence.", "exactly one review evidence marker"),
            (evidence_body(known) * 2, "exactly one review evidence marker"),
            (evidence_body(known).replace("-->", ""), "missing its closing marker"),
            (evidence_body("{"), "not valid JSON"),
            (evidence_body(known.replace('"bloquant": 0', '"bloquant": 0, "bloquant": 0', 1)), "Duplicate key"),
        ):
            with self.subTest(reason=reason):
                api = FakeGitHub()
                api.pull["body"] = body
                self.assert_refused(api, reason)

    def test_rejects_stale_altered_or_wrong_top_level_evidence(self):
        for change, reason in (
            ({"head_sha": OLD}, "different head SHA"),
            ({"base_sha": OLD}, "different base SHA"),
            ({"extra": 1}, "unexpected fields"),
            ({"reviewers": {}}, "exactly the four required reviewer profiles"),
        ):
            with self.subTest(change=change):
                api = FakeGitHub()
                api.pull["body"] = evidence_body(json.dumps({**clean_evidence(), **change}))
                self.assert_refused(api, reason)

        api = FakeGitHub()
        evidence = clean_evidence()
        next(iter(evidence["reviewers"].values()))[0]["report_text"] = "Text changed after attestation."
        api.pull["body"] = evidence_body(json.dumps(evidence))
        self.assert_refused(api, "does not attest")

    def test_rejects_mixed_cycles_with_same_head_and_consecutive_iterations(self):
        evidence = clean_evidence(review_cycle=2, iterations=(1, 2))
        next(iter(evidence["reviewers"].values()))[0]["cycle"] = 1
        api = FakeGitHub(evidence)
        self.assert_refused(api, "matching the evidence review cycle")

    def test_requires_cycle_in_evidence_and_each_report(self):
        evidence = clean_evidence()
        del evidence["review_cycle"]
        for reports in evidence["reviewers"].values():
            for report in reports:
                del report["cycle"]
        self.assert_refused(FakeGitHub(evidence), "Review evidence has unexpected fields")

        evidence = clean_evidence()
        del next(iter(evidence["reviewers"].values()))[0]["cycle"]
        self.assert_refused(FakeGitHub(evidence), "Review report has unexpected fields")

    def test_rejects_invalid_cycle_ids(self):
        for cycle in (0, -1, True, False, 1.0, "1", None):
            with self.subTest(location="evidence", cycle=cycle):
                api = FakeGitHub(clean_evidence(review_cycle=cycle))
                self.assert_refused(api, "Review cycle must be a positive integer")

            with self.subTest(location="report", cycle=cycle):
                evidence = clean_evidence()
                next(iter(evidence["reviewers"].values()))[0]["cycle"] = cycle
                self.assert_refused(FakeGitHub(evidence), "matching the evidence review cycle")

    def test_rejects_cycle_changed_after_owner_attestation(self):
        evidence = clean_evidence(review_cycle=2, iterations=(1, 2))
        api = FakeGitHub(evidence)
        evidence["review_cycle"] = 3
        for reports in evidence["reviewers"].values():
            for report in reports:
                report["cycle"] = 3
        api.pull["body"] = evidence_body(json.dumps(evidence))
        self.assert_refused(api, "does not attest")

    def test_rejects_blockers_important_findings_wrong_verdict_and_bad_types(self):
        for change, reason in (
            ({"bloquant": 1}, "nonzero or invalid findings"),
            ({"important": 1}, "nonzero or invalid findings"),
            ({"important": False}, "nonzero or invalid findings"),
            ({"verdict": "BLOQUÉ"}, "verdict is not PROPRE"),
            ({"iteration": 0}, "outside 1–20"),
            ({"iteration": 21}, "outside 1–20"),
            ({"iteration": 19.0}, "outside 1–20"),
            ({"iteration": 18}, "not consecutive"),
            ({"instance_id": " "}, "invalid instance ID"),
            ({"report_text": " "}, "Empty review report text"),
            ({"extra": True}, "unexpected fields"),
        ):
            with self.subTest(change=change):
                api = FakeGitHub()
                evidence = clean_evidence()
                next(iter(evidence["reviewers"].values()))[0].update(change)
                api.pull["body"] = evidence_body(json.dumps(evidence))
                api.latest_status["description"] = approval.evidence_description(evidence)
                self.assert_refused(api, reason)

    def test_rejects_reused_instances_nonmatching_rounds_and_missing_reports(self):
        cases = ("same profile", "another profile", "different rounds", "missing report")
        for case in cases:
            with self.subTest(case=case):
                api = FakeGitHub()
                evidence = clean_evidence()
                first, second, *_ = evidence["reviewers"].values()
                if case == "same profile":
                    first[0]["instance_id"] = first[1]["instance_id"]
                    reason = "instance was reused"
                elif case == "another profile":
                    first[0]["instance_id"] = second[1]["instance_id"]
                    reason = "instance was reused"
                elif case == "different rounds":
                    first[0]["iteration"], first[1]["iteration"] = 18, 19
                    reason = "did not complete the same iterations"
                else:
                    first.pop()
                    reason = "two reports per profile"
                api.pull["body"] = evidence_body(json.dumps(evidence))
                self.assert_refused(api, reason)

    def test_canonical_digest_ignores_formatting_and_key_order(self):
        evidence = clean_evidence()
        next(iter(evidence["reviewers"].values()))[0]["report_text"] = "Aucun constat — 검증"
        canonical = approval.evidence_description(evidence)
        for ensure_ascii in (False, True):
            payload = json.dumps(evidence, indent=2, sort_keys=ensure_ascii, ensure_ascii=ensure_ascii)
            self.assertEqual(approval.validate_evidence(evidence_body(payload), HEAD, BASE), canonical)
        self.assertRegex(canonical, "^reviews-v2:[0-9a-f]{64}$")

    def test_head_base_or_body_races_fail_closed(self):
        for race, reason in (
            ("head", "head differs"),
            ("base", "Main advanced"),
            ("body", "Review evidence changed"),
            ("status", "status is not successful"),
        ):
            with self.subTest(race=race):
                api = FakeGitHub()
                new_pull = copy.deepcopy(api.pull)
                if race == "head":
                    new_pull["head"]["sha"] = OLD
                elif race == "base":
                    new_main = copy.deepcopy(api.main)
                    new_main["object"]["sha"] = OLD
                    api.responses[MAIN_PATH] = [(api.main, False), (new_main, False)]
                elif race == "body":
                    new_evidence = clean_evidence()
                    next(iter(new_evidence["reviewers"].values()))[0]["report_text"] = "Changed evidence."
                    new_pull["body"] = evidence_body(json.dumps(new_evidence))
                else:
                    new_status = {**api.latest_status, "state": "pending"}
                    api.responses[paged(STATUSES_PATH, 1)] = [([api.latest_status], False), ([new_status], False)]
                api.responses[PULL_PATH] = [(api.pull, False), (new_pull, False)]
                self.assert_refused(api, reason)

    def test_bad_inputs_do_not_construct_api_client(self):
        valid = {
            "GITHUB_TOKEN": "token fixture",
            "GITHUB_REPOSITORY": REPOSITORY,
            "GITHUB_REPOSITORY_OWNER": OWNER,
            "APPROVAL_PULL_NUMBER": str(PULL),
            "APPROVAL_EXPECTED_HEAD": HEAD,
        }
        for change in (
            {"GITHUB_TOKEN": ""},
            {"GITHUB_REPOSITORY": "../path"},
            {"GITHUB_REPOSITORY_OWNER": "other-owner"},
            {"APPROVAL_PULL_NUMBER": "02"},
            {"APPROVAL_PULL_NUMBER": "2?evil"},
            {"APPROVAL_EXPECTED_HEAD": HEAD[:39]},
        ):
            with self.subTest(change=change), patch.dict(os.environ, {**valid, **change}, clear=True):
                with patch.object(approval, "GitHub") as client, patch("sys.stderr"):
                    self.assertEqual(approval.main(), 1)
                    client.assert_not_called()


if __name__ == "__main__":
    unittest.main()
