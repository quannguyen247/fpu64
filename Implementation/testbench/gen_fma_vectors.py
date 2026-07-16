from fractions import Fraction
from pathlib import Path
import random
import struct

F_MADD = 12
F_MSUB = 13
F_NMSUB = 14
F_NMADD = 15

RM_RNE = 0
RM_RTZ = 1
RM_RDN = 2
RM_RUP = 3
RM_RMM = 4

FF_NV = 1 << 4
FF_OF = 1 << 2
FF_UF = 1 << 1
FF_NX = 1 << 0


def f32(value):
    return 0xFFFFFFFF00000000 | struct.unpack(">I", struct.pack(">f", value))[0]


def f64(value):
    return struct.unpack(">Q", struct.pack(">d", value))[0]


def canonical_nan(is_double):
    return 0x7FF8000000000000 if is_double else 0xFFFFFFFF7FC00000


def unpack(bits, is_double):
    if is_double:
        width = 64
        exp_width = 11
        frac_width = 52
        bias = 1023
        raw = bits
        boxed = True
    else:
        width = 32
        exp_width = 8
        frac_width = 23
        bias = 127
        raw = bits & 0xFFFFFFFF
        boxed = (bits >> 32) == 0xFFFFFFFF
    sign = (raw >> (width - 1)) & 1
    exp_mask = (1 << exp_width) - 1
    frac_mask = (1 << frac_width) - 1
    exp = (raw >> frac_width) & exp_mask
    frac = raw & frac_mask
    if not boxed:
        return {"kind": "nan", "sign": 0, "snan": False, "value": Fraction(0)}
    if exp == exp_mask:
        if frac == 0:
            return {"kind": "inf", "sign": sign, "snan": False, "value": Fraction(0)}
        return {
            "kind": "nan",
            "sign": sign,
            "snan": ((frac >> (frac_width - 1)) & 1) == 0,
            "value": Fraction(0),
        }
    if exp == 0:
        if frac == 0:
            return {"kind": "zero", "sign": sign, "snan": False, "value": Fraction(0)}
        exponent = 1 - bias - frac_width
        significand = frac
    else:
        exponent = exp - bias - frac_width
        significand = (1 << frac_width) | frac
    if exponent >= 0:
        value = Fraction(significand << exponent, 1)
    else:
        value = Fraction(significand, 1 << (-exponent))
    return {"kind": "finite", "sign": sign, "snan": False, "value": value}


def floor_log2(value):
    numerator = value.numerator
    denominator = value.denominator
    exponent = numerator.bit_length() - denominator.bit_length()
    if exponent >= 0:
        if numerator < (denominator << exponent):
            exponent -= 1
    elif (numerator << (-exponent)) < denominator:
        exponent -= 1
    return exponent


def quantize(value, unit_exp, sign, rm):
    numerator = value.numerator
    denominator = value.denominator
    if unit_exp >= 0:
        denominator <<= unit_exp
    else:
        numerator <<= -unit_exp
    quotient, remainder = divmod(numerator, denominator)
    increment = False
    if remainder:
        twice = remainder << 1
        if rm == RM_RNE:
            increment = twice > denominator or (twice == denominator and (quotient & 1) != 0)
        elif rm == RM_RDN:
            increment = sign == 1
        elif rm == RM_RUP:
            increment = sign == 0
        elif rm == RM_RMM:
            increment = twice >= denominator
    return quotient + (1 if increment else 0), remainder != 0


