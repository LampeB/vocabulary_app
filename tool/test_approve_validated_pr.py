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


def clean_evidence():
    return {
        "head_sha": HEAD,
        "base_sha": BASE,
        "reviewers": {
            reviewer: [
                {
                    "iteration": iteration,
                    "instance_id": f"{reviewer}:{iteration}",
                    "verdict": "PROPRE",
                    "bloquant": 0,
                    "important": 0,
                }
                for iteration in (19, 20)
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
    def __init__(self):
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
        self.check_runs = [
            {
                "id": index,
                "name": name,
                "app": approval.ACTIONS_APP.copy(),
                "status": "completed",
                "conclusion": "success",
                "head_sha": HEAD,
            }
            for index, name in enumerate(approval.REQUIRED_CHECKS, 1)
        ]
        self.responses = {
            MAIN_PATH: [(self.main, False)],
            PULL_PATH: [(self.pull, False)],
            paged(STATUSES_PATH, 1): [([self.latest_status], False)],
            paged(CHECKS_PATH, 1): [({"check_runs": self.check_runs}, False)],
            paged(REVIEWS_PATH, 1): [([], False)],
        }
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

        for change, reason in (
            ({"creator": {"login": "another-user"}}, "not from the repository owner"),
            ({"state": "pending"}, "status is not successful"),
            ({"description": "reviews-v1:" + "a" * 64}, "does not attest"),
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
                new = {**old, "id": 1000, "conclusion": new_conclusion}
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
        self.assertRegex(canonical, "^reviews-v1:[0-9a-f]{64}$")

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
