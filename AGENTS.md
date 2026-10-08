# AGENTS.md

Guidance for AI coding agents working in this repository.

## Project

WordPress plugin: **PKL WPz REST API Authentication** — adds Bearer-token (API key)
authentication in front of the WordPress REST API. Single-plugin repo, no build step,
no package manager. Plain PHP, WordPress Plugin API conventions throughout.

- Main bootstrap: `pkl-wpz-rest-api-auth.php` (defines constants, instantiates
  `PKL_WPZ_REST_API_Auth`, which wires up the classes in `includes/`)
- `includes/class-database.php` — `PKL_WPZ_REST_API_Auth_Database`: creates/reads the
  custom tokens table, generates/revokes/restores/deletes API keys
- `includes/class-oauth-api.php` — `PKL_WPZ_REST_API_Auth_OAuth_API`: hooks into
  `rest_api_init` / authentication filters to validate incoming requests
- `includes/class-user-profile.php` — `PKL_WPZ_REST_API_Auth_User_Profile`: adds the
  "REST API Access" section to `Users > Profile`, AJAX generate/revoke handlers
- `includes/class-admin-page.php` — `PKL_WPZ_REST_API_Auth_Admin_Page`: Settings →
  PKL REST API Auth admin screen (Settings / Access Tokens / API Guide tabs)
- `assets/` — admin and profile page CSS
- `languages/` — `.pot` translation template (`Text Domain: pkl-wpz-rest-api-auth`)
- `readme.txt` — WordPress.org plugin directory listing (SVN-synced, not GitHub docs)

## Two repos, kept in sync

This Git repo (GitHub, source of truth for development) is mirrored by hand into a
separate **SVN working copy** that deploys to the WordPress.org plugin directory
(`https://plugins.svn.wordpress.org/pkl-wpz-rest-api-auth`). SVN has no build step
either — files are copied as-is into `svn/trunk`, then tagged.

- `svn-manager.ps1`, `svn-config-setup.ps1` — PowerShell helpers for the SVN side
  (sync to trunk, commit, create/list/delete tags, exclude patterns)
- `exclude.txt` / `.distignore` — files that must NOT ship to WordPress.org (dev
  scripts, `.git`, `README.md`, CI config, etc.) — keep both in sync when adding
  new dev-only files to the repo root
- `phps-create-worktree.ps1`, `phps-merge-and-cleanup.ps1`, `phps-remove-worktree.ps1`
  — git worktree helpers for parallel feature branches (PHPStorm-oriented, Windows)

When bumping a version, **both halves must move together**:

1. Bump `Version:` + `PKL_WPZ_REST_API_AUTH_VERSION` in `pkl-wpz-rest-api-auth.php`
2. Bump `Stable tag:` in `readme.txt`, update `== Changelog ==`, update
   `Tested up to:` if a newer WordPress version was verified
3. Commit + tag in Git (`git tag -s vX.Y.Z ...` — tags are GPG-signed)
4. Copy the same two files into the SVN `trunk/` working copy, commit to SVN,
   then `svn copy` trunk to `tags/X.Y.Z` on the server
5. Create the matching GitHub release from the signed tag

Do not let the two version strings (plugin header vs. `readme.txt`) drift apart —
WordPress.org reads `Stable tag` from `readme.txt`, not the plugin header.

## Conventions

- Class names: `PKL_WPZ_REST_API_Auth_*`, one class per file in `includes/`,
  filenames `class-*.php` (WordPress naming convention)
- All constants prefixed `PKL_WPZ_REST_API_AUTH_*`
- Escape/sanitize at the WordPress boundary (`sanitize_*`, `esc_*`, `wp_verify_nonce`)
  — this plugin's whole purpose is request authentication, so don't loosen
  validation in `class-oauth-api.php` or `class-database.php` without understanding
  the security implications
- No Composer, no npm, no autoloader — classes are required directly from the
  bootstrap file; keep new files wired up the same way
- Bearer token (`Authorization: Bearer`) is the only auth method. Do not re-add
  `X-API-Key`, form-data or query-parameter auth; keep docs in `README.md`, `readme.txt`
  and the admin API Guide tab consistent
- Target PHP 7.4+ (`Requires PHP` header) — avoid syntax newer than that

## Testing changes

There is no automated test suite. Verify changes manually against a local WordPress
install: activate the plugin, generate an API key from a user profile, and exercise
the REST API with `Authorization: Bearer <key>` as described in `README.md`. Bearer is
the only supported method: also confirm `X-API-Key`, form-data `api_key` and `?api_key=`
are rejected (401).
