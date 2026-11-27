"""Submit a GitHub Actions approval for owner-attested review convergence."""

import hashlib
import json
import os
import re
import sys
from urllib.error import HTTPError, URLError
from urllib.request import HTTPRedirectHandler, Request, build_opener


MAIN = "main"
REVIEW_CONTEXT = "PR / Independent agent reviews"
EVIDENCE_MARKER = "<!-- ponderin-review-evidence"
ACTIONS_BOT = "github-actions[bot]"
ACTIONS_APP = {"id": 15368, "slug": "github-actions"}
REQUIRED_CHECKS = (
    "PR / Flutter quality",
    "PR / Provider boundaries",
    "PR / Android native build",
    "PR / Dependency review",
    "PR / Secret scan",
    "PR / Workflow security",
    "test",
)
REVIEWERS = {
    "pr_product_contract_reviewer",
    "pr_code_quality_reviewer",
    "pr_correctness_tests_reviewer",
    "pr_security_delivery_reviewer",
}
REPORT_FIELDS = {"iteration", "instance_id", "verdict", "bloquant", "important"}
SHA = re.compile(r"[0-9a-f]{40}")


class ApprovalError(Exception):
    """The approval could not be verified or submitted."""


def require(condition, reason):
    if not condition:
        raise ApprovalError(reason)


def object_data(value):
    require(isinstance(value, dict), "Expected an object in GitHub response.")
    return value


def unique_keys(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, "Duplicate key in review evidence.")
        result[key] = value
    return result


def evidence_description(evidence):
    canonical = json.dumps(
        evidence, sort_keys=True, separators=(",", ":"), ensure_ascii=True
    ).encode("utf-8")
    return "reviews-v1:" + hashlib.sha256(canonical).hexdigest()


def validate_evidence(body, head, base):
    require(
        isinstance(body, str) and body.count(EVIDENCE_MARKER) == 1,
        "Expected exactly one review evidence marker in the pull request body.",
    )
    _, _, marked = body.partition(EVIDENCE_MARKER)
    payload, end, _ = marked.partition("-->")
    require(end, "Review evidence comment is missing its closing marker.")
    try:
        evidence = json.loads(payload, object_pairs_hook=unique_keys)
    except (ValueError, RecursionError) as exc:
        raise ApprovalError("Review evidence comment is not valid JSON.") from exc
    require(
        isinstance(evidence, dict) and evidence.keys() == {"head_sha", "base_sha", "reviewers"},
        "Review evidence has unexpected fields.",
    )
    require(evidence["head_sha"] == head, "Review evidence is for a different head SHA.")
    require(evidence["base_sha"] == base, "Review evidence is for a different base SHA.")
    reviewers = evidence["reviewers"]
    require(
        isinstance(reviewers, dict) and reviewers.keys() == REVIEWERS,
        "Review evidence must include exactly the four required reviewer profiles.",
    )

    instance_ids = set()
    convergence_rounds = None
    for reports in reviewers.values():
        require(isinstance(reports, list) and len(reports) == 2, "Expected two reports per profile.")
        rounds = []
        for report in reports:
            require(
                isinstance(report, dict)
                and report.keys() in (REPORT_FIELDS, REPORT_FIELDS | {"report_text"}),
                "Review report has unexpected fields.",
            )
            if "report_text" in report:
                report_text = report["report_text"]
                require(isinstance(report_text, str) and report_text.strip(), "Empty review report text.")
            require(report["verdict"] == "PROPRE", "Review verdict is not PROPRE.")
            for severity in ("bloquant", "important"):
                count = report[severity]
                require(type(count) is int and count == 0, "Review has nonzero or invalid findings.")

            iteration = report["iteration"]
            require(type(iteration) is int and 1 <= iteration <= 20, "Iteration is outside 1–20.")
            rounds.append(iteration)
            instance_id = report["instance_id"]
            require(
                isinstance(instance_id, str) and instance_id and instance_id == instance_id.strip(),
                "Review report has an invalid instance ID.",
            )
            require(instance_id not in instance_ids, "A reviewer instance was reused.")
            instance_ids.add(instance_id)

        require(rounds[1] == rounds[0] + 1, "Clean review iterations are not consecutive.")
        if convergence_rounds is None:
            convergence_rounds = rounds
        require(rounds == convergence_rounds, "Reviewer profiles did not complete the same iterations.")
    return evidence_description(evidence)