def round_binary(value, zero_sign, is_double, rm):
    if value == 0:
        sign = zero_sign
        if is_double:
            return sign << 63, 0
        return 0xFFFFFFFF00000000 | (sign << 31), 0
    sign = 1 if value < 0 else 0
    magnitude = -value if value < 0 else value
    if is_double:
        precision = 53
        frac_width = 52
        exp_width = 11
        bias = 1023
        emin = -1022
        emax = 1023
    else:
        precision = 24
        frac_width = 23
        exp_width = 8
        bias = 127
        emin = -126
        emax = 127
    exponent = floor_log2(magnitude)
    flags = 0
    if exponent < emin:
        significand, inexact = quantize(magnitude, emin - (precision - 1), sign, rm)
        if significand >= (1 << (precision - 1)):
            exp_field = 1
            frac = significand - (1 << (precision - 1))
        else:
            exp_field = 0
            frac = significand
        if inexact:
            flags |= FF_NX
            if exp_field == 0:
                flags |= FF_UF
    else:
        significand, inexact = quantize(magnitude, exponent - (precision - 1), sign, rm)
        if significand == (1 << precision):
            significand >>= 1
            exponent += 1
        if exponent > emax:
            flags |= FF_OF | FF_NX
            to_inf = rm in (RM_RNE, RM_RMM) or (rm == RM_RUP and sign == 0) or (rm == RM_RDN and sign == 1)
            if to_inf:
                exp_field = (1 << exp_width) - 1
                frac = 0
            else:
                exp_field = (1 << exp_width) - 2
                frac = (1 << frac_width) - 1
        else:
            exp_field = exponent + bias
            frac = significand & ((1 << frac_width) - 1)
            if inexact:
                flags |= FF_NX
    raw = (sign << (exp_width + frac_width)) | (exp_field << frac_width) | frac
    if is_double:
        return raw, flags
    return 0xFFFFFFFF00000000 | raw, flags


def fma_reference(rs1, rs2, rs3, op, rm, is_double):
    a = unpack(rs1, is_double)
    b = unpack(rs2, is_double)
    c = unpack(rs3, is_double)
    neg_product = op in (F_NMSUB, F_NMADD)
    neg_addend = op in (F_MSUB, F_NMADD)
    product_sign = a["sign"] ^ b["sign"] ^ neg_product
    addend_sign = c["sign"] ^ neg_addend
    multiply_invalid = (a["kind"] == "zero" and b["kind"] == "inf") or (a["kind"] == "inf" and b["kind"] == "zero")
    any_nan = a["kind"] == "nan" or b["kind"] == "nan" or c["kind"] == "nan"
    any_snan = a["snan"] or b["snan"] or c["snan"]
    if any_nan or multiply_invalid:
        return canonical_nan(is_double), FF_NV if any_snan or multiply_invalid else 0
    product_inf = a["kind"] == "inf" or b["kind"] == "inf"
    if product_inf:
        if c["kind"] == "inf" and product_sign != addend_sign:
            return canonical_nan(is_double), FF_NV
        if is_double:
            return (product_sign << 63) | 0x7FF0000000000000, 0
        return 0xFFFFFFFF00000000 | (product_sign << 31) | 0x7F800000, 0
    if c["kind"] == "inf":
        if is_double:
            return (addend_sign << 63) | 0x7FF0000000000000, 0
        return 0xFFFFFFFF00000000 | (addend_sign << 31) | 0x7F800000, 0
    product = a["value"] * b["value"]
    if product_sign:
        product = -product
    addend = c["value"]
    if addend_sign:
        addend = -addend
    exact = product + addend
    if exact == 0:
        if product == 0 and addend == 0 and product_sign == addend_sign:
            zero_sign = product_sign
        else:
            zero_sign = 1 if rm == RM_RDN else 0
    else:
        zero_sign = 0
    return round_binary(exact, zero_sign, is_double, rm)


def nonfused_reference(rs1, rs2, rs3, op, rm, is_double):
    a = unpack(rs1, is_double)
    b = unpack(rs2, is_double)
    c = unpack(rs3, is_double)
    if any(value["kind"] not in ("finite", "zero") for value in (a, b, c)):
        return None
    neg_product = op in (F_NMSUB, F_NMADD)
    neg_addend = op in (F_MSUB, F_NMADD)
    product_sign = a["sign"] ^ b["sign"] ^ neg_product
    product = a["value"] * b["value"]
    if product_sign:
        product = -product
    rounded_product, _ = round_binary(product, product_sign, is_double, rm)
    product_decoded = unpack(rounded_product, is_double)
    rounded_value = product_decoded["value"]
    if product_decoded["sign"]:
        rounded_value = -rounded_value
    addend = c["value"]
    addend_sign = c["sign"] ^ neg_addend
    if addend_sign:
        addend = -addend
    total = rounded_value + addend
    zero_sign = 1 if total == 0 and rm == RM_RDN else 0
    return round_binary(total, zero_sign, is_double, rm)


