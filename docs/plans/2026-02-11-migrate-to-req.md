# Migrate from Finch to Req Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace custom Finch HTTP client implementation with Req, eliminating 80+ lines of custom redirect handling while maintaining the HTTPClient behavior contract.

**Architecture:** Replace `Tzdata.HTTPClient.Finch` with `Tzdata.HTTPClient.Req`. Req provides redirect handling, retries, and error handling out-of-the-box while using Finch underneath for connection pooling. No Brotli dependency needed (optional in Req, not used by tzdata).

**Tech Stack:** Req 0.5+, Finch 0.21+ (as Req dependency), ExUnit for testing

---

## Task 1: Update Dependencies

**Files:**
- Modify: `mix.exs:29-32`

**Step 1: Update dependencies in mix.exs**

```elixir
defp deps do
  [
    {:req, "~> 0.5"},
    {:ex_doc, "~> 0.21", only: :dev, runtime: false}
  ]
end
```

**Step 2: Install dependencies**

Run: `mix deps.get`
Expected: Req and its dependencies (including Finch) installed

**Step 3: Commit**

```bash
git add mix.exs mix.lock
git commit -m "deps: replace finch with req dependency"
```

---

## Task 2: Create Req HTTP Client Adapter

**Files:**
- Create: `lib/tzdata/http_client/req.ex`
- Test: `test/tzdata/http_client/req_test.exs`

**Step 1: Write failing test for basic GET request**

```elixir
# test/tzdata/http_client/req_test.exs
defmodule Tzdata.HTTPClient.ReqTest do
  use ExUnit.Case, async: false

  alias Tzdata.HTTPClient.Req, as: ReqClient

  @moduletag :req

  describe "get/3" do
    test "successfully performs GET request" do
      url = "https://httpbin.org/get"
      headers = []
      options = []

      assert {:ok, {status, response_headers, body}} = ReqClient.get(url, headers, options)
      assert status == 200
      assert is_list(response_headers)
      assert is_binary(body)
      assert body =~ "httpbin"
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/tzdata/http_client/req_test.exs`
Expected: FAIL - module Tzdata.HTTPClient.Req not found

**Step 3: Implement minimal Req adapter for GET**

```elixir
# lib/tzdata/http_client/req.ex
defmodule Tzdata.HTTPClient.Req do
  @moduledoc false

  @behaviour Tzdata.HTTPClient

  @impl true
  def get(url, headers, _options) do
    case Req.request(method: :get, url: url, headers: headers) do
      {:ok, %Req.Response{status: status, headers: response_headers, body: body}} ->
        # Convert headers to list of tuples to match HTTPClient behavior
        headers_list = Enum.map(response_headers, fn {k, v} -> {k, List.first(v) || v} end)
        {:ok, {status, headers_list, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def head(_url, _headers, _options) do
    # Stub for now - will implement in Task 4
    {:error, :not_implemented}
  end
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/tzdata/http_client/req_test.exs`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/tzdata/http_client/req.ex test/tzdata/http_client/req_test.exs
git commit -m "feat: add Req HTTP client adapter"
```

---

## Task 3: Add Redirect Handling

**Files:**
- Modify: `test/tzdata/http_client/req_test.exs`
- Modify: `lib/tzdata/http_client/req.ex`

**Step 1: Write test for redirect following**

```elixir
# Add to test/tzdata/http_client/req_test.exs describe "get/3" block

test "follows redirects when follow_redirect is true" do
  url = "https://httpbin.org/redirect/1"
  headers = []
  options = [follow_redirect: true]

  assert {:ok, {status, response_headers, body}} = ReqClient.get(url, headers, options)
  assert status == 200
  assert is_list(response_headers)
  assert is_binary(body)
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/tzdata/http_client/req_test.exs`
Expected: FAIL - redirects not followed

**Step 3: Implement redirect handling in get/3**

```elixir
# Update lib/tzdata/http_client/req.ex get/3 function
@impl true
def get(url, headers, options) do
  follow_redirect = Keyword.get(options, :follow_redirect, false)

  req_options = [
    headers: headers,
    redirect: follow_redirect
  ]

  case Req.request(method: :get, url: url, req_options) do
    {:ok, %Req.Response{status: status, headers: response_headers, body: body}} ->
      headers_list = Enum.map(response_headers, fn {k, v} -> {k, List.first(v) || v} end)
      {:ok, {status, headers_list, body}}

    {:error, reason} ->
      {:error, reason}
  end
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/tzdata/http_client/req_test.exs`
Expected: PASS

**Step 5: Write test for not following redirects**

```elixir
# Add to test/tzdata/http_client/req_test.exs describe "get/3" block

