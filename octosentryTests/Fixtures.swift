//
//  Fixtures.swift
//  octosentryTests
//
//  Response bodies recorded from the GitHub REST alert endpoints, trimmed
//  to a couple of entries each but otherwise left as the API returns them.
//

enum Fixtures {

    static let dependabotAlerts = """
    [
      {
        "number": 4,
        "state": "open",
        "html_url": "https://github.com/octocat/hello-world/security/dependabot/4",
        "created_at": "2026-06-21T22:12:22Z",
        "updated_at": "2026-06-22T13:10:00Z",
        "dependency": {
          "package": { "ecosystem": "npm", "name": "some-package" },
          "manifest_path": "package-lock.json",
          "scope": "runtime"
        },
        "security_advisory": {
          "ghsa_id": "GHSA-rf4j-j272-fj86",
          "cve_id": "CVE-2026-11111",
          "summary": "Denial of service in some-package",
          "severity": "high"
        },
        "security_vulnerability": {
          "severity": "high",
          "vulnerable_version_range": "< 1.2.3"
        }
      },
      {
        "number": 3,
        "state": "open",
        "html_url": "https://github.com/octocat/hello-world/security/dependabot/3",
        "created_at": "2026-06-19T09:01:00Z",
        "updated_at": "2026-06-19T09:01:00Z",
        "dependency": {
          "package": { "ecosystem": "npm", "name": "other-package" },
          "manifest_path": "package-lock.json",
          "scope": "development"
        },
        "security_advisory": {
          "ghsa_id": "GHSA-aaaa-bbbb-cccc",
          "cve_id": null,
          "summary": "Prototype pollution in other-package",
          "severity": "moderate"
        },
        "security_vulnerability": {
          "severity": "moderate",
          "vulnerable_version_range": "< 4.0.0"
        }
      }
    ]
    """

    static let codeScanningAlerts = """
    [
      {
        "number": 12,
        "state": "open",
        "html_url": "https://github.com/octocat/hello-world/security/code-scanning/12",
        "created_at": "2026-06-20T08:00:00Z",
        "updated_at": "2026-06-20T08:30:00Z",
        "rule": {
          "id": "js/sql-injection",
          "name": "js/sql-injection",
          "severity": "error",
          "security_severity_level": "high",
          "description": "Query built from user-controlled sources",
          "tags": ["security", "external/cwe/cwe-089"]
        },
        "tool": { "name": "CodeQL", "version": "2.16.0" },
        "most_recent_instance": {
          "ref": "refs/heads/main",
          "state": "open",
          "message": { "text": "This query depends on a user-provided value." },
          "location": { "path": "src/db.js", "start_line": 42 }
        }
      },
      {
        "number": 11,
        "state": "open",
        "html_url": "https://github.com/octocat/hello-world/security/code-scanning/11",
        "created_at": "2026-06-18T11:00:00Z",
        "updated_at": "2026-06-18T11:00:00Z",
        "rule": {
          "id": "js/unused-local-variable",
          "name": "js/unused-local-variable",
          "severity": "warning",
          "security_severity_level": null,
          "description": "Unused variable",
          "tags": ["maintainability"]
        },
        "tool": { "name": "CodeQL", "version": "2.16.0" }
      }
    ]
    """

    static let secretScanningAlerts = """
    [
      {
        "number": 2,
        "state": "open",
        "html_url": "https://github.com/octocat/hello-world/security/secret-scanning/2",
        "created_at": "2026-06-22T17:45:00Z",
        "updated_at": "2026-06-22T17:45:00Z",
        "secret_type": "github_personal_access_token",
        "secret_type_display_name": "GitHub Personal Access Token",
        "validity": "active",
        "push_protection_bypassed": false
      },
      {
        "number": 1,
        "state": "open",
        "html_url": "https://github.com/octocat/hello-world/security/secret-scanning/1",
        "created_at": "2026-06-15T10:00:00Z",
        "updated_at": "2026-06-15T10:00:00Z",
        "secret_type": "generic_api_key",
        "secret_type_display_name": "Generic API Key",
        "push_protection_bypassed": false
      }
    ]
    """

    static let userRepos = """
    [
      { "id": 1296269, "name": "hello-world", "full_name": "octocat/hello-world", "private": false },
      { "id": 1296270, "name": "spoon-knife", "full_name": "octocat/spoon-knife", "private": true }
    ]
    """
}