def random_finite(rng, is_double):
    if is_double:
        raw = rng.getrandbits(64)
        if ((raw >> 52) & 0x7FF) == 0x7FF:
            raw ^= 1 << 52
        return raw
    raw = rng.getrandbits(32)
    if ((raw >> 23) & 0xFF) == 0xFF:
        raw ^= 1 << 23
    return 0xFFFFFFFF00000000 | raw


def directed_vectors():
    vectors = []
    for is_double in (0, 1):
        one = f64(1.0) if is_double else f32(1.0)
        one_half = f64(1.5) if is_double else f32(1.5)
        two = f64(2.0) if is_double else f32(2.0)
        quarter = f64(0.25) if is_double else f32(0.25)
        pos_zero = f64(0.0) if is_double else f32(0.0)
        neg_zero = f64(-0.0) if is_double else f32(-0.0)
        pos_inf = 0x7FF0000000000000 if is_double else 0xFFFFFFFF7F800000
        neg_inf = 0xFFF0000000000000 if is_double else 0xFFFFFFFFFF800000
        qnan = 0x7FF8000000000001 if is_double else 0xFFFFFFFF7FC00001
        snan = 0x7FF0000000000001 if is_double else 0xFFFFFFFF7F800001
        max_finite = 0x7FEFFFFFFFFFFFFF if is_double else 0xFFFFFFFF7F7FFFFF
        min_normal = 0x0010000000000000 if is_double else 0xFFFFFFFF00800000
        min_subnormal = 0x0000000000000001 if is_double else 0xFFFFFFFF00000001
        negative_one = f64(-1.0) if is_double else f32(-1.0)
        half_ulp_at_one = f64(2.0 ** -53) if is_double else f32(2.0 ** -24)
        negative_half_ulp_at_one = f64(-(2.0 ** -53)) if is_double else f32(-(2.0 ** -24))
        half = f64(0.5) if is_double else f32(0.5)
        for op in (F_MADD, F_MSUB, F_NMSUB, F_NMADD):
            vectors.append((is_double, op, RM_RNE, one_half, two, quarter))
        for rm in (RM_RNE, RM_RTZ, RM_RDN, RM_RUP, RM_RMM):
            vectors.append((is_double, F_MADD, rm, one, one, min_subnormal))
            vectors.append((is_double, F_MSUB, rm, one, one, one))
            vectors.append((is_double, F_MADD, rm, neg_zero, one, pos_zero))
            vectors.append((is_double, F_MADD, rm, one, one, half_ulp_at_one))
            vectors.append((is_double, F_MADD, rm, negative_one, one, negative_half_ulp_at_one))
            vectors.append((is_double, F_MADD, rm, min_subnormal, half, pos_zero))
            vectors.append((is_double, F_MADD, rm, max_finite, two, pos_zero))
            vectors.append((is_double, F_MADD, rm, max_finite ^ (1 << (63 if is_double else 31)), two, neg_zero))
        vectors.extend([
            (is_double, F_MADD, RM_RNE, qnan, one, one),
            (is_double, F_MADD, RM_RNE, one, qnan, one),
            (is_double, F_MADD, RM_RNE, one, one, qnan),
            (is_double, F_MADD, RM_RNE, snan, one, one),
            (is_double, F_MADD, RM_RNE, one, snan, one),
            (is_double, F_MADD, RM_RNE, one, one, snan),
            (is_double, F_MADD, RM_RNE, pos_zero, pos_inf, qnan),
            (is_double, F_MADD, RM_RNE, pos_inf, pos_zero, qnan),
            (is_double, F_MADD, RM_RNE, pos_inf, one, neg_inf),
            (is_double, F_MSUB, RM_RNE, pos_inf, one, pos_inf),
            (is_double, F_MADD, RM_RNE, pos_inf, one, pos_inf),
            (is_double, F_NMSUB, RM_RNE, pos_inf, one, pos_inf),
            (is_double, F_MADD, RM_RNE, max_finite, two, neg_inf),
            (is_double, F_MADD, RM_RTZ, max_finite, two, pos_zero),
            (is_double, F_MADD, RM_RUP, max_finite, two, pos_zero),
            (is_double, F_MADD, RM_RNE, min_normal, half, pos_zero),
            (is_double, F_MADD, RM_RNE, min_subnormal, half, pos_zero),
            (is_double, F_MADD, RM_RDN, one, one, negative_one),
            (is_double, F_MADD, RM_RNE, neg_zero, one, neg_zero),
        ])
    vectors.append((0, F_MADD, RM_RNE, 0x000000003F800000, f32(1.0), f32(1.0)))
    vectors.append((0, F_MADD, RM_RNE, f32(1.0), 0x000000003F800000, f32(1.0)))
    vectors.append((0, F_MADD, RM_RNE, f32(1.0), f32(1.0), 0x000000003F800000))
    return vectors


