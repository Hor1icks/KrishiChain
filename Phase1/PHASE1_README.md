# KrishiChain — Phase 1 Package

Covers **Day 0 (environment proof)** and **Day 1 (ER finalization)** of the seven-day plan.

## Files

| File | Purpose |
|---|---|
| `00_environment_check.sql` | Five checks against your XE install + creates the app user |
| `test_connection.js` | Proves node-oracledb Thick mode reaches XE 11.2 |
| `ER_BLUEPRINT.md` | Every entity, attribute, relationship and cardinality — draw from this |
| `er_overview.svg` / `.png` | Structural map of all 23 entities and their relationships |
| `er_constructs.svg` / `.png` | Full Chen detail of the five graded constructs |
| `er_overview.dot` / `er_constructs.dot` | Graphviz sources, if you want to edit and re-render |

The SVGs scale cleanly — use those in the report, not the PNGs.

---

## Day 0 — run in this order

**Every team member does this on their own machine. Nobody writes code until it passes.**

**1. Confirm the XE build you installed.** Everyone should be on the same one. Windows 64-bit is the default recommendation. Check with `node -p "process.arch"` — if it says `x64`, you need 64-bit XE and 64-bit Instant Client.

**2. Run `00_environment_check.sql` as SYSTEM** in SQL Developer. Checks 1–4 run as SYSTEM; then reconnect as `krishichain` and run the Check 5 block. Record two results in the team chat:
- the `NLS_CHARACTERSET` value
- whether the virtual-column probe worked

**3. Install Oracle Instant Client 19c** (Basic or Basic Light). Unzip it somewhere stable — `C:\oracle\instantclient_19_26`. Do not put it in a OneDrive-synced folder.

**4. Run the driver proof:**
```
npm init -y
npm install oracledb
node test_connection.js
```

Edit `INSTANT_CLIENT_DIR` at the top of the file first. The script diagnoses the four errors you're most likely to hit, including `DPI-1047`, which reads like a missing file but is almost always a 32/64-bit mismatch.

**Why this matters:** node-oracledb's default Thin mode requires Oracle Database 12.1+. It cannot connect to 11.2 at all. Without `initOracleClient()` your entire backend fails at the first query, and the error message doesn't obviously point at the cause.

---

## Day 1 — redraw the ER diagram

Work from `ER_BLUEPRINT.md`. Use `er_overview` to get the structure right and `er_constructs` to get the five graded constructs drawn in correct Chen notation.

Draw it in **draw.io / diagrams.net** rather than by hand — you will revise this at least twice more before final submission, and redrawing on paper each time wastes hours.

Finish with the checklist in §3 of the blueprint. Every unticked box is lost marks.

---

## Decisions resolved in the current build

1. **`PHYSICAL_BAZAR` remains in scope.** It supports price comparison and owns
   the weak `BAZAR_DAILY_RECORD` entity.
2. **BR-20 follows delivery preference.** `ON_DELIVERY` payment waits for a
   delivered transport; `ADVANCE` payment may happen earlier.

---

## Implemented after Phase 1

`database/01_create_tables.sql` implements the approved model.
`database/01_schema_automation.sql` adds the matching Week-11 sequences and
ordinary indexes; `database/02_trigger_layer.sql` contains the 9 varied
triggers. See `UPDATE3.md` for the current build order and demonstration.
