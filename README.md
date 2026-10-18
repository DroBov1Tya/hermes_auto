# Hermes Pentest Setup

Русская версия: [README.ru.md](README.ru.md)

An interactive Bash installer for a dedicated Hermes security-assessment profile. Choose MCP servers, skill groups, and `SOUL.md` from a terminal menu. The installer does not run scans or start Docker services.

## 🚀 Quick start

Install [Hermes Agent](https://hermes-agent.nousresearch.com/docs/getting-started/installation/), SQLite CLI (`sqlite3`), and Git first. The installer checks dependencies and offers installation through Homebrew or `apt` where supported. Docker and `uv` are required if you select kali-mcp; Node.js with `npx` is required only for Playwright. PentaCore requires `curl`, `jq`, `tar`, and a SHA-256 utility. If Hermes Agent or `uv` is missing, the installer separately offers their official installers.

Start the interactive menu from the repository:

```sh
bash install.sh
```

After the public repository is published, the same installer will be available through one command:

```sh
curl -fsSL https://raw.githubusercontent.com/DroBov1Tya/hermes_auto/main/install.sh | bash
```

The menu asks which MCP servers, skill groups, and profile files to add. Kali's MCP and `kali-workbench` skill are a single choice. Press Enter to accept the suggested defaults; answer `n` to omit any component. After showing the selection summary, the installer checks dependencies and offers available package-manager installs. Long steps show progress, including a Strix skill counter. Existing profile settings and skills are retained. Replacing an existing `SOUL.md` creates a backup. A symlink at `SOUL.md` is left untouched while the rest of the installation continues. The installer enables the `web`, `browser`, and `todo` CLI toolsets, then prints the files on disk and the result of `hermes -p <profile> skills list`. Start a new session to load the changes, or run `/reset` in an active TUI.

After installation, configure a selected Kali proxy before starting its container:

```sh
${EDITOR:-vi} ~/.local/share/hermes-pentest/kali-mcp/.env
cd ~/.local/share/hermes-pentest/kali-mcp
docker compose up -d --build
```

Set `PROXY_PORT` to a SOCKS5 listener reachable from Docker. Then finish Hermes provider setup and inspect the MCP registry:

```sh
hermes -p <profile-name> setup
hermes -p <profile-name> mcp list
hermes -p <profile-name> tools list --platform cli
hermes -p <profile-name> chat
```

Replace `<profile-name>` with the name entered in the installer (default: `pentest`).

## Menu choices

| Choice | What it installs | Default |
| --- | --- | --- |
| PentaCore | Latest release binary, bundled `pentacore-memory` skill, and MCP registration | Yes |
| kali-mcp | Pinned checkout, Python environment, MCP registration, and upstream `kali-workbench` skill | Yes |
| Playwright | Microsoft Playwright MCP registration through `npx` | No |
| Strix playbooks | 29 vulnerability skills and the `llm_applications` dependency | Yes |
| OWASP MCP review | Static source/config review skill for MCP servers | Yes |
| Bug bounty reporting | Report-writing and evidence-handling skill | Yes |
| Provided workflow skills | The supplied skills copied without changes | Yes |
| `SOUL.md` | The supplied profile instructions copied without changes | Yes for a new profile; replacement defaults to No and creates a backup |

The menu is the place to add future MCP servers and skill categories. The kali-mcp choice is optional and controls all three related parts: checkout/dependencies, MCP registration, and skill installation.

## 🧭 Installation flow

1. The installer checks for an interactive terminal and prepares the repository files.
2. You name the profile, choose MCP servers, skill groups, and `SOUL.md`, then confirm the summary.
3. It checks required dependencies and offers packages available through the detected package manager.
4. Selected components install one at a time, with progress for downloads and ✅ markers on completed steps.
5. The summary lists added and retained skills, their path, and commands to inspect MCP servers and CLI toolsets.

Colors are disabled automatically when output is redirected or `NO_COLOR` is set. Emojis are status markers; terminals without an emoji font may render them in monochrome.

## 📁 Layout

```text
Hermes profile: ${HERMES_HOME:-~/.hermes}/profiles/<profile-name>
├── SOUL.md                         optional supplied instructions
├── skills/                         selected user and upstream skill groups
└── MCP configuration                selected local servers

Local files:
├── ~/.local/opt/hermes-pentest/     PentaCore binary
└── ~/.local/share/hermes-pentest/
    ├── kali-mcp/                    optional source and Compose project
    └── strix/                       pinned upstream source
```

The default profile name is `pentest`. Substitute your chosen name and `HERMES_HOME` value in the path. To verify the profile skill list, run `hermes -p <profile-name> skills list`.

| Component | Role | Notes |
| --- | --- | --- |
| Hermes profile | Separate settings, memory, skills, and sessions | A profile does not sandbox local terminal access. |
| PentaCore | Persistent MCP memory | The installer selects the latest published release and checks its archive against that release's `SHA256SUMS`. |
| kali-mcp | Kali tools over stdio MCP | Commands may have network effects. Docker services are not started automatically. |
| [Playwright MCP](https://github.com/microsoft/playwright-mcp) | Optional browser control | Origin settings do not constrain redirects or replace network egress controls. |
| Caido MCP | Manual integration with a separate Caido instance | Not installed automatically; see the Caido docs before connecting an independently maintained server. |

## 📚 Skills and source pins

The installer offers groups rather than installing every available skill. Strix vulnerability playbooks come from `usestrix/strix` commit `972f5097c2bfaf8f1dd8b55744ab8861f0d6b6e5`; the skill bodies are copied from that revision. `llm_applications.md` is included because the Strix prompt-injection playbook references it. The OWASP MCP review skill is pinned to `65d4efd2cd0b081d52101e9708792b944e4ddebb`. The report-writing skill is pinned to `securityskills/skills` commit `b2b6b5200ee91a249816df209a0b89ff01ae450a`. The Kali skill comes from the pinned `DroBov1Tya/kali-mcp` checkout. Supplied skills and `SOUL.md` are copied from this repository.

Strix playbooks are loaded by Hermes on demand. Some describe high-impact testing techniques and assume tools that this setup does not install. Skills do not grant authorization or enforce target boundaries. Use the supplied scope rules, configure network restrictions independently, and review commands before active testing.

## 🕸️ Optional Caido MCP

Strix's Caido integration operates inside its sandbox and is separate from a standalone Hermes MCP connection. For Hermes, install and review a Caido MCP server against [Caido's MCP documentation](https://docs.caido.io/app/tutorials/mcp), then register its actual local executable and loopback URL in the selected profile. Keep its listener bound to loopback and its Caido project limited to the engagement scope. This installer does not fetch or register a third-party Caido server.

## ⚙️ Platform support and limitations

The Bash installer supports macOS Apple Silicon and Linux `x86_64`/`aarch64` PentaCore releases. Intel macOS and Windows are not supported by this installer. Linux requires a sufficiently recent glibc (Ubuntu 24.04, Debian 13, or Fedora 40 or newer). kali-mcp requires Docker and `uv`; Playwright requires Node.js and `npx`.

- The newest published PentaCore release may be a prerelease. Review its release notes.
- `SHA256SUMS` is downloaded from the same release as the archive; this detects transfer errors but is not independent signature verification.
- The installer does not start containers, run scans, validate vulnerabilities, or verify Docker runtime behavior.
- kali-mcp accepts shell commands. Its SOCKS5 route may access destinations beyond container-local firewall rules. Apply egress restrictions outside the agent.
- The upstream kali-mcp SSE configuration mounts the Docker socket; this installer registers host stdio mode only.

## License

This repository is MIT licensed. Third-party software retains its upstream license.
