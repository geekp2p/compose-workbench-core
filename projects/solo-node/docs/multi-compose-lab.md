# Embedding `solo-node` inside `multi-compose-lab`

This guide shows how to add the Bitcoin solo-node stack as another project in
[`multi-compose-lab`](https://github.com/superpung/multi-compose-lab) so you can
start/stop it with the same `up.ps1` / `down.ps1` helpers used by the existing
`go-hello`, `py-hello`, and `node-hello` samples.

## 1) Copy the project into `projects/solo-node`
1. Clone both repositories side by side:
   ```powershell
   git clone https://github.com/superpung/multi-compose-lab.git C:\multiprojlab\multi-compose-lab
   git clone https://github.com/superpung/solo-node.git       C:\multiprojlab\solo-node
   ```
2. Create a new project folder and copy everything from this repo into it
   (including hidden files like `.env.example`):
   ```powershell
   mkdir C:\multiprojlab\multi-compose-lab\projects\solo-node
   robocopy C:\multiprojlab\solo-node C:\multiprojlab\multi-compose-lab\projects\solo-node /MIR /XD .git
   ```
   The `robocopy` command mirrors the contents while skipping the `.git`
   directory so the lab repository keeps its own Git history.

## 2) Compose file is already named for the lab
This repository now ships with both `docker-compose.yml` (original name) and a
copy named `compose.yml` so the lab helper scripts find it automatically. If you
mirror a fresh clone into `projects/solo-node`, the `compose.yml` file comes
along and no manual renaming is needed.

## 3) Fetch CKPool sources inside the new project folder
Run the fetch script from the **copied** project so the `ckpool/src/` directory
is populated before you bring the stack up:
```powershell
cd C:\multiprojlab\multi-compose-lab\projects\solo-node
./ckpool/fetch-source.sh
```
(Use Git Bash on Windows so the POSIX shell script can run.)

## 4) Optional: customize paths/credentials
If you want to place the blockchain on another drive or override RPC credentials
and payout addresses, copy `.env.example` to `.env` inside the new project
folder and edit the values. All overrides continue to work because the compose
file is identical to the original repository.

## 5) Start/stop via the lab wrappers
From the `multi-compose-lab` root you can now manage the stack just like the
other samples:
```powershell
# Build and start
.\up.ps1 solo-node -Build

# Stop and remove containers/networks
.\down.ps1 solo-node

# Optional deep clean (remove local images + volumes)
.\clean.ps1 -Project solo-node -Deep
```
The compose project name automatically becomes `solo-node`, matching the
folder you created.

### Quick command reference
- **Start everything (already built):** `.\up.ps1 solo-node`
- **Start everything and rebuild:** `.\up.ps1 solo-node -Build`
- **Stop containers:** `.\down.ps1 solo-node`
- **Remove containers + networks:** `.\down.ps1 solo-node -Remove`
- **Delete images/volumes as well:** `.\clean.ps1 -Project solo-node -Deep`

You can also run Docker Compose directly from `projects/solo-node`:

```powershell
docker compose up -d                   # start all services
docker compose up -d --build           # rebuild then start
docker compose up -d bitcoind-main ckpool-solo-main     # start only mainnet pair
docker compose up -d bitcoind-testnet ckpool-solo-testnet # start only testnet pair
docker compose down                    # stop and remove containers/networks
```

### Viewing logs
Use the Docker Compose service names when tailing logs. Common ones are
`bitcoind-main`, `bitcoind-testnet`, `ckpool-solo-main`, and
`ckpool-solo-testnet`.

```powershell
docker compose logs -f bitcoind-main
docker compose logs -f ckpool-solo-main
docker compose logs -f bitcoind-testnet
docker compose logs -f ckpool-solo-testnet
```

When you prefer to stay in the repository root instead of `projects/solo-node`,
give Docker Compose the compose file path and project name explicitly:

```powershell
docker compose -f .\projects\solo-node\compose.yml -p solo-node logs -f bitcoin-main
docker compose -f .\projects\solo-node\compose.yml -p solo-node logs -f ckpool-main
docker compose -f .\projects\solo-node\compose.yml -p solo-node logs -f bitcoin-testnet
docker compose -f .\projects\solo-node\compose.yml -p solo-node logs -f ckpool-test
```

If you started the stack via `.\up.ps1`, the same service names apply when
using `docker logs -f <service>`.

## Notes
- The `clean.ps1`/`clean.cmd` scripts in `multi-compose-lab` already handle
  per-project cleanup; no changes are needed.
- If you update the `solo-node` repo later, rerun the `robocopy` command to sync
  the project folder and rebuild with `up.ps1 solo-node -Build`.