class NoRedirects(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


class GitHub:
    def __init__(self, token, repository):
        self.token = token
        self.root = f"https://api.github.com/repos/{repository}"
        self.opener = build_opener(NoRedirects())

    def request(self, path, body=None):
        request = Request(
            self.root + path,
            data=None if body is None else json.dumps(body).encode("utf-8"),
            headers={
                "Accept": "application/vnd.github+json",
                "Authorization": f"Bearer {self.token}",
                "Content-Type": "application/json",
                "User-Agent": "ponderin-validated-pr-approval",
                "X-GitHub-Api-Version": "2022-11-28",
            },
        )
        try:
            with self.opener.open(request, timeout=20) as response:
                result = json.load(response)
                has_next = re.search(r'\brel="next"', response.headers.get("Link", "")) is not None
                return result, has_next
        except HTTPError as exc:
            raise ApprovalError(f"GitHub API returned HTTP {exc.code} for {path}.") from exc
        except (URLError, OSError, ValueError, RecursionError) as exc:
            raise ApprovalError(f"GitHub API request failed for {path}.") from exc

    def get(self, path):
        result, _ = self.request(path)
        return object_data(result)

    def pages(self, path, field=None):
        separator = "&" if "?" in path else "?"
        page = 1
        while True:
            result, has_next = self.request(f"{path}{separator}per_page=100&page={page}")
            entries = result if field is None else object_data(result).get(field)
            require(isinstance(entries, list), "Expected a list in GitHub response.")
            for entry in entries:
                yield object_data(entry)
            if not has_next:
                return
            page += 1

    def post(self, path, body):
        result, _ = self.request(path, body)
        return object_data(result)


def main_tip(api):
    ref = api.get(f"/git/ref/heads/{MAIN}")
    require(ref.get("ref") == f"refs/heads/{MAIN}", "GitHub returned an unexpected base ref.")
    target = object_data(ref.get("object"))
    sha = target.get("sha")
    require(
        target.get("type") == "commit" and isinstance(sha, str) and SHA.fullmatch(sha),
        "GitHub returned an invalid main tip.",
    )
    return sha


def validate_pull(pull, number, repository, head, base):
    require(pull.get("number") == number, "GitHub returned a different pull request.")
    require(pull.get("state") == "open" and pull.get("draft") is False, "Pull request is closed or a draft.")
    pull_head = object_data(pull.get("head"))
    pull_base = object_data(pull.get("base"))
    require(pull_base.get("ref") == MAIN, "Pull request must target main.")
    for branch in (pull_head, pull_base):
        require(
            object_data(branch.get("repo")).get("full_name") == repository,
            "Pull request must originate from this repository and target it.",
        )
    require(pull_head.get("sha") == head, "Pull request head differs from the expected SHA.")
    require(pull_base.get("sha") == base, "Pull request base differs from the current main tip.")


def validate_status(api, owner, head, description):
    # GitHub returns commit statuses in reverse chronological order.
    for status in api.pages(f"/commits/{head}/statuses"):
        if status.get("context") != REVIEW_CONTEXT:
            continue
        require(status.get("state") == "success", "Independent review status is not successful.")
        require(
            object_data(status.get("creator")).get("login") == owner,
            "Independent review status is not from the repository owner.",
        )
        require(
            status.get("description") == description,
            "Owner status does not attest to the review evidence in the pull request body.",
        )
        return
    raise ApprovalError("Independent review status is missing.")


def validate_checks(api, head):
    latest = {}
    for check in api.pages(f"/commits/{head}/check-runs?filter=all", "check_runs"):
        name = check.get("name")
        if name not in REQUIRED_CHECKS:
            continue
        run_id = check.get("id")
        require(type(run_id) is int and run_id > 0, f"{name} has an invalid check run ID.")
        previous = latest.get(name)
        if previous is None or run_id > previous["id"]:
            latest[name] = check
        elif run_id == previous["id"]:
            require(check == previous, f"{name} has conflicting results for the same check run.")

    for name in REQUIRED_CHECKS:
        require(name in latest, f"{name} is missing.")
        check = latest[name]
        app = object_data(check.get("app"))
        require(all(app.get(key) == value for key, value in ACTIONS_APP.items()), f"{name} is not from GitHub Actions.")
        require(check.get("head_sha") == head, f"{name} is for a different head SHA.")
        require(
            check.get("status") == "completed" and check.get("conclusion") == "success",
            f"{name} has no successful latest check run.",
        )


def is_actions_approval(review, head):
    if review.get("state") != "APPROVED" or review.get("commit_id") != head:
        return False
    user = review.get("user")
    return isinstance(user, dict) and user.get("login") == ACTIONS_BOT and user.get("type") == "Bot"


def approve(api, repository, owner, number, head):
    pull_path = f"/pulls/{number}"
    reviews_path = f"{pull_path}/reviews"
    base = main_tip(api)
    pull = api.get(pull_path)
    validate_pull(pull, number, repository, head, base)
    description = validate_evidence(pull.get("body"), head, base)
    validate_status(api, owner, head, description)
    validate_checks(api, head)
    if any(is_actions_approval(review, head) for review in api.pages(reviews_path)):
        return False

    require(main_tip(api) == base, "Main advanced while approval was being verified.")
    validate_status(api, owner, head, description)
    pull = api.get(pull_path)
    validate_pull(pull, number, repository, head, base)
    require(
        validate_evidence(pull.get("body"), head, base) == description,
        "Review evidence changed while approval was being verified.",
    )
    review = api.post(
        reviews_path,
        {
            "event": "APPROVE",
            "commit_id": head,
            "body": "GitHub Actions verified the required CI checks and the repository owner's "
            "attestation of two consecutive clean rounds by all four independent reviewer "
            f"profiles.\n\nEvidence: `{description}`.",
        },
    )
    require(is_actions_approval(review, head), "GitHub did not confirm an Actions approval for the expected SHA.")
    return True


def main():
    try:
        token = os.environ.get("GITHUB_TOKEN")
        repository = os.environ.get("GITHUB_REPOSITORY", "")
        owner = os.environ.get("GITHUB_REPOSITORY_OWNER", "")
        number = os.environ.get("APPROVAL_PULL_NUMBER", "")
        head = os.environ.get("APPROVAL_EXPECTED_HEAD", "").lower()
        require(token, "Missing GitHub Actions token.")
        require(
            re.fullmatch(r"[A-Za-z0-9-]+/[A-Za-z0-9_.-]+", repository)
            and repository.partition("/")[0] == owner,
            "Invalid GitHub repository or repository owner.",
        )
        require(re.fullmatch(r"[1-9][0-9]{0,9}", number), "Expected a positive pull request number.")
        require(SHA.fullmatch(head), "Expected a full 40-character head SHA.")
        submitted = approve(GitHub(token, repository), repository, owner, int(number), head)
    except ApprovalError as exc:
        print(f"Approval failed: {exc}", file=sys.stderr)
        return 1

    if submitted:
        print(f"Approved pull request #{number} at {head}.")
    else:
        print(f"An Actions approval already exists for pull request #{number} at {head}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
