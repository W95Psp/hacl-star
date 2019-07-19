module Hacl.Bignum25519

module ST = FStar.HyperStack.ST
open FStar.HyperStack.All

open Lib.IntTypes
open Lib.ByteSequence
open Lib.Buffer

module S51 = Hacl.Spec.Curve25519.Field51.Definition
module S56 = Hacl.Spec.Ed25519.Field56.Definition
module F51 = Hacl.Impl.Ed25519.Field51
module F56 = Hacl.Impl.Ed25519.Field56

(* Type abbreviations *)
inline_for_extraction noextract
let felem = lbuffer uint64 5ul

(* A point is buffer of size 20, that is 4 consecutive buffers of size 5 *)
inline_for_extraction noextract
let point = lbuffer uint64 20ul

#set-options "--z3rlimit 10 --max_fuel 0 --max_ifuel 0"

inline_for_extraction noextract
let getx (p:point) : Stack felem
  (requires fun h -> live h p)
  (ensures fun h0 f h1 -> f == gsub p 0ul 5ul /\ h0 == h1)
  = sub p 0ul 5ul
inline_for_extraction noextract
let gety (p:point) : Stack felem
  (requires fun h -> live h p)
  (ensures fun h0 f h1 -> f == gsub p 5ul 5ul /\ h0 == h1)
  = sub p 5ul 5ul
inline_for_extraction noextract
let getz (p:point) : Stack felem
  (requires fun h -> live h p)
  (ensures fun h0 f h1 -> f == gsub p 10ul 5ul /\ h0 == h1)
  = sub p 10ul 5ul
inline_for_extraction noextract
let gett (p:point) : Stack felem
  (requires fun h -> live h p)
  (ensures fun h0 f h1 -> f == gsub p 15ul 5ul /\ h0 == h1)
  = sub p 15ul 5ul

inline_for_extraction noextract
val make_u64_5:
    b:lbuffer uint64 5ul
  -> s0:uint64 -> s1:uint64 -> s2:uint64 -> s3:uint64 -> s4:uint64 ->
  Stack unit
    (requires fun h -> live h b)
    (ensures  fun h0 _ h1 -> modifies (loc b) h0 h1 /\
      F51.as_nat h1 b == S51.as_nat5 (s0, s1, s2, s3, s4)
    )

inline_for_extraction noextract
val make_u64_10:
    b:lbuffer uint64 10ul
  -> s0:uint64 -> s1:uint64 -> s2:uint64 -> s3:uint64 -> s4:uint64
  -> s5:uint64 -> s6:uint64 -> s7:uint64 -> s8:uint64 -> s9:uint64 ->
  Stack unit
    (requires fun h -> live h b)
    (ensures  fun h0 _ h1 -> modifies (loc b) h0 h1)

inline_for_extraction noextract
val make_u128_9:
    b:lbuffer uint128 9ul
  -> s0:uint128 -> s1:uint128 -> s2:uint128 -> s3:uint128 -> s4:uint128
  -> s5:uint128 -> s6:uint128 -> s7:uint128 -> s8:uint128 ->
  Stack unit
    (requires fun h -> live h b)
    (ensures fun h0 _ h1 -> modifies (loc b) h0 h1)

inline_for_extraction noextract
val make_zero:
  b:lbuffer uint64 5ul ->
  Stack unit
    (requires fun h -> live h b)
    (ensures  fun h0 _ h1 -> modifies (loc b) h0 h1 /\
      F51.fevalh h1 b == Spec.Curve25519.zero
    )

inline_for_extraction noextract
val make_one:
  b:lbuffer uint64 5ul ->
  Stack unit
    (requires fun h -> live h b)
    (ensures  fun h0 _ h1 -> modifies (loc b) h0 h1 /\
      F51.fevalh h1 b == Spec.Curve25519.one
    )

