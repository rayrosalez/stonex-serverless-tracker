# Serverless Migration Tracker

An AI/BI (Lakeview) dashboard that shows your **Databricks Jobs serverless‑migration progress**, built **entirely on Databricks system tables** — so it runs in your own workspace against your own data, with no external dependencies.

It classifies every job over a chosen window as:

**All‑Purpose** (job runs on an interactive cluster — worst case) → **Jobs‑Compute** (classic job cluster) → **Serverless** (target)

…and reports adoption %, spend, per‑Business‑Unit and per‑environment breakdowns, a velocity trend, and a per‑job backlog of what's still to migrate.

---

## What you get

- **Migration Tracker** page — headline KPIs (% serverless, job counts, spend), Top Opportunities, velocity trend, compute‑mix charts, a BU × compute‑type heatmap, and a BU scorecard.
- **BU Drill‑Down** page — per‑environment compute mix, a per‑job migration backlog (jobs still on All‑Purpose / Classic), and a list of jobs already on serverless.
- Global filters: **Date Range**, **Business Unit**, **Environment**.

## Data sources (all GA system tables)

| Table | Used for |
|---|---|
| `system.lakeflow.job_task_run_timeline` | per‑run compute type |
| `system.compute.clusters` | splits classic into All‑Purpose vs Jobs‑Compute (`cluster_source`) |
| `system.billing.usage` | serverless job counts, spend (DBUs) |
| `system.billing.list_prices` | DBU → dollar conversion |
| `system.lakeflow.jobs` | job names |
| `system.access.workspaces_latest` | workspace → Business Unit / environment mapping |

---

## Deploy

**Prerequisites**
- Databricks CLI v0.218+ authenticated to your workspace (`databricks auth login`).
- A SQL warehouse.
- `SELECT` on the system schemas above for the principal that runs the dashboard. (System tables are enabled per‑metastore by an account admin.)

**Option A — Databricks Asset Bundle (recommended)**
```bash
# 1. Edit databricks.yml: set workspace host
# 2. Deploy, passing your warehouse id
databricks bundle deploy -t prod --var="warehouse_id=<your_warehouse_id>"
```
The dashboard appears under **Dashboards** in your workspace. Open it and **Publish**.

**Option B — Import the file directly**
In the workspace UI: **Dashboards → Create → Import dashboard from file**, choose `src/serverless_tracker.lvdash.json`, then attach a SQL warehouse and Publish.

---

## Configure for your environment

### 1. Business‑Unit / environment mapping  *(the one thing you'll likely edit)*
Each dataset begins with a `ws` CTE that maps `workspace_name` → Business Unit + environment. It ships with a naming‑convention mapping; adjust the `CASE` statements to match your workspaces. The same block appears in every file under `datasets/` and is embedded in the dashboard — the readable copies in `datasets/*.sql` are the source of truth if you regenerate.

If you tag resources with a Business Unit instead of encoding it in the workspace name, switch the mapping to read `system.billing.usage.custom_tags['<your_bu_tag>']`.

Workspaces that don't match any rule fall into **`Unmapped`** and are excluded from the per‑BU views (they're still counted in account‑level totals).

### 2. Spend figures
Spend is computed as **DBUs × list price** — i.e. a **list‑price estimate**. To reflect your negotiated/effective rate, open `datasets/spend_kpi.sql` and change the `* 1.0` multiplier to your effective $/DBU.

---

## Notes & limitations

- **All‑Purpose spend** is shown as **total all‑purpose compute** (cluster‑level), labeled as such — system tables don't attribute interactive‑cluster cost to individual jobs, so this is an upper bound, not a job‑attributed figure. **Job counts** on All‑Purpose are exact.
- **Account scope.** System tables are scoped to a single account/metastore. If your estate spans multiple Databricks accounts, deploy one copy per account (or confirm a shared metastore), otherwise each copy only sees its own account's workspaces.
- **Account‑level KPIs vs per‑BU views.** Headline KPIs count all workspaces; per‑BU widgets exclude `Unmapped` ones, so the scorecard won't necessarily sum to the headline totals.
- **Freshness.** System‑table data lags real‑time by up to a few hours. Schedule a dashboard refresh to keep it warm.

## Repo layout
```
databricks.yml                      # Asset Bundle definition
src/serverless_tracker.lvdash.json  # the dashboard
datasets/*.sql                      # readable copy of each dataset query
```