test "does not follow redirects when follow_redirect is false" do
  url = "https://httpbin.org/redirect/1"
  headers = []
  options = [follow_redirect: false]

  assert {:ok, {status, response_headers, _body}} = ReqClient.get(url, headers, options)
  assert status in [301, 302, 307, 308]
  # Should have location header
  assert Enum.any?(response_headers, fn {k, _v} -> String.downcase(k) == "location" end)
end
```

**Step 6: Run test to verify it passes**

Run: `mix test test/tzdata/http_client/req_test.exs`
Expected: PASS (implementation already handles this)

**Step 7: Commit**

```bash
git add lib/tzdata/http_client/req.ex test/tzdata/http_client/req_test.exs
git commit -m "feat: add redirect handling to Req adapter"
```

---

## Task 4: Implement HEAD Requests

**Files:**
- Modify: `test/tzdata/http_client/req_test.exs`
- Modify: `lib/tzdata/http_client/req.ex`

**Step 1: Write test for HEAD request**

```elixir
# Add to test/tzdata/http_client/req_test.exs

describe "head/3" do
  test "successfully performs HEAD request" do
    url = "https://httpbin.org/get"
    headers = []
    options = []

    assert {:ok, {status, response_headers}} = ReqClient.head(url, headers, options)
    assert status == 200
    assert is_list(response_headers)
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/tzdata/http_client/req_test.exs`
Expected: FAIL - returns {:error, :not_implemented}

**Step 3: Implement HEAD request**

```elixir
# Update lib/tzdata/http_client/req.ex head/3 function
@impl true
def head(url, headers, _options) do
  case Req.request(method: :head, url: url, headers: headers) do
    {:ok, %Req.Response{status: status, headers: response_headers}} ->
      headers_list = Enum.map(response_headers, fn {k, v} -> {k, List.first(v) || v} end)
      {:ok, {status, headers_list}}

    {:error, reason} ->
      {:error, reason}
  end
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/tzdata/http_client/req_test.exs`
Expected: PASS

**Step 5: Write test for error handling**

```elixir
# Add to describe "head/3" block

test "returns error for invalid URL" do
  url = "https://this-domain-does-not-exist-12345.com"
  headers = []
  options = []

  assert {:error, _reason} = ReqClient.head(url, headers, options)
end
```

**Step 6: Run test to verify it passes**

Run: `mix test test/tzdata/http_client/req_test.exs`
Expected: PASS (implementation already handles this)

**Step 7: Commit**

```bash
git add lib/tzdata/http_client/req.ex test/tzdata/http_client/req_test.exs
git commit -m "feat: implement HEAD requests in Req adapter"
```

---

## Task 5: Verify Custom Headers Work

**Files:**
- Modify: `test/tzdata/http_client/req_test.exs`

**Step 1: Write test for custom headers**

```elixir
# Add to test/tzdata/http_client/req_test.exs describe "get/3" block

test "sends custom headers in request" do
  url = "https://httpbin.org/headers"
  headers = [{"X-Custom-Header", "test-value"}]
  options = []

  assert {:ok, {status, _response_headers, body}} = ReqClient.get(url, headers, options)
  assert status == 200
  assert body =~ "X-Custom-Header"
  assert body =~ "test-value"
