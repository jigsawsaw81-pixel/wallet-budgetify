from decimal import Decimal, InvalidOperation
from pathlib import Path

ROOT = Path(__file__).parent
SWIFT_ROOT = ROOT / "Budgetify"


def indian_numeric(value: Decimal) -> str:
    quantized = value.quantize(Decimal("0.01")) if value != value.to_integral_value() else value
    raw = format(quantized, "f")
    whole, _, fraction = raw.partition(".")
    groups = []
    if len(whole) > 3:
        groups.append(whole[-3:])
        whole = whole[:-3]
        while whole:
            groups.append(whole[-2:])
            whole = whole[:-2]
        whole = ",".join(reversed(groups))
    return whole + (f".{fraction}" if fraction else "")


def money_string(value: Decimal) -> str:
    sign = "−" if value < 0 else ""
    return sign + "₹" + indian_numeric(abs(value))


def parse_money(raw: str, allows_zero: bool = False) -> Decimal:
    cleaned = "".join(character for character in raw if not character.isspace())
    cleaned = cleaned.replace("₹", "").replace(",", "")
    if not cleaned:
        raise ValueError("empty")
    if "-" in cleaned:
        raise ValueError("negative")
    pieces = cleaned.split(".")
    if len(pieces) > 2 or not pieces[0].isdigit() or (len(pieces) == 2 and (len(pieces[1]) > 2 or not pieces[1].isdigit())):
        raise ValueError("invalid")
    try:
        amount = Decimal(cleaned)
    except InvalidOperation as error:
        raise ValueError("invalid") from error
    if amount == 0 and not allows_zero:
        raise ValueError("zero")
    return amount


expected_formats = {
    Decimal("0"): "₹0",
    Decimal("1"): "₹1",
    Decimal("100"): "₹100",
    Decimal("1000"): "₹1,000",
    Decimal("100000"): "₹1,00,000",
    Decimal("100000.50"): "₹1,00,000.50",
}
for value, expected in expected_formats.items():
    if money_string(value) != expected:
        raise AssertionError(f"format {value}: expected {expected}, got {money_string(value)}")

accepted_inputs = {
    "1000": Decimal("1000"),
    "1,000": Decimal("1000"),
    "1000.50": Decimal("1000.50"),
    "₹1,000.50": Decimal("1000.50"),
    " ₹ 1,000.50 ": Decimal("1000.50"),
}
for raw, expected in accepted_inputs.items():
    if parse_money(raw) != expected:
        raise AssertionError(f"parse {raw!r}: expected {expected}, got {parse_money(raw)}")

for invalid in ("", "₹", "1.001", "-1", "1,00,0x"):
    try:
        parse_money(invalid)
    except ValueError:
        pass
    else:
        raise AssertionError(f"invalid money input accepted: {invalid!r}")

swift = "\n".join(path.read_text() for path in sorted(SWIFT_ROOT.glob("*.swift")))
required_fragments = (
    'static let currencySymbol = "₹"',
    "struct AmountText: View",
    'struct RupeeSymbol: View',
    'Image(systemName: "indianrupeesign")',
    'Text(MoneyFormatter.numericString(magnitude))',
    "struct MoneyInputField: View",
    ".monospacedDigit()",
)
for fragment in required_fragments:
    if fragment not in swift:
        raise AssertionError(f"missing shared money-rendering fragment: {fragment}")

for forbidden in ('Text("₹")', "₹\\(", "₹(value)", "₹,.2f", "String(format:"):
    if forbidden in swift:
        raise AssertionError(f"forbidden raw or template currency rendering found: {forbidden}")

print("Money formatting validation passed: Indian INR outputs, Decimal parser inputs, shared AmountText, native U+20B9, and forbidden-pattern checks.")
