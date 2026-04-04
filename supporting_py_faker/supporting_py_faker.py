#!/usr/bin/env python3
"""
generate_customer_transactions.py

ONLY inserts customer-facing transactions into the `transactions` table
for the last N years. It does NOT:
- update account balances
- insert fee transactions

Balances/fees should be handled by your SQL triggers/scripts.

Behavior:
- 60% customer transactions occur in the customer's home branch (inferred),
  40% occur in other branches.
- CURRENT can go negative (allowed).
- LOAN should be negative: generator includes disbursements and repayments,
  weighted to make loans trend negative overall.
- Payday spike around the 20th (19–22), holiday spike for business deposits,
  and a digital campaign ~3 years ago.
"""

import argparse
import sqlite3
import random
from datetime import datetime, timedelta, date

LSL = "LSL"

CHANNELS = ["IN_BRANCH","USSD","WEB","SMART_APP","POS","ONLINE_PAYMENTS"]

TX_TYPES = [
    "SALARY_DEPOSIT",
    "ATM_WITHDRAWAL",
    "BNA_DEPOSIT",
    "POS_PURCHASE",
    "AIRTIME_DATA",
    "ELECTRICITY",
    "DSTV",
    "TAX",
    "P2P_TRANSFER",
    "LOAN_DISBURSEMENT",
    "LOAN_REPAYMENT",
]

def to_sqlite_dt(d: datetime) -> str:
    return d.strftime("%Y-%m-%d %H:%M:%S")

def to_sqlite_date(d: date) -> str:
    return d.strftime("%Y-%m-%d")

def connect(db_path: str) -> sqlite3.Connection:
    conn = sqlite3.connect(db_path)
    conn.execute("PRAGMA foreign_keys=ON;")
    conn.execute("PRAGMA journal_mode=WAL;")
    conn.execute("PRAGMA synchronous=OFF;")
    conn.execute("PRAGMA temp_store=MEMORY;")
    return conn

def table_exists(conn, name: str) -> bool:
    return conn.execute(
        "SELECT 1 FROM sqlite_master WHERE type='table' AND name=?;", (name,)
    ).fetchone() is not None

def pick_weighted(items, weights):
    return random.choices(items, weights=weights, k=1)[0]

def within_holiday_spike(d: date) -> bool:
    # Nov 25 to Dec 31 every year
    return (d.month == 11 and d.day >= 25) or (d.month == 12)

def within_payday_spike(d: date) -> bool:
    # Around 20th
    return d.day in (19, 20, 21, 22)

def within_campaign(d: date, start: date, end: date) -> bool:
    return start <= d <= end

def fail_probability(channel: str) -> float:
    # Higher failures online/POS, lower in-branch
    if channel == "IN_BRANCH":
        return 0.005
    if channel in ("POS","ONLINE_PAYMENTS"):
        return 0.025
    return 0.015

def choose_channel_for_day(d: date, campaign_start: date, campaign_end: date) -> str:
    # Campaign boosts digital channels
    if within_campaign(d, campaign_start, campaign_end):
        return pick_weighted(
            ["SMART_APP","USSD","WEB","IN_BRANCH","POS","ONLINE_PAYMENTS"],
            [0.30,      0.26,  0.16, 0.10,      0.10, 0.08]
        )
    return pick_weighted(
        ["IN_BRANCH","SMART_APP","USSD","WEB","POS","ONLINE_PAYMENTS"],
        [0.22,      0.22,      0.20, 0.12, 0.14, 0.10]
    )