end
```

**Step 2: Run test to verify it passes**

Run: `mix test test/tzdata/http_client/req_test.exs`
Expected: PASS (implementation already handles this)

**Step 3: Commit**

```bash
git add test/tzdata/http_client/req_test.exs
git commit -m "test: verify custom headers work with Req adapter"
```

---

## Task 6: Add Integration Test for IANA Data

**Files:**
- Create: `test/integration/req_download_test.exs`

**Step 1: Write integration test for real IANA download**

```elixir
# test/integration/req_download_test.exs
defmodule Tzdata.Integration.ReqDownloadTest do
  use ExUnit.Case

  @moduletag :integration
  @moduletag timeout: 60_000

  alias Tzdata.HTTPClient.Req, as: ReqClient

  describe "real IANA timezone data operations" do
    test "can download IANA tzdata file" do
      url = "https://data.iana.org/time-zones/tzdata-latest.tar.gz"
      headers = []
      options = [follow_redirect: true]

      assert {:ok, {status, response_headers, body}} = ReqClient.get(url, headers, options)
      assert status == 200
      assert is_list(response_headers)
      assert is_binary(body)
      assert byte_size(body) > 100_000
    end

    test "can get HEAD information from IANA" do
      url = "https://data.iana.org/time-zones/tzdata-latest.tar.gz"
      headers = []
      options = []

      assert {:ok, {status, response_headers}} = ReqClient.head(url, headers, options)
      assert status == 200
      assert is_list(response_headers)

      # Should have Last-Modified header
      assert Enum.any?(response_headers, fn {k, _v} ->
        String.downcase(k) == "last-modified"
      end)

      # Should have Content-Length header
      assert Enum.any?(response_headers, fn {k, _v} ->
        String.downcase(k) == "content-length"
      end)
    end
  end
end
```

**Step 2: Run integration test**

Run: `mix test test/integration/req_download_test.exs --include integration`
Expected: PASS

**Step 3: Commit**

```bash
git add test/integration/req_download_test.exs
git commit -m "test: add integration tests for Req adapter with IANA data"
```

---

## Task 7: Update Default HTTP Client Configuration

**Files:**
- Modify: `mix.exs:47`

**Step 1: Write test verifying default client is Req**

```elixir
# test/tzdata/config_test.exs
defmodule Tzdata.ConfigTest do
  use ExUnit.Case

  test "default http_client is Req" do
    # Get default from application env
    default_client = Application.get_env(:tzdata, :http_client)
    assert default_client == Tzdata.HTTPClient.Req
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/tzdata/config_test.exs`
Expected: FAIL - default is still Finch

**Step 3: Update default in mix.exs**

```elixir
# mix.exs
defp env do
  [
    autoupdate: :enabled,
    data_dir: nil,
    http_client: Tzdata.HTTPClient.Req
  ]
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/tzdata/config_test.exs`
Expected: PASS

**Step 5: Commit**

```bash
git add mix.exs test/tzdata/config_test.exs
git commit -m "config: set Req as default HTTP client"
```

---

## Task 8: Run Full Test Suite

**Files:**
- N/A (verification step)

**Step 1: Run all existing tests**

Run: `mix test`
Expected: All tests pass

**Step 2: Run integration tests**

Run: `mix test --include integration`
Expected: All tests pass

**Step 3: If any tests fail, investigate and fix**

Review failures and adjust implementation as needed.

**Step 4: Commit any fixes**

```bash
git add <fixed-files>
git commit -m "fix: address test failures from Req migration"
```

---

## Task 9: Update README Documentation

**Files:**
- Modify: `README.md:100-140` (HTTP Client section)

**Step 1: Update HTTP Client section in README**

```markdown
## HTTP Client

Tzdata uses Req (via the Finch HTTP client) for HTTPS requests to get new updates. Req provides secure HTTPS connections with proper SSL certificate verification when downloading new tzdata releases from IANA.

### Custom HTTP Client

If you want to use a different HTTP client, you can configure it in your application:

```elixir
# config/config.exs
config :tzdata, http_client: MyApp.CustomHTTPClient
```

Your custom client must implement the `Tzdata.HTTPClient` behaviour:

```elixir
defmodule MyApp.CustomHTTPClient do
  @behaviour Tzdata.HTTPClient

  @impl true
  def get(url, headers, options) do
    # Return {:ok, {status, headers, body}} or {:error, reason}
  end

  @impl true
  def head(url, headers, options) do
    # Return {:ok, {status, headers}} or {:error, reason}
  end
end
```

### Using Hackney (Legacy)

If you need to continue using Hackney, you can configure it explicitly:

```elixir
# mix.exs
defp deps do
  [
    {:tzdata, "~> 1.2"},
    {:hackney, "~> 1.0"}
  ]
end

# config/config.exs
config :tzdata, http_client: Tzdata.HTTPClient.Hackney
```