val fsum:
    a:felem
  -> b:felem ->
  Stack unit
    (requires fun h -> live h a /\ live h b /\ disjoint a b)
    (ensures  fun h0 _ h1 -> modifies (loc a) h0 h1)

val fdifference:
    a:felem
  -> b:felem ->
  Stack unit
    (requires fun h -> live h a /\ live h b /\ disjoint a b)
    (ensures  fun h0 _ h1 -> modifies (loc a) h0 h1)

val reduce_513:
  a:felem ->
  Stack unit
    (requires fun h -> live h a)
    (ensures  fun h0 _ h1 -> modifies (loc a) h0 h1)

val fdifference_reduced:
    a:felem
  -> b:felem ->
  Stack unit
    (requires fun h -> live h a /\ live h b /\ disjoint a b)
    (ensures  fun h0 _ h1 -> modifies (loc a) h0 h1)

val fmul:
    out:felem
  -> a:felem
  -> b:felem ->
  Stack unit
    (requires fun h -> live h out /\ live h a /\ live h b)
    (ensures  fun h0 _ h1 -> modifies (loc out) h0 h1 /\
      F51.fevalh h1 out == Spec.Curve25519.fmul (F51.fevalh h0 a) (F51.fevalh h0 b)
    )

val times_2:
    out:felem
  -> a:felem ->
  Stack unit
    (requires fun h -> live h out /\ live h a)
    (ensures  fun h0 _ h1 -> modifies (loc out) h0 h1)

val times_d:
    out:felem
  -> a:felem ->
  Stack unit
    (requires fun h -> live h out /\ live h a)
    (ensures  fun h0 _ h1 -> modifies (loc out) h0 h1)

val times_2d:
    out:felem
  -> a:felem ->
  Stack unit
    (requires fun h -> live h out /\ live h a)
    (ensures  fun h0 _ h1 -> modifies (loc out) h0 h1)

val fsquare:
    out:felem
  -> a:felem ->
  Stack unit
    (requires fun h -> live h out /\ live h a /\ disjoint a out)
    (ensures  fun h0 _ h1 -> modifies (loc out) h0 h1)

val fsquare_times:
    out:felem
  -> a:felem
  -> n:size_t{v n > 0} ->
  Stack unit
    (requires fun h -> live h out /\ live h a /\ disjoint out a)
    (ensures  fun h0 _ h1 -> modifies (loc out) h0 h1)

val fsquare_times_inplace:
    out:felem
  -> n:size_t{v n > 0} ->
  Stack unit
    (requires fun h -> live h out)
    (ensures  fun h0 _ h1 -> modifies (loc out) h0 h1)

val inverse:
    out:felem
  -> a:felem ->
  Stack unit
    (requires fun h -> live h out /\ live h a /\ disjoint a out)
    (ensures  fun h0 _ h1 -> modifies (loc out) h0 h1 /\
      F51.fevalh h1 out == Spec.Ed25519.modp_inv (F51.fevalh h0 a)
    )

val reduce:
  out:felem ->
  Stack unit
    (requires fun h -> live h out)
    (ensures  fun h0 _ h1 -> modifies (loc out) h0 h1 /\
      F51.fevalh h1 out == F51.as_nat h1 out /\
      F51.fevalh h0 out == F51.as_nat h1 out
    )

val load_51:
    output:lbuffer uint64 5ul
  -> input:lbuffer uint8 32ul ->
  Stack unit
    (requires fun h -> live h output /\ live h input)
    (ensures  fun h0 _ h1 -> modifies (loc output) h0 h1 /\
      F51.as_nat h1 output == nat_from_bytes_le (as_seq h0 input)
    )

val store_51:
    output:lbuffer uint8 32ul
  -> input:lbuffer uint64 5ul ->
  Stack unit
    (requires fun h -> live h input /\ live h output)
    (ensures fun h0 _ h1 -> modifies (loc output) h0 h1 /\
      as_seq h1 output == nat_to_bytes_le 32 (F51.fevalh h0 input)
    )
