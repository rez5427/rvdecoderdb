/*=======================================================================================*/
/*  This Sail RISC-V architecture model, comprising all files and                        */
/*  directories except where otherwise noted is subject the BSD                          */
/*  two-clause license in the LICENSE file.                                              */
/*                                                                                       */
/*  SPDX-License-Identifier: BSD-2-Clause                                                */
/*=======================================================================================*/

default Order dec

$include <smt.sail>
$include <option.sail>
$include <arith.sail>
$include <string.sail>
$include <mapping.sail>
$include <vector_dec.sail>
$include <generic_equality.sail>
$include <hex_bits.sail>
$include <hex_bits_signed.sail>

val not_bit : bit -> bit
function not_bit(b) = if b == bitone then bitzero else bitone

overload ~ = {not_bool, not_vec, not_bit}

// not_bool alias.
val not : forall ('p : Bool). bool('p) -> bool(not('p))
function not(b) = not_bool(b)

overload operator & = {and_vec}

overload operator | = {or_vec}

function bit_str(b: bit) -> string =
  match b {
    bitzero => "0b0",
    bitone => "0b1"
  }

overload BitStr = {bits_str, bit_str}

overload operator ^ = {xor_vec, concat_str}

val sub_vec = pure {c: "sub_bits", _: "sub_vec"} : forall 'n. (bits('n), bits('n)) -> bits('n)

val sub_vec_int = pure {c: "sub_bits_int", _: "sub_vec_int"} : forall 'n. (bits('n), int) -> bits('n)

overload operator - = {sub_vec, sub_vec_int}

val quot_positive_round_zero = pure {interpreter: "quot_round_zero", lem: "hardware_quot", c: "tdiv_int", coq: "Z.quot"} : forall 'n 'm, 'n >= 0 & 'm > 0. (int('n), int('m)) -> int(div('n, 'm))

val quot_round_zero = pure {interpreter: "quot_round_zero", lem: "hardware_quot", c: "tdiv_int", coq: "Z.quot"} : (int, int) -> int
val rem_round_zero = pure {interpreter: "rem_round_zero", lem: "hardware_mod", c: "tmod_int", coq: "Z.rem"} : (int, int) -> int

/* The following defines % as euclidean modulus */
overload operator % = {emod_int}

overload min = {min_int}
overload max = {max_int}

val print_instr    = pure "print_instr" : string -> unit
val print_reg      = pure "print_reg" : string -> unit
//val print_mem      = pure "print_mem_access" : string -> unit
val print_platform = pure "print_platform" : string -> unit

val sign_extend : forall 'n 'm, 'm >= 'n. (implicit('m), bits('n)) -> bits('m)
val zero_extend : forall 'n 'm, 'm >= 'n. (implicit('m), bits('n)) -> bits('m)

function sign_extend(m, v) = sail_sign_extend(v, m)
function zero_extend(m, v) = sail_zero_extend(v, m)

val zeros_implicit : forall 'n, 'n >= 0 . implicit('n) -> bits('n)
function zeros_implicit (n) = sail_zeros(n)
overload zeros = {zeros_implicit}

val ones : forall 'n, 'n >= 0 . implicit('n) -> bits('n)
function ones (n) = sail_ones (n)

mapping bool_bit : bool <-> bit = {
  true <-> bitone,
  false <-> bitzero,
}

mapping bool_bits : bool <-> bits(1) = {
  true   <-> 0b1,
  false  <-> 0b0,
}

mapping bool_not_bits : bool <-> bits(1) = {
  true   <-> 0b0,
  false  <-> 0b1,
}

// These aliases make the conversion direction a bit clearer.
function bool_to_bit(x : bool) -> bit = bool_bit(x)
function bit_to_bool(x : bit) -> bool = bool_bit(x)
function bool_to_bits(x : bool) -> bits(1) = bool_bits(x)
function bits_to_bool(x : bits(1)) -> bool = bool_bits(x)


val to_bits : forall 'l, 'l >= 0.(int('l), int) -> bits('l)
function to_bits (l, n) = get_slice_int(l, n, 0)

infix 4 <_s
infix 4 >_s
infix 4 <=_s
infix 4 >=_s
infix 4 <_u
infix 4 >_u
infix 4 <=_u
infix 4 >=_u

val operator <_s  : forall 'n, 'n > 0. (bits('n), bits('n)) -> bool
val operator >_s  : forall 'n, 'n > 0. (bits('n), bits('n)) -> bool
val operator <=_s : forall 'n, 'n > 0. (bits('n), bits('n)) -> bool
val operator >=_s : forall 'n, 'n > 0. (bits('n), bits('n)) -> bool
val operator <_u  : forall 'n. (bits('n), bits('n)) -> bool
val operator >_u  : forall 'n. (bits('n), bits('n)) -> bool
val operator <=_u : forall 'n. (bits('n), bits('n)) -> bool
val operator >=_u : forall 'n. (bits('n), bits('n)) -> bool

function operator <_s  (x, y) = signed(x) < signed(y)
function operator >_s  (x, y) = signed(x) > signed(y)
function operator <=_s (x, y) = signed(x) <= signed(y)
function operator >=_s (x, y) = signed(x) >= signed(y)
function operator <_u  (x, y) = unsigned(x) < unsigned(y)
function operator >_u  (x, y) = unsigned(x) > unsigned(y)
function operator <=_u (x, y) = unsigned(x) <= unsigned(y)
function operator >=_u (x, y) = unsigned(x) >= unsigned(y)

infix 7 >>
infix 7 <<

val "shift_bits_right" : forall 'n 'm. (bits('n), bits('m)) -> bits('n)
val "shift_bits_left"  : forall 'n 'm. (bits('n), bits('m)) -> bits('n)

val "shiftl" : forall 'm 'n, 'n >= 0. (bits('m), int('n)) -> bits('m)
val "shiftr" : forall 'm 'n, 'n >= 0. (bits('m), int('n)) -> bits('m)

overload operator >> = {shift_bits_right, shiftr}
overload operator << = {shift_bits_left, shiftl}

/* Ideally these would be sail builtin */

function shift_right_arith64 (v : bits(64), shift : bits(6)) -> bits(64) =
    let v128 : bits(128) = sign_extend(v) in
    (v128 >> shift)[63..0]

function shift_right_arith32 (v : bits(32), shift : bits(5)) -> bits(32) =
    let v64 : bits(64) = sign_extend(v) in
    (v64 >> shift)[31..0]

infix 7 >>>
infix 7 <<<

val rotate_bits_right : forall 'n 'm, 'm >= 0. (bits('n), bits('m)) -> bits('n)
function rotate_bits_right (v, n) =
    (v >> n) | (v << (to_bits(length(n), length(v)) - n))

val rotate_bits_left : forall 'n 'm, 'm >= 0. (bits('n), bits('m)) -> bits('n)
function rotate_bits_left (v, n) =
    (v << n) | (v >> (to_bits(length(n), length(v)) - n))

val rotater : forall 'm 'n, 'm >= 'n >= 0. (bits('m), int('n)) -> bits('m)
function rotater (v, n) =
    (v >> n) | (v << (length(v) - n))

val rotatel : forall 'm 'n, 'm >= 'n >= 0. (bits('m), int('n)) -> bits('m)
function rotatel (v, n) =
    (v << n) | (v >> (length(v) - n))

overload operator >>> = {rotate_bits_right, rotater}
overload operator <<< = {rotate_bits_left, rotatel}

function reverse_bits_in_byte (xs : bits(8)) -> bits(8) = {
  var ys : bits(8) = zeros();
  foreach (i from 0 to 7)
    ys[i] = xs[7-i];
  ys
}

overload reverse = {reverse_bits_in_byte}

overload operator / = {quot_positive_round_zero, quot_round_zero}
overload operator * = {mult_atom, mult_int}

val readmem = pure "readmem" : (bits(64), bits(64)) -> bits(64)
val writemem = pure "writemem" : (bits(64), bits(64), bits(64), bits(64)) -> unit
val exception_raised = pure "get_exception" : (unit) -> bool