Note: Hackney has known security vulnerabilities and is less actively maintained than Req/Finch.
```

**Step 2: Commit README changes**

```bash
git add README.md
git commit -m "docs: update README for Req HTTP client"
```

---

## Task 10: Update CHANGELOG

**Files:**
- Modify: `CHANGELOG.md:1-27`

**Step 1: Update CHANGELOG with Req migration**

```markdown
# Changelog for Tzdata

## [Unreleased]

### Changed
- Replaced Hackney with Req as the default HTTP client
  - Addresses security concerns with Hackney (CVE-2018-1000007,
    AIKIDO-2026-10122)
  - See https://hexdocs.pm/hackney/news.html#3-0-0-2026-01-27
  - See https://intel.aikido.dev/cve/AIKIDO-2026-10122
  - Req is now required dependency instead of Hackney
  - Default `:http_client` config changed to `Tzdata.HTTPClient.Req`
  - Users who need Hackney can still configure it explicitly (see README)
  - Hackney implementation remains available for backward compatibility
  - Req provides redirect handling, retries, and better error handling out-of-the-box
  - No native dependencies required (Brotli compression is optional and not used)

### Added
- New `Tzdata.HTTPClient.Req` implementation with full SSL verification

### Fixed
- Pattern matching bug in `DataLoader.do_latest_file_size_by_head/1` to
  handle new HTTP client response format

### Migration Guide
- Req will be installed automatically when you update dependencies
- No code changes needed unless you explicitly configured Hackney
- If you want to continue using Hackney, see README for configuration
```

**Step 2: Commit CHANGELOG**

```bash
git add CHANGELOG.md
git commit -m "docs: update CHANGELOG for Req migration"
```

---

## Task 11: Remove Finch Adapter and Tests

**Files:**
- Delete: `lib/tzdata/http_client/finch.ex`
- Delete: `test/tzdata/http_client/finch_test.exs`
- Delete: `test/integration/real_download_test.exs` (if exists)

**Step 1: Remove Finch adapter**

Run: `git rm lib/tzdata/http_client/finch.ex`

**Step 2: Remove Finch tests**

Run: `git rm test/tzdata/http_client/finch_test.exs`

**Step 3: Remove old integration tests if they exist**

Run: `git rm test/integration/real_download_test.exs` (if exists)

**Step 4: Run tests to ensure nothing broke**

Run: `mix test`
Expected: All tests pass

**Step 5: Commit removals**

```bash
git commit -m "refactor: remove Finch adapter in favor of Req"
```

---

## Task 12: Final Verification

**Files:**
- N/A (verification only)

**Step 1: Clean and recompile**

Run: `mix clean && mix compile`
Expected: Clean compilation with no warnings

**Step 2: Run full test suite**

Run: `mix test --include integration`
Expected: All tests pass

**Step 3: Check for compilation warnings**

Run: `mix compile --warnings-as-errors`
Expected: No warnings

**Step 4: Verify with real IANA download**

Start an IEx session and test:

```bash
iex -S mix
```

```elixir
Tzdata.DataLoader.download_new()
```

Expected: Successfully downloads tzdata

**Step 5: Create final commit if any fixes needed**

```bash
git add <any-final-fixes>
git commit -m "fix: final adjustments for Req migration"
```

---

## Testing Strategy

### Unit Tests
- Test Req adapter with mock HTTP responses
- Test redirect behavior (follow vs no-follow)
- Test custom headers
- Test error handling

### Integration Tests
- Test actual IANA downloads
- Test HEAD requests for metadata
- Verify SSL certificate validation works

### Backward Compatibility
- Keep HTTPClient behavior contract unchanged
- Hackney adapter still available for users who need it
- Configuration changes are documented in README

---

## Rollback Plan

If issues arise:

1. Revert to Finch by updating mix.exs:
   ```elixir
   {:finch, "~> 0.21"}
   ```

2. Update config:
   ```elixir
   config :tzdata, http_client: Tzdata.HTTPClient.Finch
   ```

3. The Finch adapter code can be restored from git history

---

## Post-Migration Validation

After deployment:
1. Monitor for any HTTP-related errors
2. Verify automatic updates continue working
3. Check SSL certificate validation is functioning
4. Confirm no performance regressions in download times