def pick_tx_type_for_day(d: date, customer_type: str):
    # Base mix of customer-facing activities
    weights = {
        "SALARY_DEPOSIT":     0.11,
        "ATM_WITHDRAWAL":     0.18,
        "BNA_DEPOSIT":        0.14,
        "POS_PURCHASE":       0.20,
        "AIRTIME_DATA":       0.10,
        "ELECTRICITY":        0.08,
        "DSTV":               0.06,
        "TAX":                0.02,
        "P2P_TRANSFER":       0.08,
        "LOAN_DISBURSEMENT":  0.02,
        "LOAN_REPAYMENT":     0.03,
    }

    # Payday spike: more salary deposits, withdrawals, transfers, repayments
    if within_payday_spike(d):
        weights["SALARY_DEPOSIT"] *= 2.5
        weights["ATM_WITHDRAWAL"] *= 1.8
        weights["P2P_TRANSFER"] *= 1.4
        weights["POS_PURCHASE"] *= 1.2
        weights["LOAN_REPAYMENT"] *= 1.3

    # Holiday spike: business deposits increase
    if customer_type == "BUSINESS" and within_holiday_spike(d):
        weights["BNA_DEPOSIT"] *= 2.2
        weights["POS_PURCHASE"] *= 1.3

    items = list(weights.keys())
    w = list(weights.values())
    s = sum(w)
    w = [x/s for x in w]
    return pick_weighted(items, w)

def amount_for_tx(tx_type, customer_type):
    # LSL distributions (rounded to 2dp)
    if tx_type == "SALARY_DEPOSIT":
        return round(random.uniform(15000, 120000), 2) if customer_type == "BUSINESS" else round(random.uniform(2000, 15000), 2)
    if tx_type == "ATM_WITHDRAWAL":
        return round(random.choice([100,200,300,500,800,1000,1500,2000,3000,5000]), 2)
    if tx_type == "BNA_DEPOSIT":
        return round(random.uniform(2000, 90000), 2) if customer_type == "BUSINESS" else round(random.uniform(50, 8000), 2)
    if tx_type == "POS_PURCHASE":
        return round(random.uniform(20, 3500), 2)
    if tx_type in ("AIRTIME_DATA","ELECTRICITY","DSTV"):
        return round(random.uniform(10, 1500), 2)
    if tx_type == "TAX":
        return round(random.uniform(500, 25000), 2)
    if tx_type == "P2P_TRANSFER":
        return round(random.uniform(50, 12000), 2)
    if tx_type == "LOAN_DISBURSEMENT":
        return round(random.uniform(2000, 80000), 2)
    if tx_type == "LOAN_REPAYMENT":
        return round(random.uniform(200, 12000), 2)
    return round(random.uniform(50, 5000), 2)

def load_pools(conn):
    # Customers
    customer_map = dict(conn.execute("SELECT id, customer_type FROM customers WHERE is_active=1;").fetchall())
    customer_ids = list(customer_map.keys())

    # Customer accounts by customer and type (exclude CLOSED to reduce auto-fails)
    cust_accounts = {}
    for aid, cid, bid, atype in conn.execute("""
        SELECT id, customer_id, branch_id, account_type
        FROM accounts
        WHERE account_category='CUSTOMER'
          AND customer_id IS NOT NULL
          AND status <> 'CLOSED';
    """).fetchall():
        cust_accounts.setdefault(cid, []).append((aid, bid, atype))

    # Infer "home branch" = branch where customer has most accounts (ties -> min branch_id)
    home_branch = {}
    for cid, bid in conn.execute("""
        WITH counts AS (
          SELECT customer_id, branch_id, COUNT(*) AS n
          FROM accounts
          WHERE account_category='CUSTOMER' AND customer_id IS NOT NULL
          GROUP BY customer_id, branch_id
        ),
        ranked AS (
          SELECT customer_id, branch_id,
                 ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY n DESC, branch_id ASC) AS rn
          FROM counts
        )
        SELECT customer_id, branch_id FROM ranked WHERE rn=1;
    """).fetchall():
        home_branch[cid] = bid

    all_branch_ids = [r[0] for r in conn.execute("SELECT id FROM branches;").fetchall()]

    # Tellers and devices for initiators
    tellers_by_branch = {}
    for eid, bid in conn.execute("SELECT id, branch_id FROM employees WHERE role='TELLER' AND is_active=1;").fetchall():
        tellers_by_branch.setdefault(bid, []).append(eid)

    devices_by_branch_type = {}
    for did, bid, dtype in conn.execute("SELECT id, branch_id, device_type FROM devices WHERE is_active=1;").fetchall():
        devices_by_branch_type.setdefault((bid, dtype), []).append(did)

    # GLs by account_number (used as counterparty accounts)
    gl_ids = dict(conn.execute("""
        SELECT account_number, id
        FROM accounts
        WHERE account_category='GL' AND status <> 'CLOSED';
    """).fetchall())

    # Suspense by (branch_id, type_code) from account_number pattern <seq><type_code>00000000
    suspense_map = {}
    for aid, bid, acct_no in conn.execute("""
        SELECT id, branch_id, account_number
        FROM accounts
        WHERE account_category='SUSPENSE' AND status <> 'CLOSED';
    """).fetchall():
        type_code = acct_no[2:4] if acct_no and len(acct_no) >= 4 else None
        suspense_map[(bid, type_code)] = aid

    return customer_map, customer_ids, cust_accounts, home_branch, all_branch_ids, tellers_by_branch, devices_by_branch_type, gl_ids, suspense_map

