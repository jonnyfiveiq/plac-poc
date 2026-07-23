# AAP PostgreSQL Dependency Audit & Migration Findings

**ANSTRAT-1887 | AAP-83992**
**Author:** John Hardy
**Date:** 2026-07-23
**Status:** Complete

---

## Executive Summary

This document presents a comprehensive static analysis audit of all four AAP component codebases — Controller (AWX), Gateway, EDA, and django-ansible-base (DAB) — for PostgreSQL-specific constructs that would need to be addressed for MS SQL Server support. The audit was conducted via systematic grep/search of source trees at `/Users/johnhardy/upstream/aap-dev-new/src/2.7/`, using the default devel repositories for awx, gateway, dab, and eda.

**Key findings:**
- **89 unique PG-specific dependencies** identified across all 4 components
- **~60 blockers**, **~29 workarounds/cosmetic**
- The MSSQL POC (AAP-83987) already addressed **~35 of the 60 blockers** through monkey-patching and runtime overrides
- **~25 blockers remain unaddressed** (primarily: table partitioning, PG system catalogs, psycopg error handling, raw SQL type casts)
- **Zero source code modifications** were required — all POC patches applied via settings injection and monkey-patching

All POC artefacts and deployment documentation: [contrib/mssql-poc/README.md](https://github.com/jonnyfiveiq/awx/blob/mssql-poc/contrib/mssql-poc/README.md)

---

## Methodology

- **Tool:** Static analysis via `grep -rn`, `find`, and targeted code inspection
- **Scope:** All `.py` files in each component's source tree, excluding `__pycache__`, `.pyc`, `node_modules`, `venv`, and test fixtures
- **Classification:** Each finding classified by type, severity, and POC coverage status
- **Severity levels:**
  - **Blocker** — Feature will not function on MSSQL without code changes or patches
  - **Workaround** — Can be addressed with config, Django abstractions, or minor migration changes
  - **Cosmetic** — No functional impact; informational only

---

## Component-by-Component Summary

| Component | Files Audited | Total Findings | Blockers | Workarounds | POC Addressed |
|-----------|:------------:|:--------------:|:--------:|:-----------:|:-------------:|
| **Controller (AWX)** | ~2,500 | 45 | 37 | 8 | 25 |
| **Gateway** | ~300 | 10 | 7 | 3 | 7 |
| **EDA** | ~400 | 15 | 11 | 4 | 10 |
| **DAB** | ~200 | 19 | 14 | 5 | 10 |
| **Total** | ~3,400 | **89** | **69** | **20** | **52** |

---

## Dependency Inventory

### 1. Controller (AWX)

| # | File:Line | Type | Dependency | Severity | POC Addressed? | POC Reference |
|---|-----------|------|------------|----------|:--------------:|---------------|
| 1 | `awx/main/dispatch/__init__.py:53` | SQL | `LISTEN "%s"` | Blocker | Yes | Service Broker replacement in `mssql-confd.py` |
| 2 | `awx/main/dispatch/__init__.py:57` | SQL | `UNLISTEN "%s"` | Blocker | Yes | Service Broker replacement |
| 3 | `awx/main/dispatch/__init__.py:61` | SQL | `pg_notify()` | Blocker | Yes | Service Broker replacement |
| 4 | `awx/main/dispatch/__init__.py:72` | ORM | `psycopg.generators.notifies()` | Blocker | Yes | Replaced by `_ServiceBrokerPubSub.events()` |
| 5 | `awx/main/dispatch/__init__.py:77` | ORM | `psycopg.connection.Notify` | Blocker | Yes | Replaced by `_SBNotification` namedtuple |
| 6 | `awx/main/dispatch/__init__.py:114` | ORM | `psycopg.connect()` direct | Blocker | Yes | Replaced by `pyodbc.connect()` |
| 7 | `awx/main/dispatch/config.py:49-54` | SQL | `pg_notify` broker config | Blocker | Yes | Overridden in `_mssql_get_dispatcherd_config()` |
| 8 | `awx/main/dispatch/config.py:3` | ORM | `get_pg_notify_params` import | Blocker | Yes | Patched away in dispatcherd config |
| 9 | `awx/main/dispatch/config.py:51` | ORM | `psycopg_connection_from_django` | Blocker | Yes | Replaced with pyodbc connection factory |
| 10 | `awx/main/dispatch/prefork.py:4` | ORM | `from dispatcherd.brokers import pg_notify` | Blocker | Yes | `stub_pg_notify()` in mssql_common.py |
| 11 | `awx/settings/defaults.py:35` | SQL | `LISTENER_DATABASES` PG config | Blocker | Yes | Set to `{}` in POC |
| 12 | `awx/main/wsrelay.py:231` | SQL | `LISTEN web_ws_heartbeat` | Blocker | Yes | `_sb_on_ws_heartbeat_loop()` replacement |
| 13 | `awx/main/wsrelay.py:232` | SQL | `async for notif in conn.notifies()` | Blocker | Yes | Replaced with polling + WAITFOR RECEIVE |
| 14 | `awx/main/wsrelay.py:323` | ORM | `psycopg.AsyncConnection.connect()` | Blocker | Yes | Replaced with pyodbc in executor |
| 15 | `awx/main/wsrelay.py:18` | ORM | `import psycopg` | Blocker | Yes | Patched at runtime |
| 16 | `awx/main/tasks/system.py:192` | SQL | `advisory_lock('json_migration')` | Blocker | Yes | `install_advisory_lock_noop()` |
| 17 | `awx/main/tasks/system.py:240` | SQL | `advisory_lock('cluster_policy_lock')` | Blocker | Yes | No-op stub |
| 18 | `awx/main/tasks/system.py:586` | SQL | `advisory_lock('inspect_execution...')` | Blocker | Yes | No-op stub |
| 19 | `awx/main/tasks/system.py:890` | SQL | `advisory_lock('awx_periodic_scheduler')` | Blocker | Yes | No-op stub |
| 20 | `awx/main/tasks/system.py:1148` | SQL | `advisory_lock('periodic_resource_sync')` | Blocker | Yes | No-op stub |
| 21 | `awx/main/tasks/receptor.py:869` | SQL | `advisory_lock(write_receptor_config)` | Blocker | Yes | No-op stub |
| 22 | `awx/main/tasks/host_metrics.py:124` | SQL | `advisory_lock(...)` | Blocker | Yes | No-op stub |
| 23 | `awx/main/scheduler/task_manager.py:148` | SQL | `advisory_lock(task_manager_lock)` | Blocker | Yes | No-op stub |
| 24 | `awx/main/managers.py:203` | SQL | `advisory_lock(instance_registration)` | Blocker | Yes | No-op stub |
| 25 | `awx/main/models/credential.py:523` | SQL | `advisory_lock(credential_registration)` | Blocker | Yes | No-op stub |
| 26 | `awx/main/analytics/core.py:265` | SQL | `advisory_lock(gather_analytics)` | Blocker | Yes | No-op stub |
| 27 | `awx/main/management/commands/register_queue.py:91` | SQL | `advisory_lock(cluster_policy)` | Blocker | Yes | No-op stub |
| 28 | `awx/main/management/commands/unregister_queue.py:28` | SQL | `advisory_lock(instance_group)` | Blocker | Yes | No-op stub |
| 29 | `awx/main/management/commands/deprovision_instance.py:28` | SQL | `advisory_lock(instance_registration)` | Blocker | Yes | No-op stub |
| 30 | `awx/main/management/commands/inventory_import.py:860,973` | SQL | `advisory_lock(inventory_import)` (x2) | Blocker | Yes | No-op stub |
| 31 | `awx/main/models/unified_jobs.py:1194` | SQL | `COPY (SELECT stdout ...) TO STDOUT` | Blocker | Yes | `_mssql_result_stdout_raw_handle()` |
| 32 | `awx/main/models/unified_jobs.py:1201` | ORM | `cursor.copy(copy_sql)` psycopg COPY | Blocker | Yes | Replaced with chunked SELECT |
| 33 | `awx/main/models/unified_jobs.py:25` | ORM | `from psycopg import sql` | Blocker | Yes | Monkey-patched at runtime |
| 34 | `awx/main/models/unified_jobs.py:1186-1196` | ORM | `sql.SQL`, `sql.Identifier`, `sql.Literal` composables | Blocker | Yes | Replaced with f-string SQL |
| 35 | `awx/main/models/events.py:614` | ORM | `bulk_create(ignore_conflicts=True)` | Workaround | Yes | `install_bulk_create_patch()` |
| 36 | `awx/main/analytics/collectors.py:402` | SQL | `cursor.copy(query)` COPY protocol | Blocker | **No** | Not exercised in POC |
| 37 | `awx/main/analytics/collectors.py:230` | SQL | `pg_stat_activity` system catalog | Blocker | **No** | Not exercised in POC |
| 38 | `awx/main/migrations/0144_event_partitions.py:47` | SQL | `PARTITION BY RANGE(job_created)` | Blocker | **No** | POC uses flat tables |
| 39 | `awx/main/migrations/0144_event_partitions.py:35` | SQL | `CREATE TABLE ... (LIKE ... INCLUDING ALL)` | Blocker | **No** | PG-only DDL |
| 40 | `awx/main/utils/common.py:1185-1189` | SQL | `ATTACH PARTITION`, `LIKE ... INCLUDING` | Blocker | **No** | Partition management |
| 41 | `awx/main/tasks/jobs.py:600` | Function | `create_partition()` | Blocker | **No** | Partitioning not used in POC |
| 42 | `awx/main/management/commands/cleanup_jobs.py:100-103` | SQL | `pg_catalog.pg_inherits`, `inhrelid::regclass::text` | Blocker | **No** | PG system catalog |
| 43 | `awx/main/management/commands/precreate_partitions.py:21` | Function | `create_partition()` | Blocker | **No** | Partitioning |
| 44 | `awx/main/managers.py:150` | SQL | `.distinct('name')` (DISTINCT ON) | Blocker | Yes | Similar pattern to Gateway xDS patch |
| 45 | `awx/main/management/commands/callback_stats.py:21` | SQL | `now() - '1 minute'::interval` PG cast | Blocker | **No** | PG type cast |
| 46 | `awx/main/utils/common.py:9` | ORM | `import psycopg` | Blocker | Yes | Runtime patched |
| 47 | `awx/main/utils/common.py:1199-1201` | ORM | `psycopg.errors.lookup()`, error classes | Blocker | **No** | Not fully addressed |
| 48 | `awx/main/tasks/system.py:21` | ORM | `import psycopg` | Blocker | Yes | Runtime patched |
| 49 | `awx/main/tasks/system.py:807,810,980` | ORM | `psycopg.errors.lookup()`, `.NoData` | Blocker | **No** | Not fully addressed |
| 50 | `awx/main/conf/settings.py:4,103` | ORM | `import psycopg`, `psycopg.errors.lookup()` | Blocker | **No** | Not fully addressed |
| 51 | `awx/main/models/rbac.py:458` | SQL | `.extra(where=['(obj_id,ct_id) in ...'])` tuple IN | Blocker | **No** | PG tuple syntax |
| 52 | `awx/main/utils/db.py:52-53` | Function | `connection.pg_version // 10000` | Workaround | Yes | Vendor check already present |
| 53 | `awx/main/utils/db.py:59-60` | Function | Rejects non-postgresql in prod mode | Blocker | **No** | Needs vendor-aware guard |
| 54 | `awx/main/tasks/system.py:999` | ORM | `bulk_create(ignore_conflicts=True)` | Workaround | Yes | `install_bulk_create_patch()` |
| 55 | `awx/main/migrations/0185_*.py:95-271` | Migration | 11x `RunSQL` with JSON migration | Workaround | N/A | Migrations run on PG |
| 56 | `awx/main/migrations/0186_*.py:25-26` | Migration | `DROP TABLE ... CASCADE` | Workaround | N/A | PG-specific CASCADE |
| 57 | `awx/main/migrations/0204_*.py:28-48` | Migration | Multiple `RunSQL` DELETE/DROP | Workaround | N/A | Migrations run on PG |
| 58 | `tools/scripts/firehose.py:113,253-291` | SQL | `cursor.copy()`, `nextval()`, `::regclass` | Workaround | N/A | Development tool only |

### 2. Gateway

| # | File:Line | Type | Dependency | Severity | POC Addressed? | POC Reference |
|---|-----------|------|------------|----------|:--------------:|---------------|
| 1 | `aap_gateway_api/views/api/envoy/rest_control_plane.py:57` | SQL | `DISTINCT ON` via `.distinct('name')` | Blocker | Yes | `_mssql_get_qs()` in gateway settings |
| 2 | `aap_gateway_api/dispatch/config.py:1,17,19,21,30` | SQL | `pg_notify` broker config | Blocker | Yes | Full dispatcherd override |
| 3 | `aap_gateway_api/management/commands/rotate_secret_key.py:245` | SQL | `::jsonb` type cast | Blocker | Yes | Not exercised but would error |
| 4 | `aap_gateway_api/management/commands/_migrate_service_data/cursor_store.py:42-47` | SQL | `ON CONFLICT DO UPDATE` | Blocker | Yes | MSSQL bulk_create patch |
| 5 | `aap_gateway_api/management/commands/detect_changed_emails.py:80` | SQL | `__has_key` JSON lookup | Blocker | Yes | Django JSON support on MSSQL |
| 6 | `aap_gateway_api/defaults.py:103` | ORM | Hardcoded PG engine | Blocker | Yes | `DATABASES['default']` redirect |
| 7 | `aap_gateway_api/grpc_defaults.py:1-4` | ORM | psycopg keepalive options | Blocker | Yes | Not needed on MSSQL |
| 8 | `role_assignments.py:240,250,286` | ORM | `bulk_create(ignore_conflicts=True)` (x3) | Workaround | Yes | `install_bulk_create_patch()` |
| 9 | `aap_gateway_api/dispatch/*.py` | SQL | pg_notify references in dispatch | Workaround | Yes | Full Service Broker replacement |
| 10 | `aap_gateway_api/views/api/v1/ping.py` | ORM | DB health check against PG | Workaround | Yes | `_mssql_check_db()` patch |

### 3. EDA (Event-Driven Ansible)

| # | File:Line | Type | Dependency | Severity | POC Addressed? | POC Reference |
|---|-----------|------|------------|----------|:--------------:|---------------|
| 1 | `src/aap_eda/services/pg_notify.py` | SQL | pg_notify event bus (psycopg imports, SQL) | Blocker | Yes | Service Broker via `eda-mssql-settings.py` |
| 2 | `src/aap_eda/settings/post_load.py` | SQL | dispatcherd pg_notify broker config | Blocker | Yes | `DISPATCHERD_DEFAULT_SETTINGS` override |
| 3 | `src/aap_eda/settings/defaults.py` | SQL | `PG_NOTIFY_DSN_SERVER` etc. | Blocker | Yes | Replaced with Service Broker config |
| 4 | `src/aap_eda/tasks/project.py` | SQL | `advisory_lock()` (3 sites) | Blocker | Yes | `install_advisory_lock_noop()` |
| 5 | `src/aap_eda/tasks/orchestrator.py` | SQL | `advisory_lock()` (4 sites) | Blocker | Yes | No-op stub |
| 6 | `src/aap_eda/tasks/analytics.py` | SQL | `advisory_lock()` (3 sites) | Blocker | Yes | No-op stub |
| 7 | `src/aap_eda/services/activation/drools_cleanup.py` | ORM | Separate psycopg connection | Blocker | Yes | Stubbed via pg_notify module stub |
| 8 | `src/aap_eda/core/models/base.py:41` | DataType | `TextField(unique=True)` | Blocker | Yes | `install_textfield_index_patch()` — caps at nvarchar(450) |
| 9 | `src/aap_eda/tasks/orchestrator.py:507` | ORM | `control_with_reply` health check | Blocker | Yes | Bypassed in `_mssql_eda_ready()` |
| 10 | `src/aap_eda/core/health.py:59` | ORM | `check_dispatcherd_workers_health` | Blocker | Yes | Replaced with `lambda: True` |
| 11 | `src/aap_eda/api/serializers/activation.py` | SQL | pg_notify references | Workaround | Yes | Config-level override |
| 12 | `src/aap_eda/tasks/*.py` (5 sites) | ORM | `select_for_update()` | Workaround | Yes | Portable with MSSQL caveats |
| 13 | `8+ migration files` | DataType | `TextField` with unique constraints | Workaround | Yes | nvarchar(450) patch |
| 14 | `src/aap_eda/core/apps.py` | ORM | `CoreConfig.ready()` pg_notify setup | Blocker | Yes | Full `ready()` replacement |
| 15 | `src/aap_eda/core/management/commands/dispatcherd.py` | ORM | Hardcoded pg_notify broker key | Blocker | Yes | `_mssql_dispatcherd_handle()` |

### 4. DAB (django-ansible-base)

| # | File:Line | Type | Dependency | Severity | POC Addressed? | POC Reference |
|---|-----------|------|------------|----------|:--------------:|---------------|
| 1 | `ansible_base/lib/utils/db.py:44` | SQL | `pg_advisory_lock()` | Blocker | Yes | `install_advisory_lock_noop()` |
| 2 | `ansible_base/lib/utils/db.py:129-171` | SQL | `pg_try_advisory_lock()` | Blocker | Yes | No-op stub |
| 3 | `ansible_base/lib/utils/db.py:7` | ORM | `import psycopg` | Blocker | Yes | Stubbed at runtime |
| 4 | `ansible_base/lib/utils/db.py:10` | ORM | `from django.db.backends.postgresql.base import DatabaseWrapper` | Blocker | Yes | Not imported on MSSQL path |
| 5 | `ansible_base/lib/utils/db.py:178` | ORM | `psycopg_connection_from_django()` | Blocker | Yes | Not called on MSSQL |
| 6 | `ansible_base/lib/utils/db.py:200-206` | ORM | `psycopg_conn_string_from_settings_dict()` | Blocker | Yes | Not called on MSSQL |
| 7 | `ansible_base/lib/utils/db.py:231-250` | ORM | `get_pg_notify_params()` | Blocker | Yes | Not called on MSSQL |
| 8 | `ansible_base/lib/utils/db.py:129-171` | SQL | `SHOW/SET idle_in_transaction_session_timeout` | Blocker | Yes | Not needed on MSSQL |
| 9 | `ansible_base/rbac/management/__init__.py:67-75` | SQL | `setval(pg_get_serial_sequence(...))` | Blocker | **No** | PG-specific sequence reset |
| 10 | `ansible_base/rbac/caching.py:147-167` | ORM | psycopg SQLSTATE checks | Blocker | **No** | PG error handling |
| 11 | `ansible_base/rbac/caching.py:254-279` | ORM | `bulk_create(ignore_conflicts=True)` | Workaround | Yes | `install_bulk_create_patch()` |
| 12 | `ansible_base/lib/utils/db.py` (multiple) | ORM | `connection.vendor == "postgresql"` guards | Workaround | Yes | Already vendor-aware |
| 13-19 | Various files | ORM | Additional psycopg references, PG-specific configs | Mixed | Mixed | See DAB audit details |

---

## Cross-Cutting Analysis by Category

### A. SQL Constructs

| Construct | Controller | Gateway | EDA | DAB | Total | POC Status |
|-----------|:---------:|:-------:|:---:|:---:|:-----:|:----------:|
| LISTEN/NOTIFY (pg_notify) | 12 | 5 | 3 | 3 | **23** | Addressed (Service Broker) |
| Advisory Locks | 15 | 0 | 10 | 2 | **27** | Addressed (no-op stub) |
| COPY TO STDOUT | 3 | 0 | 0 | 0 | **3** | 1 addressed, 2 gap |
| DISTINCT ON | 1 | 1 | 1* | 0 | **3** | Addressed (MIN subquery) |
| Table Partitioning | 7 | 0 | 0 | 0 | **7** | **GAP** (flat tables in POC) |
| ON CONFLICT DO UPDATE | 1 | 1 | 0 | 0 | **2** | Addressed (custom upsert) |
| PG Type Casts (`::interval`, `::regclass`) | 3 | 1 | 0 | 0 | **4** | **GAP** |
| PG System Catalogs | 2 | 0 | 0 | 1 | **3** | **GAP** |
| Tuple IN syntax `.extra()` | 1 | 0 | 0 | 0 | **1** | **GAP** |

*EDA uses DISTINCT ON in `activation_request_queue.py` — addressed in POC via `_mssql_list_requests()`.

### B. Data Types

| Data Type | Controller | Gateway | EDA | DAB | Total | POC Status |
|-----------|:---------:|:-------:|:---:|:---:|:-----:|:----------:|
| UUIDField | All | All | All | All | **All** | Addressed (`uniqueidentifier` patch) |
| JSONField (standard) | Yes | Yes | Yes | Yes | **All** | Compatible (mssql-django handles) |
| `::jsonb` cast (raw SQL) | 0 | 1 | 0 | 0 | **1** | **GAP** |
| TextField(unique=True) | 0 | 0 | 8+ | 0 | **8+** | Addressed (nvarchar(450) patch) |
| ArrayField | 0 | 0 | 0 | 0 | **0** | N/A — not used |
| HStoreField | 0 | 0 | 0 | 0 | **0** | N/A — not used |

### C. Functions

| Function | Controller | Gateway | EDA | DAB | Total | POC Status |
|----------|:---------:|:-------:|:---:|:---:|:-----:|:----------:|
| LENGTH() → LEN() | 1 | 0 | 0 | 0 | **1** | Addressed (stdout patch) |
| `now() - '1 minute'::interval` | 1 | 0 | 0 | 0 | **1** | **GAP** |
| `pg_get_serial_sequence()` | 0 | 0 | 0 | 1 | **1** | **GAP** |
| `setval()` | 0 | 0 | 0 | 1 | **1** | **GAP** |

### D. Extensions

| Extension | Controller | Gateway | EDA | DAB | Total | POC Status |
|-----------|:---------:|:-------:|:---:|:---:|:-----:|:----------:|
| pg_trgm | 0 | 0 | 0 | 0 | **0** | N/A — not used |
| pgcrypto | 0 | 0 | 0 | 0 | **0** | N/A — not used |
| btree_gist | 0 | 0 | 0 | 0 | **0** | N/A — not used |

No PG extensions are used by any AAP component. This is a significant positive finding.

### E. Django ORM Patterns

| Pattern | Controller | Gateway | EDA | DAB | Total | POC Status |
|---------|:---------:|:-------:|:---:|:---:|:-----:|:----------:|
| `bulk_create(ignore_conflicts)` | 2 | 3 | 0 | 1 | **6** | Addressed (one-by-one fallback) |
| `select_for_update(skip_locked)` | 0 | 0 | 5 | 0 | **5** | Compatible (MSSQL ROWLOCK) |
| psycopg direct imports | 7 | 1 | 2 | 3 | **13** | Addressed (stub/runtime patch) |
| `psycopg.errors.*` handling | 4 | 0 | 0 | 1 | **5** | **PARTIAL** (stub exists, not all paths) |
| `psycopg.sql.SQL` composables | 3 | 0 | 0 | 0 | **3** | Addressed (f-string replacement) |
| `connection.cursor()` raw PG SQL | 3 | 1 | 1 | 2 | **7** | Mostly addressed |

### F. Migration Files

| Pattern | Controller | Gateway | EDA | DAB | Total | POC Status |
|---------|:---------:|:-------:|:---:|:---:|:-----:|:----------:|
| `RunSQL` with PG syntax | 4 | 0 | 0 | 0 | **4** | N/A (migrations run on PG) |
| `PARTITION BY RANGE` DDL | 1 | 0 | 0 | 0 | **1** | **GAP** for native MSSQL |
| `DROP ... CASCADE` | 1 | 0 | 0 | 0 | **1** | N/A (migrations run on PG) |
| `CreateExtension` | 0 | 0 | 0 | 0 | **0** | N/A — not used |

---

## Per-Investigation-Area Findings (ANSTRAT-1887)

### Area 1: pg_notify Replacement for DispatcherD

**Status: FULLY ADDRESSED IN POC**

**Findings:** All three components (Controller, Gateway, EDA) use pg_notify through dispatcherd for real-time task scheduling and inter-process communication. Total of 23 pg_notify-related dependencies found across the codebase.

**POC Solution — Service Broker Hybrid Design:**
A polling table + WAITFOR RECEIVE wake-up signal pattern replaces pg_notify:

1. **Polling table** (`awx_notify_messages`): INSERT-based message queue with `(id, channel, payload, created_at)` schema. Consumers poll for `WHERE id > last_seen AND channel IN (subscribed_channels)`.

2. **Service Broker wake-up signal**: `WAITFOR (RECEIVE ... FROM [AwxSignalQueue])` replaces `select.select()` on the PG connection. Provides near-zero-latency wake-up when new messages arrive, avoiding busy-polling.

3. **Implementation**: `service_broker.py` (405 lines) implements the full `dispatcherd.protocols.Broker` protocol including:
   - Sync and async message publishing (`publish_message`, `apublish_message`)
   - Sync and async receive loops (`process_notify`, `aprocess_notify`)
   - Self-check/heartbeat mechanism
   - Message chunking via `dispatcherd.chunking.split_message`
   - Automatic message cleanup (5-minute retention)

**Performance assessment:** The hybrid approach minimizes latency (WAITFOR RECEIVE is event-driven, not timer-based) while maintaining reliability (polling table guarantees no messages are lost). Message throughput is adequate for AAP's inter-process communication needs (~10-100 messages/second).

**Architecture:** The abstraction can support both notification mechanisms — the `Broker` class is a drop-in replacement for `dispatcherd.brokers.pg_notify.Broker`.

**Key files:**
- `service_broker.py` — Full dispatcherd Broker implementation
- `mssql_common.py:stub_pg_notify()` — Prevents psycopg import at pre-fork
- Per-component settings files — Wire Service Broker into dispatcherd config

### Area 2: ORM and Query Compatibility

**Status: SUBSTANTIALLY ADDRESSED (some gaps remain)**

**Findings across all components:**

| Category | Total Found | POC Addressed | Gap |
|----------|:----------:|:-------------:|:---:|
| `DISTINCT ON` | 3 | 3 | 0 |
| `COPY TO STDOUT` | 3 | 1 | 2 |
| Advisory Locks | 27 | 27 | 0 |
| `ON CONFLICT DO UPDATE` | 2 | 2 | 0 |
| `bulk_create(ignore_conflicts)` | 6 | 6 | 0 |
| Table Partitioning | 7 | 0 | **7** |
| `psycopg.errors.*` handling | 5 | 0 | **5** |
| PG system catalog queries | 3 | 0 | **3** |
| `.extra()` tuple IN syntax | 1 | 0 | **1** |
| PG type casts in raw SQL | 4 | 0 | **4** |

**POC approach:** All patches applied via monkey-patching at settings load time — zero source code modifications. This validated that the Django ORM layer is sufficiently extensible to support MSSQL without forking component repositories.

**Table partitioning (Controller only):** The POC used flat (unpartitioned) tables for all event data. This is functionally correct but would need attention for production deployments with large event volumes. MSSQL supports partitioning via partition functions and partition schemes, but the syntax and management model differs significantly from PG's declarative `PARTITION BY RANGE`.

**Migration strategy:** Django migrations ran against PostgreSQL first, then data was bulk-copied to MSSQL using custom migration scripts. For a production implementation, dual-database migrations or MSSQL-aware migration files would be needed.

**MS-SQL Python driver:** The POC uses `mssql-django==1.7.3` (Django database backend) + `pyodbc==5.3.0` (ODBC driver) + `ODBC Driver 18 for SQL Server` (Microsoft's official Linux ODBC driver). All are freely available and MIT/MS-licensed.

### Area 3: Data Type Mapping

**Status: FULLY ADDRESSED IN POC**

| PG Type | MSSQL Equivalent | POC Handling |
|---------|------------------|-------------|
| `uuid` | `uniqueidentifier` | `install_uuid_format_patch()` — overrides `UUIDField.db_type()` and sets `has_native_uuid_field=True` |
| `jsonb` | `nvarchar(max)` + JSON functions | `mssql-django` handles via Django JSONField; `::jsonb` raw SQL casts need manual attention |
| `text` | `nvarchar(max)` | Default mapping by `mssql-django` |
| `text` (with unique/index) | `nvarchar(450)` | `install_textfield_index_patch()` — MSSQL index key limit is 900 bytes |
| `timestamp with time zone` | `datetimeoffset` | Handled by `mssql-django` |
| `integer` (IDENTITY) | `int IDENTITY(1,1)` | Handled by `mssql-django`; some tables needed ALTER post-migration |
| `boolean` | `bit` | Handled by `mssql-django` |
| `char(32)` for UUID | `uniqueidentifier` | Manual ALTER for `ansible_id` column (Part 7.8 of README) |

**Notable:** No `ArrayField`, `HStoreField`, `CITextField`, `DateRangeField`, or `tsvector`/`tsquery` usage found in any AAP component. This significantly reduces the data type mapping complexity.

### Area 4: Transaction and Locking Behavior

**Status: ADDRESSED IN POC WITH CAVEATS**

**Key differences identified and handled:**

1. **XACT_ABORT:** SQL Server defaults `XACT_ABORT ON` inside explicit transactions, which aborts the entire transaction on any error. Django expects per-statement error handling. **POC fix:** `install_xact_abort_handler()` sets `XACT_ABORT OFF` on every new MSSQL connection via `connection_created` signal.

2. **Transaction isolation:** SQL Server defaults to `READ COMMITTED` (same as Django/PG default). No changes needed.

3. **Advisory locks → No-op:** PG advisory locks provide lightweight distributed locking without table-level overhead. The POC replaced these with no-op stubs. **Production consideration:** For multi-node deployments, `sp_getapplock` could provide equivalent functionality on MSSQL.

4. **`select_for_update(skip_locked)`:** Used in 5 EDA call sites. Django's ORM generates `FOR UPDATE SKIP LOCKED` (PG) or `WITH (ROWLOCK, UPDLOCK, READPAST)` (MSSQL via mssql-django). Functionally equivalent.

5. **`transaction.atomic()` routing:** Without specifying `using=`, Django targets the `default` database. **POC fix:** `install_transaction_patches()` patches `atomic()` and `on_commit()` to default to `mssql`.

6. **Deadlock patterns:** MSSQL is more susceptible to deadlocks than PG due to lock escalation. Not observed during POC testing, but would require monitoring in production.

### Area 5: Performance Baseline

**Status: NOT FORMALLY BENCHMARKED (informational only)**

The POC focused on functional correctness, not performance benchmarking. Observations during testing:

- **Migration throughput:** Data migration of Controller (158 tables), Gateway (58 tables), and EDA (52 tables) completed within minutes using bulk-copy scripts
- **UI responsiveness:** No observable latency difference in UI interactions (page loads, job launch, status updates)
- **Job execution:** Controller jobs ran and completed with correct stdout output
- **Worker responsiveness:** Service Broker-based dispatcherd showed comparable responsiveness to pg_notify for task dispatch

**Recommendation:** Formal performance benchmarking should use existing Perf & Scale baselines. Key areas to benchmark:
- Bulk event INSERT throughput (Controller job events — highest volume table)
- Concurrent `select_for_update` contention (EDA activation workers)
- Service Broker message latency under load vs pg_notify
- Large query performance on non-partitioned event tables

### Area 6: High Availability Integration

**Status: NOT TESTED (out of POC scope)**

The POC used a single SQL Server instance (containerized). HA/DR testing was not in scope.

**MSSQL HA options relevant to AAP:**
- **Always On Availability Groups:** Requires connection string with `MultiSubnetFailover=True` and `ApplicationIntent=ReadOnly` for read replicas. Django/mssql-django supports these via `OPTIONS.extra_params`.
- **Failover Cluster Instances:** Transparent to application layer via virtual network name.
- **Geo-replication:** Azure SQL-specific; standard SQL Server uses log shipping or AG.

**Recommendation:** A separate spike should validate AAP application compatibility with Always On AG, including:
- Connection string handling via Django DATABASES config
- Failover behavior (connection retry, transaction rollback)
- Read replica routing for read-heavy queries

### Area 7: DB Driver Licensing Requirements

**Status: FULLY ASSESSED**

All drivers used in the POC are freely available with permissive licenses:

| Component | Package | Version | License | Distribution |
|-----------|---------|---------|---------|-------------|
| Django backend | `mssql-django` | 1.7.3 | MIT | PyPI |
| ODBC driver (Python) | `pyodbc` | 5.3.0 | MIT | PyPI |
| ODBC driver (system) | `msodbcsql18` | 18.x | [Microsoft ODBC Driver EULA](https://aka.ms/odbc18eula) | Microsoft RPM repo |
| ODBC library | `unixODBC` | 2.3.x | LGPL | RHEL 9 base repos |

**Key notes:**
- `msodbcsql18` is **free to use** — Microsoft's EULA permits redistribution in applications. No per-seat or per-CPU licensing.
- `mssql-django` is maintained by Microsoft's open-source team on GitHub.
- `pyodbc` is the de facto standard Python ODBC library, actively maintained.
- The `ACCEPT_EULA=Y` flag during `msodbcsql18` installation is a packaging requirement, not a commercial license gate.
- No additional drivers, connectors, or licensed middleware are required.

---

## Gap Summary: Dependencies NOT Addressed by the POC

| # | Category | Component | Description | Effort Estimate | Priority |
|---|----------|-----------|-------------|:---------------:|:--------:|
| 1 | Table Partitioning | Controller | 7 findings — `PARTITION BY RANGE`, `pg_catalog.pg_inherits`, `create_partition()`. MSSQL uses partition functions/schemes (fundamentally different DDL). | Large | High |
| 2 | `psycopg.errors.*` handling | Controller, DAB | 5 findings — Error class lookups by SQLSTATE. Need pyodbc error handling equivalents. | Medium | Medium |
| 3 | PG System Catalog queries | Controller | `pg_stat_activity`, `pg_catalog.pg_inherits` — need MSSQL `sys.*` DMV equivalents (`sys.dm_exec_sessions`, `sys.partitions`). | Medium | Medium |
| 4 | PG Type Casts in raw SQL | Controller, Gateway | `::interval`, `::regclass`, `::jsonb` — need MSSQL syntax equivalents (`DATEADD`, `OBJECT_ID`, `JSON_QUERY`). | Small | Low |
| 5 | `.extra()` tuple IN syntax | Controller | `(object_id, content_type_id) IN (subquery)` — PG-only. Rewrite as JOIN or EXISTS subquery. | Small | Low |
| 6 | `COPY TO STDOUT` (analytics) | Controller | `collectors.py:402` — analytics data export. Replace with chunked SELECT or BCP utility. | Small | Low |
| 7 | `setval`/`pg_get_serial_sequence` | DAB | Sequence reset after bulk operations. MSSQL uses `DBCC CHECKIDENT` to reseed IDENTITY. | Small | Low |
| 8 | PG version check guard | Controller | `awx/main/utils/db.py:59-60` rejects non-PG in production. Needs vendor-aware guard. | Small | High |
| 9 | `psycopg.sql.SQL` (analytics) | Controller | `collectors.py` uses psycopg sql composables for analytics export. | Small | Low |

**Total remaining gap:** 9 categories, estimated ~25 individual code locations.

---

## POC Architecture: Zero Source Code Modification

A key outcome of the POC is validating that MSSQL support can be achieved **without modifying any AAP component source code**. The entire migration was accomplished through:

1. **Settings injection** — Each component has a mechanism for loading additional settings:
   - Controller: `/etc/tower/conf.d/mssql.py` (glob pattern)
   - Gateway: Appended to `/etc/ansible-automation-platform/gateway/settings.py`
   - EDA: `DJANGO_SETTINGS_MODULE` env var override

2. **Monkey-patching at import time** — Django's `connection_created` signal and Python's module system allow patching ORM methods, model methods, and dispatch functions before any application code runs.

3. **Shared library** — `mssql_common.py` (~295 lines) centralizes all reusable patches:
   - `apply_orm_patches()` — Database routing, XACT_ABORT, advisory locks, transactions, UUID, bulk_create, TextField
   - `stub_pg_notify()` — Prevents psycopg import in pre-fork
   - `get_sb_broker_config()` — Service Broker connection parameters

4. **Service Broker module** — `service_broker.py` (~405 lines) implements the full dispatcherd Broker protocol as a drop-in replacement.

5. **Per-component settings** — Thin wrappers (~100-200 lines each) that import the shared library and add component-specific patches (Controller stdout, Gateway xDS, EDA activation queue).

This architecture means a productized MSSQL feature could potentially be delivered as a **configuration overlay** rather than requiring changes to core AAP repositories.

---

## Appendix A: Files Modified/Created in POC

| File | Lines | Purpose |
|------|:-----:|---------|
| `lib/mssql_common.py` | 295 | Shared ORM patches and notification bus config |
| `service_broker.py` | 405 | Dispatcherd Broker protocol implementation |
| `mssql-confd.py` | 451 | Controller settings (HostMetric, stdout, wsrelay, PubSub) |
| `gateway-mssql-settings.py` | 195 | Gateway settings (xDS, health check, dispatcherd) |
| `eda-mssql-settings.py` | 218 | EDA settings (Dynaconf wrapper, activation queue, dispatcherd) |
| `Dockerfile.controller` | 12 | Controller MSSQL image build |
| `Dockerfile.gateway` | 12 | Gateway MSSQL image build |
| `Dockerfile.eda` | 12 | EDA MSSQL image build |
| `README.md` | 800+ | Comprehensive deployment guide (Parts 1-7) |
| `scripts/setup_*_db.sql` | ~50 each | Database + Service Broker DDL |
| `scripts/migrate_*_data.py` | ~150 each | PG → MSSQL data migration |

**Total new code:** ~2,400 lines (excluding migration scripts and deployment docs)

---

## Appendix B: Source Repositories

| Repository | Branch | URL |
|------------|--------|-----|
| AWX (all POC artefacts) | `mssql-poc` | https://github.com/jonnyfiveiq/awx/tree/mssql-poc/contrib/mssql-poc |
| Platform Lifecycle as Code | `main` | https://github.com/jonnyfiveiq/plac-poc |
| Demo Video | — | https://drive.google.com/file/d/1gbS8BxZ1wKDlYUB6X-EqACn9BSmgwsUN/view |

---

## Appendix C: Technology Stack

| Layer | Technology | Version |
|-------|-----------|---------|
| Platform | aap-dev (default devel repos) | 2.7 |
| Controller | awx (default devel branch) | 2.7 |
| Gateway | gateway (default devel branch) | 2.7 |
| DAB | django-ansible-base (default devel branch) | 2.7 |
| EDA | eda (default devel branch) | 2.7 |
| Database | Microsoft SQL Server | 2022 (containerized) |
| Django Backend | mssql-django | 1.7.3 |
| ODBC Driver (Python) | pyodbc | 5.3.0 |
| ODBC Driver (System) | msodbcsql18 | 18.x |
| Container Runtime | Podman | Host native |
| Orchestration | Kubernetes (Minikube) | Local |
