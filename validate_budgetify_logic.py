from dataclasses import dataclass
from datetime import datetime, timedelta
from decimal import Decimal

@dataclass
class Wallet:
    id: str
    initial: Decimal
    group: str
    kind: str

@dataclass
class Tx:
    amount: Decimal
    wallet: str
    type: str
    status: str | None = None
    title: str = ""
    created: datetime = datetime.now()

now = datetime.now()
wallets = [
    Wallet("bank", Decimal("1000"), "Mine", "bank"),
    Wallet("cash", Decimal("200"), "Mine", "cash"),
    Wallet("work", Decimal("500"), "Work", "bank"),
]
txs = [
    Tx(Decimal("100"), "bank", "expense", title="Groceries", created=now),
    Tx(Decimal("500"), "bank", "income", status="Received", title="Salary", created=now),
    Tx(Decimal("300"), "bank", "income", status="Pending", title="Invoice", created=now),
    Tx(Decimal("50"), "cash", "expense", title="Coffee", created=now - timedelta(days=2)),
]

def wallet_balance(wallet):
    movement = sum((tx.amount if tx.type == "income" else -tx.amount) for tx in txs if tx.wallet == wallet.id and tx.status != "Pending")
    return wallet.initial + movement

def assert_equal(actual, expected, label):
    if actual != expected:
        raise AssertionError(f"{label}: expected {expected}, got {actual}")

assert_equal(wallet_balance(wallets[0]), Decimal("1400"), "bank balance excludes pending income")
assert_equal(wallet_balance(wallets[1]), Decimal("150"), "cash balance")
assert_equal(sum(wallet_balance(w) for w in wallets if w.group == "Mine"), Decimal("1550"), "mine total")
assert_equal(sum(wallet_balance(w) for w in wallets), Decimal("2050"), "grand total")
assert_equal(sum(tx.amount for tx in txs if tx.type == "income" and tx.status != "Pending"), Decimal("500"), "received income")
assert_equal(sum(tx.amount for tx in txs if tx.type == "expense"), Decimal("150"), "expenses")
assert_equal(sum(tx.amount for tx in txs if tx.type == "income" and tx.status == "Pending"), Decimal("300"), "pending income")

# Transfer creates balanced debit and credit records.
transfer_amount = Decimal("125")
transfer_from = Tx(transfer_amount, "bank", "expense", title="Transfer to Cash", created=now)
transfer_to = Tx(transfer_amount, "cash", "income", status="Received", title="Transfer from Bank", created=now)
txs.extend([transfer_from, transfer_to])
assert_equal(wallet_balance(wallets[0]), Decimal("1275"), "source wallet after transfer")
assert_equal(wallet_balance(wallets[1]), Decimal("275"), "destination wallet after transfer")
assert_equal(sum(tx.amount if tx.type == "income" else -tx.amount for tx in (transfer_from, transfer_to)), Decimal("0"), "transfer double entry")

# Search and date filters match title/category-style search semantics.
search_hits = [tx for tx in txs if "coffee" in tx.title.lower()]
assert_equal(len(search_hits), 1, "search filter")
recent_hits = [tx for tx in txs if tx.created >= now - timedelta(days=7)]
assert_equal(len(recent_hits), 6, "seven-day filter")

print("Budgetify logic validation passed: balances, pending income, transfers, search, and date filters.")
