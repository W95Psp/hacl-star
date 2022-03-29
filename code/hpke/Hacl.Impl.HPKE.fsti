module Hacl.Impl.HPKE

open FStar.HyperStack
open FStar.HyperStack.All

module B = LowStar.Buffer
open Lib.Buffer
open Lib.IntTypes

module S = Spec.Agile.HPKE

#set-options "--z3rlimit 20 --max_fuel 0 --max_ifuel 0"

inline_for_extraction noextract
let key_dh_public (cs:S.ciphersuite) = lbuffer uint8 (size (S.size_dh_public cs))
inline_for_extraction noextract
let key_dh_secret (cs:S.ciphersuite) = lbuffer uint8 (size (S.size_dh_key cs))
inline_for_extraction noextract
let serialized_point_dh (cs:S.ciphersuite) = lbuffer uint8 (size (S.size_dh_serialized cs))
inline_for_extraction noextract
let key_aead (cs:S.ciphersuite) = lbuffer uint8 (size (S.size_aead_key cs))
inline_for_extraction noextract
let nonce_aead (cs:S.ciphersuite) = lbuffer uint8 (size (S.size_aead_nonce cs))

(* Redefining this to work around Low*'s limitation on buffer size *)
let max_length_info (a:S.hash_algorithm) =
  max_size_t - S.size_label_version - S.size_suite_id_hpke - S.size_label_info_hash - Spec.Hash.Definitions.block_length a

val context_s (cs:S.ciphersuite) : Type0
val ctx_loc (#cs:S.ciphersuite) (ctx:context_s cs) : GTot B.loc
val ctx_invariant (#cs:S.ciphersuite) (h:mem) (ctx:context_s cs) : GTot prop
val as_ctx (#cs:S.ciphersuite) (h:mem) (ctx:context_s cs) : GTot (S.encryption_context cs)

val frame_ctx (#cs:S.ciphersuite) (ctx:context_s cs) (l:B.loc) (h0 h1:mem)
  : Lemma (requires ctx_invariant h0 ctx /\ B.loc_disjoint (ctx_loc ctx) l /\ modifies l h0 h1)
          (ensures ctx_invariant h1 ctx /\ as_ctx h0 ctx == as_ctx h1 ctx)
          [SMTPat (modifies l h0 h1); SMTPat (ctx_invariant h0 ctx)]

inline_for_extraction noextract
let setupBaseS_st (cs:S.ciphersuite) (p:Type0) =
     o_pkE: key_dh_public cs
  -> o_ctx: context_s cs
  -> skE: key_dh_secret cs
  -> pkR: serialized_point_dh cs
  -> infolen: size_t{v infolen <= max_length_info (S.hash_of_cs cs)}
  -> info: lbuffer uint8 infolen
  -> Stack UInt32.t
     (requires fun h0 ->
        p /\
        live h0 o_pkE /\
        ctx_invariant h0 o_ctx /\
        live h0 skE /\ live h0 pkR /\ live h0 info /\
        disjoint o_pkE skE /\ disjoint o_pkE pkR /\ disjoint o_pkE info /\
        B.loc_disjoint (ctx_loc o_ctx) (loc info) /\
        B.loc_disjoint (loc o_pkE) (ctx_loc o_ctx))
     (ensures fun h0 result h1 -> modifies (loc o_pkE |+| ctx_loc o_ctx) h0 h1 /\
       (let output = S.setupBaseS cs (as_seq h0 skE) (as_seq h0 pkR) (as_seq h0 info) in
        match result with
        | 0ul -> Some? output /\ (let pkE, ctx = Some?.v output in
          as_seq h1 o_pkE == pkE /\
          as_ctx h1 o_ctx == ctx)
        | 1ul -> None? output
        | _ -> False
        )
     )

inline_for_extraction noextract
let setupBaseR_st (cs:S.ciphersuite) (p:Type0) =
     o_ctx : context_s cs
  -> pkE: key_dh_public cs
  -> skR: key_dh_secret cs
  -> infolen: size_t{v infolen <= max_length_info (S.hash_of_cs cs)}
  -> info: lbuffer uint8 infolen
  -> Stack UInt32.t
     (requires fun h0 ->
        p /\
        ctx_invariant h0 o_ctx /\
        live h0 pkE /\ live h0 skR /\ live h0 info /\
        B.loc_disjoint (ctx_loc o_ctx) (loc info)
      )
     (ensures fun h0 result h1 -> modifies (ctx_loc o_ctx) h0 h1 /\
       (let output = S.setupBaseR cs (as_seq h0 pkE) (as_seq h0 skR) (as_seq h0 info) in
       match result with
       | 0ul -> Some? output /\ (let ctx = Some?.v output in
         as_ctx h1 o_ctx == ctx)
       | 1ul -> None? output
       | _ -> False
       )
     )

(*
inline_for_extraction noextract
let sealBase_st (cs:S.ciphersuite) (p:Type0) =
     skE: key_dh_secret cs
  -> pkR: key_dh_public cs
  -> mlen: size_t{v mlen <= S.max_length cs /\ v mlen + S.size_dh_public cs + 16 <= max_size_t}
  -> m:lbuffer uint8 mlen
  -> infolen: size_t {v infolen <= S.max_info}
  -> info: lbuffer uint8 infolen
  -> output: lbuffer uint8 (size (v mlen + S.size_dh_public cs + 16))
  -> Stack UInt32.t
       (requires fun h0 ->
         p /\
         live h0 output /\ live h0 skE /\ live h0 pkR /\
         live h0 m /\ live h0 info /\
         disjoint output pkR /\ disjoint output info /\ disjoint output m /\ disjoint output skE)
       (ensures fun h0 result h1 -> modifies (loc output) h0 h1 /\
         (let sealed = S.sealBase cs (as_seq h0 skE) (as_seq h0 pkR) (as_seq h0 m) (as_seq h0 info) in
         match result with
         | 0ul -> Some? sealed /\ as_seq h1 output `Seq.equal` Some?.v sealed
         | 1ul -> None? sealed
         | _ -> False)
       )

inline_for_extraction noextract
let openBase_st (cs:S.ciphersuite) (p:Type0) =
     pkE: key_dh_public cs
  -> skR: key_dh_secret cs
  -> mlen: size_t{S.size_dh_public cs + S.size_aead_tag cs <= v mlen /\ v mlen <= S.max_length cs}
  -> m:lbuffer uint8 mlen
  -> infolen: size_t {v infolen <= S.max_info}
  -> info: lbuffer uint8 infolen
  -> output: lbuffer uint8 (size (v mlen - S.size_dh_public cs - S.size_aead_tag cs))
  -> Stack UInt32.t
       (requires fun h0 ->
         p /\
         live h0 output /\ live h0 pkE /\ live h0 skR /\
         live h0 m /\ live h0 info /\
         disjoint output info /\ disjoint output m)
       (ensures fun h0 z h1 -> modifies (loc output) h0 h1 /\
         (let plain = S.openBase cs (as_seq h0 skR) (as_seq h0 m) (as_seq h0 info) in
         match z with
         | 0ul -> Some? plain /\ as_seq h1 output == Some?.v plain
         | 1ul -> None? plain
         | _ -> False))
*)

noextract inline_for_extraction
val setupBaseS: #cs:S.ciphersuite -> setupBaseS_st cs True

noextract inline_for_extraction
val setupBaseR: #cs:S.ciphersuite -> setupBaseR_st cs True

(*
noextract inline_for_extraction
val sealBase: #cs:S.ciphersuite -> sealBase_st cs True

noextract inline_for_extraction
val openBase: #cs:S.ciphersuite -> openBase_st cs True
*)