def choose_branch_context(home_bid, all_branch_ids, home_ratio=0.60):
    if home_bid is None:
        return random.choice(all_branch_ids)
    if random.random() < home_ratio:
        return home_bid
    others = [b for b in all_branch_ids if b != home_bid]
    return random.choice(others) if others else home_bid

def pick_initiator(channel, branch_ctx, tellers_by_branch, devices_by_branch_type, cust_id):
    if channel == "IN_BRANCH":
        t = tellers_by_branch.get(branch_ctx, [])
        return ("EMPLOYEE", random.choice(t) if t else None)
    if channel == "POS":
        d = devices_by_branch_type.get((branch_ctx, "POS"), [])
        return ("DEVICE", random.choice(d) if d else None)
    if channel in ("USSD","WEB","SMART_APP","ONLINE_PAYMENTS"):
        return ("CUSTOMER", cust_id)
    return ("SYSTEM", None)

def pick_customer_account(cust_accounts, cid, prefer_types=None):
    accts = cust_accounts.get(cid, [])
    if not accts:
        return None
    if prefer_types:
        preferred = [a for a in accts if a[2] in prefer_types]
        if preferred:
            return random.choice(preferred)
    return random.choice(accts)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("db", help="SQLite database file path (e.g., bank_sim.db)")
    ap.add_argument("--transactions", type=int, default=250000, help="Number of customer transactions to generate")
    ap.add_argument("--years", type=int, default=5, help="How many years back from today")
    ap.add_argument("--home_ratio", type=float, default=0.60, help="Share of transactions in home branch (default 0.60)")
    ap.add_argument("--batch", type=int, default=5000, help="Batch size for inserts (default 5000)")
    args = ap.parse_args()

    conn = connect(args.db)

    # Minimal table checks
    required = ["customers","accounts","transactions","branches","employees","devices"]
    missing = [t for t in required if not table_exists(conn, t)]
    if missing:
        raise SystemExit("Missing tables: " + ", ".join(missing) + "\nCreate schema + seed base data first.")

    # Params (optional): suspicious threshold used to pre-fill is_suspicious to help analysis;
    # your SQL scripts/triggers may override it.
    suspicious_threshold_row = conn.execute("""
        SELECT COALESCE(CAST(value AS NUMERIC), 10000)
        FROM system_parameters
        WHERE key='suspicious_threshold_lsl';
    """).fetchone()
    suspicious_threshold = float(suspicious_threshold_row[0]) if suspicious_threshold_row else 10000.0

    customer_map, customer_ids, cust_accounts, home_branch, all_branch_ids, tellers_by_branch, devices_by_branch_type, gl_ids, suspense_map = load_pools(conn)

    if not customer_ids:
        raise SystemExit("No customers found. Load customers/accounts first.")
    if not cust_accounts:
        raise SystemExit("No customer accounts found. Load accounts first.")

    # Required GLs (fallback to any GL if missing)
    gl_interbank = gl_ids.get("990000000004") or next(iter(gl_ids.values()), None)
    gl_data      = gl_ids.get("990000000002") or gl_interbank
    gl_elec      = gl_ids.get("990000000003") or gl_interbank
    gl_dstv      = gl_ids.get("990000000005") or gl_interbank
    gl_tax       = gl_ids.get("990000000006") or gl_interbank
    gl_pos       = gl_ids.get("990000000007") or gl_interbank

    if gl_interbank is None:
        raise SystemExit("No GL accounts found. Seed GL accounts first (e.g., HQ service GLs).")

    # Date range (last N years)
    end_d = date.today()
    start_d = end_d - timedelta(days=365 * args.years)

    # Campaign period: ~3 years ago for 90 days (relative to today)
    campaign_start = end_d - timedelta(days=365 * 3)
    campaign_end = campaign_start + timedelta(days=90)

    # Weighted day sampling (payday/holiday/campaign)
    days, weights = [], []
    d = start_d
    while d <= end_d:
        w = 1.0
        if within_payday_spike(d): w *= 1.8
        if within_holiday_spike(d): w *= 1.25
        if within_campaign(d, campaign_start, campaign_end): w *= 1.15
        days.append(d)
        weights.append(w)
        d += timedelta(days=1)
    total_w = sum(weights)
    weights = [x / total_w for x in weights]

    BATCH = max(100, args.batch)
    rows = []
    inserted = 0

    for i in range(args.transactions):
        tx_day = random.choices(days, weights=weights, k=1)[0]
        posted_dt = datetime(tx_day.year, tx_day.month, tx_day.day,
                             random.randint(8, 20), random.randint(0, 59), random.randint(0, 59))
        created_dt = posted_dt - timedelta(minutes=random.randint(0, 180))

        cust_id = random.choice(customer_ids)
        if cust_id not in cust_accounts:
            continue

        cust_type = customer_map.get(cust_id, "PERSON")
        branch_ctx = choose_branch_context(home_branch.get(cust_id), all_branch_ids, home_ratio=args.home_ratio)
        channel = choose_channel_for_day(tx_day, campaign_start, campaign_end)

        initiated_by_type, initiated_by_id = pick_initiator(
            channel, branch_ctx, tellers_by_branch, devices_by_branch_type, cust_id
        )

        tx_type = pick_tx_type_for_day(tx_day, cust_type)
        amt = amount_for_tx(tx_type, cust_type)

        status = "FAILED" if (random.random() < fail_probability(channel)) else "SUCCESS"
        is_susp = 1 if (status == "SUCCESS" and amt >= suspicious_threshold) else 0

        narrative = tx_type.replace("_", " ")
        reference = None

        dr_aid = None
        cr_aid = None

        # Customer-facing flows: one side is customer account, other is GL/suspense/another customer
        if tx_type == "SALARY_DEPOSIT":
            cr = pick_customer_account(cust_accounts, cust_id, ["CURRENT","SAVINGS"])
            if not cr: continue
            dr_aid = gl_interbank
            cr_aid = cr[0]

        elif tx_type == "ATM_WITHDRAWAL":
            # channel constraint: no "ATM" channel in enum; we treat as POS-style device channel
            # debit customer current, credit branch ATM suspense ("01")
            dr = pick_customer_account(cust_accounts, cust_id, ["CURRENT"])
            if not dr: continue
            dr_aid = dr[0]
            cr_aid = suspense_map.get((branch_ctx, "01"), gl_interbank)

        elif tx_type == "BNA_DEPOSIT":
            # debit branch BNA suspense ("02"), credit customer current/savings
            cr = pick_customer_account(cust_accounts, cust_id, ["CURRENT","SAVINGS"])
            if not cr: continue
            dr_aid = suspense_map.get((branch_ctx, "02"), gl_interbank)
            cr_aid = cr[0]

        elif tx_type == "POS_PURCHASE":
            dr = pick_customer_account(cust_accounts, cust_id, ["CURRENT"])
            if not dr: continue
            dr_aid = dr[0]
            cr_aid = gl_pos

        elif tx_type == "AIRTIME_DATA":
            dr = pick_customer_account(cust_accounts, cust_id, ["CURRENT"])
            if not dr: continue
            dr_aid = dr[0]
            cr_aid = gl_data

        elif tx_type == "ELECTRICITY":
            dr = pick_customer_account(cust_accounts, cust_id, ["CURRENT"])
            if not dr: continue
            dr_aid = dr[0]
            cr_aid = gl_elec

        elif tx_type == "DSTV":
            dr = pick_customer_account(cust_accounts, cust_id, ["CURRENT"])
            if not dr: continue
            dr_aid = dr[0]
            cr_aid = gl_dstv

        elif tx_type == "TAX":
            dr = pick_customer_account(cust_accounts, cust_id, ["CURRENT"])
            if not dr: continue
            dr_aid = dr[0]
            cr_aid = gl_tax

        elif tx_type == "P2P_TRANSFER":
            dr = pick_customer_account(cust_accounts, cust_id, ["CURRENT","SAVINGS"])
            if not dr: continue

            # pick other customer with accounts
            other = random.choice(customer_ids)
            tries = 0
            while (other == cust_id or other not in cust_accounts) and tries < 10:
                other = random.choice(customer_ids)
                tries += 1
            cr = pick_customer_account(cust_accounts, other, ["CURRENT","SAVINGS"])
            if not cr: continue

            dr_aid = dr[0]
            cr_aid = cr[0]

        elif tx_type == "LOAN_DISBURSEMENT":
            # DR loan (makes it more negative once balances/fees apply), CR current (customer receives funds)
            loan = pick_customer_account(cust_accounts, cust_id, ["LOAN"])
            cur  = pick_customer_account(cust_accounts, cust_id, ["CURRENT"])
            if not loan or not cur:
                continue
            dr_aid = loan[0]
            cr_aid = cur[0]

        elif tx_type == "LOAN_REPAYMENT":
            # DR current (customer pays), CR loan (reduces negative)
            loan = pick_customer_account(cust_accounts, cust_id, ["LOAN"])
            cur  = pick_customer_account(cust_accounts, cust_id, ["CURRENT"])
            if not loan or not cur:
                continue
            dr_aid = cur[0]
            cr_aid = loan[0]

        else:
            # fallback
            dr = pick_customer_account(cust_accounts, cust_id, ["CURRENT"])
            if not dr: continue
            dr_aid = dr[0]
            cr_aid = gl_interbank

        if dr_aid == cr_aid:
            continue

        # IMPORTANT: we do NOT update balances, we do NOT insert fees.
        # Triggers/scripts can apply postings based on SUCCESS status.
        rows.append((
            dr_aid, cr_aid, round(amt,2), LSL,
            status, is_susp,
            channel, initiated_by_type, initiated_by_id,
            narrative, reference,
            to_sqlite_dt(created_dt), to_sqlite_dt(posted_dt), to_sqlite_date(tx_day)
        ))

        if len(rows) >= BATCH:
            conn.execute("BEGIN;")
            conn.executemany(
                "INSERT INTO transactions(dr_account_id,cr_account_id,amount,currency,status,is_suspicious,channel,initiated_by_type,initiated_by_id,narrative,reference,created_at,posted_at,value_date) "
                "VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?);",
                rows
            )
            conn.execute("COMMIT;")
            inserted += len(rows)
            rows = []
            print(f"Inserted {inserted}/{args.transactions} transactions...")

    # flush remainder
    if rows:
        conn.execute("BEGIN;")
        conn.executemany(
            "INSERT INTO transactions(dr_account_id,cr_account_id,amount,currency,status,is_suspicious,channel,initiated_by_type,initiated_by_id,narrative,reference,created_at,posted_at,value_date) "
            "VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?);",
            rows
        )
        conn.execute("COMMIT;")
        inserted += len(rows)

    print(f"\nDone. Inserted {inserted} customer transactions.")
    print("Balances/fees should now be applied by your SQL triggers/scripts.")
    conn.close()

if __name__ == "__main__":
    main()