def build_vectors():
    rng = random.Random(0xF64A2026)
    vectors = directed_vectors()
    for is_double in (0, 1):
        for op in (F_MADD, F_MSUB, F_NMSUB, F_NMADD):
            for rm in (RM_RNE, RM_RTZ, RM_RDN, RM_RUP, RM_RMM):
                for _ in range(32):
                    vectors.append((
                        is_double,
                        op,
                        rm,
                        random_finite(rng, is_double),
                        random_finite(rng, is_double),
                        random_finite(rng, is_double),
                    ))
    fused_found = {0: 0, 1: 0}
    attempts = 0
    while fused_found[0] < 16 or fused_found[1] < 16:
        attempts += 1
        if attempts > 2000000:
            raise RuntimeError("unable to find fused-distinguishing vectors")
        is_double = attempts & 1
        if fused_found[is_double] >= 16:
            continue
        op = (F_MADD, F_MSUB, F_NMSUB, F_NMADD)[rng.randrange(4)]
        rm = rng.randrange(5)
        candidate = (
            is_double,
            op,
            rm,
            random_finite(rng, is_double),
            random_finite(rng, is_double),
            random_finite(rng, is_double),
        )
        expected = fma_reference(candidate[3], candidate[4], candidate[5], op, rm, is_double)
        nonfused = nonfused_reference(candidate[3], candidate[4], candidate[5], op, rm, is_double)
        if nonfused is not None and expected[0] != nonfused[0]:
            vectors.append(candidate)
            fused_found[is_double] += 1
    return vectors


def main():
    output = Path(__file__).resolve().parents[1] / "vector" / "fma_vectors.hex"
    output.parent.mkdir(parents=True, exist_ok=True)
    vectors = build_vectors()
    fused_count = 0
    with output.open("w", encoding="ascii", newline="\n") as stream:
        for is_double, op, rm, rs1, rs2, rs3 in vectors:
            result, flags = fma_reference(rs1, rs2, rs3, op, rm, is_double)
            nonfused = nonfused_reference(rs1, rs2, rs3, op, rm, is_double)
            fused_diff = int(nonfused is not None and result != nonfused[0])
            fused_count += fused_diff
            stream.write(
                f"{is_double:x} {op:x} {rm:x} {rs1:016x} {rs2:016x} {rs3:016x} "
                f"{result:016x} {flags:02x} {fused_diff:x}\n"
            )
    print(f"generated={len(vectors)} fused_distinguishing={fused_count} path={output}")


if __name__ == "__main__":
    main()
