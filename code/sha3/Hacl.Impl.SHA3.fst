module Hacl.Impl.SHA3

open FStar.HyperStack.All
open FStar.HyperStack
open FStar.HyperStack.ST
open FStar.Mul

open LowStar.Buffer
open LowStar.BufferOps

open Lib.IntTypes
open Lib.Buffer
open Lib.ByteBuffer

open Spec.SHA3.Constants

module ST = FStar.HyperStack.ST
module B = LowStar.Buffer
module LSeq = Lib.Sequence
module LB = Lib.ByteSequence
module Loop = Lib.LoopCombinators
module S = Spec.SHA3

let keccak_rotc :x:glbuffer rotc_t 24ul{witnessed x keccak_rotc /\ recallable x}
  = createL_global rotc_list

let keccak_piln :x:glbuffer piln_t 24ul{witnessed x keccak_piln /\ recallable x}
  = createL_global piln_list

let keccak_rndc :x:glbuffer pub_uint64 24ul{witnessed x keccak_rndc /\ recallable x}
  = createL_global rndc_list

#reset-options "--z3rlimit 50 --max_fuel 0 --max_ifuel 0 --using_facts_from '* -FStar.Seq'"

inline_for_extraction noextract
let state = lbuffer uint64 25ul

inline_for_extraction noextract
let index = n:size_t{v n < 5}

inline_for_extraction noextract
val readLane:
    s:state
  -> x:index
  -> y:index
  -> Stack uint64
    (requires fun h -> live h s)
    (ensures  fun h0 r h1 ->
      modifies loc_none h0 h1 /\
      r == S.readLane (as_seq h0 s) (v x) (v y))
let readLane s x y = s.(x +! 5ul *! y)

inline_for_extraction noextract
val writeLane:
    s:state
  -> x:index
  -> y:index
  -> v:uint64
  -> Stack unit
    (requires fun h -> live h s)
    (ensures  fun h0 _ h1 ->
      modifies (loc s) h0 h1 /\
      as_seq h1 s == S.writeLane (as_seq h0 s) (size_v x) (size_v y) v)
let writeLane s x y v = s.(x +! 5ul *! y) <- v

[@"c_inline"]
let rotl (a:uint64) (b:size_t{0 < uint_v b /\ uint_v b < 64}) =
  rotate_left a b

inline_for_extraction noextract
val state_theta0:
    s:state
  -> _C:lbuffer uint64 5ul
  -> Stack unit
    (requires fun h -> live h s /\ live h _C /\ disjoint _C s)
    (ensures  fun h0 _ h1 ->
      modifies (loc _C) h0 h1 /\
      as_seq h1 _C == S.state_theta0 (as_seq h0 s) (as_seq h0 _C))
let state_theta0 s _C =
  [@ inline_let]
  let spec h0 = S.state_theta_inner_C (as_seq h0 s) in
  let h0 = ST.get () in
  loop1 h0 5ul _C spec
  (fun x ->
    Loop.unfold_repeati 5 (spec h0) (as_seq h0 _C) (v x);
    _C.(x) <-
      readLane s x 0ul ^.
      readLane s x 1ul ^.
      readLane s x 2ul ^.
      readLane s x 3ul ^.
      readLane s x 4ul
  )

inline_for_extraction noextract
val state_theta_inner_s:
    _C:lbuffer uint64 5ul
  -> x:index
  -> s:state
  -> Stack unit
    (requires fun h0 -> live h0 s /\ live h0 _C /\ disjoint _C s)
    (ensures  fun h0 _ h1 ->
      modifies (loc s) h0 h1 /\
      as_seq h1 s == S.state_theta_inner_s (as_seq h0 _C) (v x) (as_seq h0 s))
let state_theta_inner_s _C x s =
  let _D = _C.((x +. 4ul) %. 5ul) ^. rotl _C.((x +. 1ul) %. 5ul) 1ul in
  [@ inline_let]
  let spec h0 = S.state_theta_inner_s_inner (v x) _D in
  let h0 = ST.get () in
  loop1 h0 5ul s spec
  (fun y ->
    Loop.unfold_repeati 5 (spec h0) (as_seq h0 s) (v y);
    writeLane s x y (readLane s x y ^. _D)
  )

inline_for_extraction noextract
val state_theta1:
     s:state
  -> _C:lbuffer uint64 5ul
  -> Stack unit
    (requires fun h0 -> live h0 s /\ live h0 _C /\ disjoint _C s)
    (ensures  fun h0 _ h1 ->
      modifies (loc s) h0 h1 /\
      as_seq h1 s == S.state_theta1 (as_seq h0 s) (as_seq h0 _C))
let state_theta1 s _C =
  [@ inline_let]
  let spec h0 = S.state_theta_inner_s (as_seq h0 _C) in
  let h0 = ST.get () in
  loop1 h0 5ul s spec
  (fun x ->
    Loop.unfold_repeati 5 (spec h0) (as_seq h0 s) (v x);
    state_theta_inner_s _C x s
  )

inline_for_extraction noextract
val state_theta:
    s:state
  -> Stack unit
    (requires fun h -> live h s)
    (ensures  fun h0 _ h1 ->
      modifies (loc s) h0 h1 /\
      as_seq h1 s == S.state_theta (as_seq h0 s))
let state_theta s =
  let h0 = ST.get() in
  let spec _ h1 = as_seq h1 s == S.state_theta (as_seq h0 s) /\ live h1 s in
  let footprint = Ghost.hide (loc s) in
  salloc1 h0 5ul (u64 0) (Ghost.hide (loc s)) spec
    (fun _C -> state_theta0 s _C; state_theta1 s _C)

#reset-options "--max_fuel 1 --max_ifuel 1 --z3rlimit 50"

private
val index_map: #a:Type -> #b:Type -> f:(a -> b) -> l:list a -> i:nat{i < List.Tot.length l} ->
  Lemma (List.Tot.index (List.Tot.map f l) i == f (List.Tot.index l i))
let rec index_map #a #b f l i =
  if i = 0 then ()
  else
    match l with
    | [] -> ()
    | _ :: l' -> index_map f l' (i - 1)

#reset-options "--max_fuel 0 --max_ifuel 0 --z3rlimit 100"

inline_for_extraction noextract
val state_pi_rho_inner:
    i:size_t{v i < 24}
  -> current:lbuffer uint64 1ul
  -> s:state
  -> Stack unit
    (requires fun h -> live h s /\ live h current /\ disjoint current s)
    (ensures  fun h0 _ h1 ->
      modifies (loc_union (loc s) (loc current)) h0 h1 /\
      (let c', s' = S.state_pi_rho_inner (v i) (bget h0 current 0, as_seq h0 s) in
      bget h1 current 0 == c' /\
      as_seq h1 s == s'))
let state_pi_rho_inner i current s =
  assert_norm (List.Tot.length piln_list == 24);
  let h0 = ST.get () in
  recall_contents keccak_rotc Spec.SHA3.Constants.keccak_rotc;
  recall_contents keccak_piln Spec.SHA3.Constants.keccak_piln;
  index_map v piln_list (v i);
  let _Y = keccak_piln.(i) in
  let r = keccak_rotc.(i) in
  let temp = s.(_Y) in
  s.(_Y) <- rotl current.(0ul) r;
  current.(0ul) <- temp

inline_for_extraction noextract
val state_pi_rho:
    s:state
  -> Stack unit
    (requires fun h -> live h s)
    (ensures  fun h0 _ h1 ->
      modifies (loc s) h0 h1 /\
      as_seq h1 s == S.state_pi_rho (as_seq h0 s))
let state_pi_rho s =
  let x = readLane s 1ul 0ul in
  let h0 = ST.get() in
  let spec _ h1 = as_seq h1 s == S.state_pi_rho (as_seq h0 s) /\ live h1 s in
  salloc1 h0 1ul x (Ghost.hide (loc s)) spec
     (fun current ->
         let h1 = ST.get () in
         assert (bget h1 current 0 == S.readLane (as_seq h0 s) 1 0);
         [@ inline_let]
         let refl h i : GTot (uint64 & S.state) = bget h current 0, as_seq h s in
         [@ inline_let]
         let footprint i = loc_union (loc current) (loc s) in
         [@ inline_let]
         let spec h0 = S.state_pi_rho_inner in
         let h0 = ST.get () in
         loop h0 24ul S.state_pi_rho_s refl footprint spec
         (fun i ->
           Loop.unfold_repeat_gen 24 S.state_pi_rho_s (spec h0) (refl h0 0) (v i);
           state_pi_rho_inner i current s
         )
     )

inline_for_extraction noextract
val state_chi_inner:
    s_pi_rho:state
  -> y:index
  -> x:index
  -> s:state
  -> Stack unit
    (requires fun h0 -> live h0 s_pi_rho /\ live h0 s /\ disjoint s_pi_rho s)
    (ensures  fun h0 _ h1 ->
      modifies (loc s) h0 h1 /\
      as_seq h1 s == S.state_chi_inner (as_seq h0 s_pi_rho) (v y) (v x) (as_seq h0 s))
let state_chi_inner s_pi_rho y x s =
  writeLane s x y
    (readLane s_pi_rho x y ^.
     ((lognot (readLane s_pi_rho ((x +. 1ul) %. 5ul) y)) &.
     readLane s_pi_rho ((x +. 2ul) %. 5ul) y))

inline_for_extraction noextract
val state_chi_inner1:
    s_pi_rho:state
  -> y:index
  -> s:state
  -> Stack unit
    (requires fun h0 -> live h0 s_pi_rho /\ live h0 s /\ disjoint s_pi_rho s)
    (ensures  fun h0 _ h1 ->
      modifies (loc s) h0 h1 /\
      as_seq h1 s == S.state_chi_inner1 (as_seq h0 s_pi_rho) (v y) (as_seq h0 s))
let state_chi_inner1 s_pi_rho y s =
  [@ inline_let]
  let spec h0 = S.state_chi_inner (as_seq h0 s_pi_rho) (v y) in
  let h0 = ST.get () in
  loop1 h0 5ul s spec
  (fun x ->
    Loop.unfold_repeati 5 (spec h0) (as_seq h0 s) (v x);
    state_chi_inner s_pi_rho y x s
  )

inline_for_extraction noextract
val state_chi:
    s:state
  -> Stack unit
    (requires fun h -> live h s)
    (ensures  fun h0 _ h1 ->
      modifies (loc s) h0 h1 /\
      as_seq h1 s == S.state_chi (as_seq h0 s))
let state_chi s =
  let h0 = ST.get() in
  let spec _ h1 = as_seq h1 s == S.state_chi (as_seq h0 s) /\ live h1 s in
  salloc1 h0 25ul (u64 0) (Ghost.hide (loc s)) spec
    (fun s_pi_rho ->
      copy s_pi_rho s;
      [@ inline_let]
      let spec h0 = S.state_chi_inner1 (as_seq h0 s_pi_rho) in
      let h0 = ST.get () in
      loop1 h0 5ul s spec
      (fun y ->
        Loop.unfold_repeati 5 (spec h0) (as_seq h0 s) (v y);
        state_chi_inner1 s_pi_rho y s
      )
    )

inline_for_extraction noextract
val state_iota:
    s:state
  -> round:size_t{v round < 24}
  -> Stack unit
    (requires fun h -> live h s)
    (ensures  fun h0 _ h1 ->
      modifies (loc s) h0 h1 /\
      as_seq h1 s == S.state_iota (as_seq h0 s) (v round))
let state_iota s round =
  recall_contents keccak_rndc Spec.SHA3.Constants.keccak_rndc;
  let c = keccak_rndc.(round) in
  writeLane s 0ul 0ul (readLane s 0ul 0ul ^. secret c)

val state_permute:
    s:state
  -> Stack unit
    (requires fun h -> live h s)
    (ensures  fun h0 _ h1 ->
      modifies (loc s) h0 h1 /\
      as_seq h1 s == S.state_permute (as_seq h0 s))
let state_permute s =
  [@ inline_let]
  let spec h0 = S.state_permute1 in
  let h0 = ST.get () in
  loop1 h0 24ul s spec
  (fun round ->
    Loop.unfold_repeati 24 (spec h0) (as_seq h0 s) (v round);
    state_theta s;
    state_pi_rho s;
    state_chi s;
    state_iota s round)

val loadState:
    rateInBytes:size_t{v rateInBytes <= 200}
  -> input:lbuffer uint8 rateInBytes
  -> s:state
  -> Stack unit
    (requires fun h -> live h input /\ live h s /\ disjoint input s)
    (ensures  fun h0 _ h1 ->
      modifies (loc s) h0 h1 /\
      as_seq h1 s == S.loadState (v rateInBytes) (as_seq h0 input) (as_seq h0 s))
let loadState rateInBytes input s =
  let h0 = ST.get() in
  let spec _ h1 = as_seq h1 s ==
    S.loadState (v rateInBytes) (as_seq h0 input) (as_seq h0 s) /\ live h1 s in
  salloc1 h0 200ul (u8 0) (Ghost.hide (loc s)) spec
    (fun block ->
      update_sub block 0ul rateInBytes input;
      [@ inline_let]
      let spec h0 = S.loadState_inner (as_seq h0 block) in
      let h0 = ST.get () in
      loop1 h0 25ul s spec
      (fun j ->
        Loop.unfold_repeati 25 (spec h0) (as_seq h0 s) (v j);
        let h0 = ST.get() in
        let x = uint_from_bytes_le #U64 (sub block (j *! 8ul) 8ul) in
        s.(j) <- s.(j) ^. x
      ))

inline_for_extraction noextract
val storeState_inner:
    s:state
  -> j:size_t{v j < 25}
  -> block:lbuffer uint8 200ul
  -> Stack unit
    (requires fun h0 -> live h0 s /\ live h0 block /\ disjoint s block)
    (ensures  fun h0 _ h1 ->
      modifies (loc block) h0 h1 /\
      as_seq h1 block == S.storeState_inner (as_seq h0 s) (v j) (as_seq h0 block))
let storeState_inner s j block =
  let sj = s.(j) in
  let h0 = ST.get () in
  update_sub_f h0 block (j *! 8ul) 8ul
    (fun h -> Lib.ByteSequence.uint_to_bytes_le sj)
    (fun _ -> uint_to_bytes_le #U64 (sub block (j *! 8ul) 8ul) sj)

val storeState:
    rateInBytes:size_t{v rateInBytes <= 200}
  -> s:state
  -> res:lbuffer uint8 rateInBytes
  -> Stack unit
    (requires fun h0 -> live h0 s /\ live h0 res)
    (ensures  fun h0 _ h1 ->
      modifies (loc res) h0 h1 /\
      as_seq h1 res == S.storeState (v rateInBytes) (as_seq h0 s))
let storeState rateInBytes s res =
  let h0 = ST.get() in
  let spec _ h1 = as_seq h1 res == S.storeState (v rateInBytes) (as_seq h0 s) /\ live h1 res in
  salloc1 h0 200ul (u8 0) (Ghost.hide (loc res)) spec
    (fun block ->
      [@ inline_let]
      let spec h0 = S.storeState_inner (as_seq h0 s) in
      let h0 = ST.get () in
      loop1 h0 25ul block spec
      (fun j ->
        Loop.unfold_repeati 25 (spec h0) (as_seq h0 block) (v j);
        storeState_inner s j block
      );
      copy res (sub block 0ul rateInBytes)
    )

(* 
   Lemma lemma_equiv_alloc_bigger_state proves that it is equivalent
   to allocate a bigger temporary buffer and then use a part of it 
   compared to allocation of the exact size buffer *)

val lemma_equiv_alloc_bigger_state: #len: size_nat -> #t: inttype -> #l: secrecy_level 
  -> a:size_t{v a > 0 /\ v a <= len} 
  -> Lemma (
    let input0 = Lib.Sequence.create #(int_t t l) (v a) (mk_int #t #l 0) in
    let nextBlock_1 = Lib.Sequence.create #(int_t t l) len (mk_int #t #l 0) in 
    let input1 = Lib.Sequence.sub #(int_t t l) #len nextBlock_1 0 (v a) in 
    input0 == input1)
let lemma_equiv_alloc_bigger_state #len #t #l a  = 
  let input0 = Lib.Sequence.create #(int_t t l) (v a) (mk_int #t #l 0) in
  let nextBlock_1 = Lib.Sequence.create #(int_t t l) len (mk_int #t #l 0) in 
  let input1 = Lib.Sequence.sub #(int_t t l) #len nextBlock_1 0 (v a) in 
  Seq.lemma_eq_intro input0 input1


#reset-options "--z3rlimit 50 --max_fuel 0 --max_ifuel 0 --using_facts_from '* -FStar.Seq'"

inline_for_extraction noextract
val absorb_next:
    s:state
  -> rateInBytes:size_t{v rateInBytes > 0 /\ v rateInBytes <= 200}
  -> Stack unit
    (requires fun h -> live h s)
    (ensures  fun h0 _ h1 ->
      modifies (loc s) h0 h1 /\
      as_seq h1 s == S.absorb_next (as_seq h0 s) (v rateInBytes))
let absorb_next s rateInBytes =
  let h0 = ST.get() in
  let spec _ h1 = as_seq h1 s == S.absorb_next (as_seq h0 s) (v rateInBytes) /\ live h1 s in
  salloc1 h0 200ul (u8 0) (Ghost.hide (loc s)) spec
    (fun tempBlock ->
      let nextBlock = sub tempBlock (size 0) rateInBytes in 
      nextBlock.(rateInBytes -! 1ul) <- u8 0x80;
      loadState rateInBytes nextBlock s;
      state_permute s;
      lemma_equiv_alloc_bigger_state #200 #U8 #SEC rateInBytes)

inline_for_extraction noextract
val absorb_last_:
    delimitedSuffix:byte_t
  -> rateInBytes:size_t{0 < v rateInBytes /\ v rateInBytes <= 200}
  -> rem:size_t{v rem < v rateInBytes}
  -> input:lbuffer uint8 rem
  -> s:state
  -> Stack unit
    (requires fun h -> live h s /\ live h input /\ disjoint s input)
    (ensures  fun h0 _ h1 ->
      modifies (loc s) h0 h1 /\
      as_seq h1 s ==
      S.absorb_last delimitedSuffix (v rateInBytes) (v rem)
        (as_seq h0 input) (as_seq h0 s))
let absorb_last_ delimitedSuffix rateInBytes rem input s =
  let h0 = ST.get() in
  let spec _ h1 =
    as_seq h1 s ==
    S.absorb_last delimitedSuffix (v rateInBytes) (v rem) (as_seq h0 input) (as_seq h0 s) /\
    live h1 s in
  salloc1 h0 200ul (u8 0) (Ghost.hide (loc s)) spec
    (fun temp ->
      let open Lib.RawIntTypes in
      let lastBlock = sub temp (size 0) rateInBytes in 
      update_sub lastBlock (size 0) rem input;
      lastBlock.(rem) <- byte_to_uint8 delimitedSuffix;
      loadState rateInBytes lastBlock s;
      if not ((delimitedSuffix &. byte 0x80) =. byte 0) &&
         (size_to_UInt32 rem = size_to_UInt32 (rateInBytes -. 1ul))
      then state_permute s;
      absorb_next s rateInBytes;
      lemma_equiv_alloc_bigger_state #200 #U8 #SEC rateInBytes)

private
inline_for_extraction noextract
val positive_and_lte: a: size_t -> b: size_t -> Tot (r: bool {
  r == not (v a > 0 && v a <= v b)})
let positive_and_lte a b = 
  let a_is_zero = eq a (size 0) in 
  let a_gt_b = gt a b in 
  a_is_zero || a_gt_b

val absorb_last:
    delimitedSuffix:byte_t
  -> rateInBytes:size_t
  -> rem:size_t
  -> input:lbuffer uint8 rem
  -> s:state
  -> Stack bool
    (requires fun h -> live h s /\ live h input /\ disjoint s input)
    (ensures  fun h0 success h1 ->
      modifies (loc s) h0 h1 /\ (
      if v rateInBytes > 0 && v rateInBytes <= 200 && v rem < v rateInBytes then
	success /\
	as_seq h1 s ==
	S.absorb_last delimitedSuffix (v rateInBytes) (v rem)
          (as_seq h0 input) (as_seq h0 s)
      else 
	~ success))
let absorb_last delimitedSuffix rateInBytes rem input s =
  if positive_and_lte rateInBytes (size 200) || gte rem rateInBytes then 
    false
  else begin
    absorb_last_ delimitedSuffix rateInBytes rem input s; 
    true
  end

inline_for_extraction noextract
val absorb_inner_:
    rateInBytes:size_t{0 < v rateInBytes /\ v rateInBytes <= 200}
  -> block:lbuffer uint8 rateInBytes
  -> s:state
  -> Stack unit
    (requires fun h0 -> live h0 s /\ live h0 block /\ disjoint s block)
    (ensures  fun h0 _ h1 ->
      modifies (loc s) h0 h1 /\
      as_seq h1 s ==
      S.absorb_inner (v rateInBytes) (as_seq h0 block) (as_seq h0 s))
let absorb_inner_ rateInBytes block s =
  loadState rateInBytes block s;
  state_permute s

val absorb_inner:
    rateInBytes:size_t
  -> block:lbuffer uint8 rateInBytes
  -> s:state
  -> Stack bool
    (requires fun h0 -> live h0 s /\ live h0 block /\ disjoint s block)
    (ensures  fun h0 success h1 ->
      modifies (loc s) h0 h1 /\ (
      if v rateInBytes > 0 && v rateInBytes <= 200 then
	success /\
	as_seq h1 s ==
	S.absorb_inner (v rateInBytes) (as_seq h0 block) (as_seq h0 s)
      else
	~ success))
let absorb_inner rateInBytes block s =
  if positive_and_lte rateInBytes (size 200) then 
    false
  else begin
    absorb_inner_ rateInBytes block s;
    true
  end

inline_for_extraction noextract
val absorb_:
    s:state
  -> rateInBytes:size_t{0 < v rateInBytes /\ v rateInBytes <= 200}
  -> inputByteLen:size_t
  -> input:lbuffer uint8 inputByteLen
  -> delimitedSuffix:byte_t
  -> Stack unit
    (requires fun h0 -> live h0 s /\ live h0 input /\ disjoint s input)
    (ensures  fun h0 _ h1 ->
      modifies (loc s) h0 h1 /\
      as_seq h1 s ==
      S.absorb (as_seq h0 s) (v rateInBytes) (v inputByteLen)
        (as_seq h0 input) delimitedSuffix)
let absorb_ s rateInBytes inputByteLen input delimitedSuffix =
  loop_blocks rateInBytes inputByteLen input
  (S.absorb_inner (v rateInBytes))
  (S.absorb_last delimitedSuffix (v rateInBytes))
  (absorb_inner_ rateInBytes)
  (absorb_last_ delimitedSuffix rateInBytes) s

val absorb:
    s:state
  -> rateInBytes:size_t
  -> inputByteLen:size_t
  -> input:lbuffer uint8 inputByteLen
  -> delimitedSuffix:byte_t
  -> Stack bool
    (requires fun h0 -> live h0 s /\ live h0 input /\ disjoint s input)
    (ensures fun h0 success h1 ->
      modifies (loc s) h0 h1 /\ (
      if v rateInBytes > 0 && v rateInBytes <= 200 then 
	success /\
	as_seq h1 s ==
	S.absorb (as_seq h0 s) (v rateInBytes) (v inputByteLen)
          (as_seq h0 input) delimitedSuffix
      else
	~ success ))

let absorb s rateInBytes inputByteLen input delimitedSuffix = 
  if positive_and_lte rateInBytes (size 200) then 
    false
  else begin
    absorb_ s rateInBytes inputByteLen input delimitedSuffix;
    true
  end

inline_for_extraction noextract
val squeeze_inner:
    rateInBytes:size_t{0 < v rateInBytes /\ v rateInBytes <= 200}
  -> outputByteLen:size_t
  -> s:state
  -> output:lbuffer uint8 rateInBytes
  -> i:size_t{v i < v (outputByteLen /. rateInBytes)}
  -> Stack unit
    (requires fun h0 -> live h0 s /\ live h0 output /\ disjoint s output)
    (ensures  fun h0 _ h1 ->
      modifies2 s output h0 h1 /\
      (as_seq h1 s, as_seq h1 output) ==
      S.squeeze_inner (v rateInBytes) (v outputByteLen) (v i) (as_seq h0 s))
let squeeze_inner rateInBytes outputByteLen s output i =
  storeState rateInBytes s output;
  state_permute s

#reset-options "--z3rlimit 300 --max_fuel 0 --max_ifuel 0"

private
let mult_plus_lt (i a b:nat) : Lemma (requires i < a) (ensures  i * b + b <= a * b) =
  assert (i <= a - 1)

inline_for_extraction noextract
val squeeze_:
    s:state
  -> rateInBytes:size_t{0 < v rateInBytes /\ v rateInBytes <= 200}
  -> outputByteLen:size_t
  -> output:lbuffer uint8 outputByteLen
  -> Stack unit
    (requires fun h0 -> live h0 s /\ live h0 output /\ disjoint s output)
    (ensures  fun h0 _ h1 ->
      modifies2 s output h0 h1 /\
      as_seq h1 output == S.squeeze (as_seq h0 s) (v rateInBytes) (v outputByteLen))
let squeeze_ s rateInBytes outputByteLen output =
  let outBlocks = outputByteLen /. rateInBytes in
  let remOut = outputByteLen %. rateInBytes in
  assert_spinoff (v outputByteLen - v remOut == v outBlocks * v rateInBytes);
  let last = sub output (outputByteLen -. remOut) remOut in
  [@ inline_let]
  let a_spec (i:nat{i <= v outputByteLen / v rateInBytes}) = S.state in
  let blocks = sub output (size 0) (outBlocks *! rateInBytes) in
  let h0 = ST.get() in
  fill_blocks h0 rateInBytes outBlocks blocks a_spec
    (fun h i -> as_seq h s)
    (fun _ -> loc s)
    (fun h0 -> S.squeeze_inner (v rateInBytes) (v outputByteLen))
    (fun i ->
      mult_plus_lt (v i) (v outBlocks) (v rateInBytes);
      squeeze_inner rateInBytes outputByteLen s (sub blocks (i *! rateInBytes) rateInBytes) i);
  storeState remOut s last;
  let h1 = ST.get() in
  Seq.lemma_split (as_seq h1 output) (v outBlocks * v rateInBytes);
  norm_spec [delta_only [`%S.squeeze]] (S.squeeze (as_seq h0 s) (v rateInBytes) (v outputByteLen))

val squeeze:
    s:state
  -> rateInBytes:size_t
  -> outputByteLen:size_t
  -> output:lbuffer uint8 outputByteLen
  -> Stack bool
    (requires fun h0 -> live h0 s /\ live h0 output /\ disjoint s output)
    (ensures  fun h0 success h1 ->
      modifies2 s output h0 h1 /\ (
      if v rateInBytes > 0 && v rateInBytes <= 200 then 
	success /\
	as_seq h1 output == S.squeeze (as_seq h0 s) (v rateInBytes) (v outputByteLen)
      else
	~success ))
let squeeze s rateInBytes outputByteLen output = 
  if positive_and_lte rateInBytes (size 200) then 
    false
  else begin
    squeeze_ s rateInBytes outputByteLen output;
    true
  end

inline_for_extraction noextract
val keccak_:
    rate:size_t{v rate % 8 == 0 /\ v rate / 8 > 0 /\ v rate <= 1600}
  -> inputByteLen:size_t
  -> input:lbuffer uint8 inputByteLen
  -> delimitedSuffix:byte_t
  -> outputByteLen:size_t
  -> output:lbuffer uint8 outputByteLen
  -> Stack unit
    (requires fun h -> live h input /\ live h output /\ disjoint input output)
    (ensures  fun h0 _ h1 ->
      modifies1 output h0 h1 /\ (
      let capacity = 1600 - v rate in 
      as_seq h1 output ==
      S.keccak (v rate) capacity (v inputByteLen) (as_seq h0 input) delimitedSuffix (v outputByteLen)))
let keccak_ rate inputByteLen input delimitedSuffix outputByteLen output =
  push_frame();
  let rateInBytes = rate /. size 8 in
  let s:state = create 25ul (u64 0) in
  absorb_ s rateInBytes inputByteLen input delimitedSuffix;
  squeeze_ s rateInBytes outputByteLen output;
  pop_frame()

val keccak:
    rate:size_t
  -> inputByteLen:size_t
  -> input:lbuffer uint8 inputByteLen
  -> delimitedSuffix:byte_t
  -> outputByteLen:size_t
  -> output:lbuffer uint8 outputByteLen
  -> Stack bool
    (requires fun h -> live h input /\ live h output /\ disjoint input output)
    (ensures  fun h0 success h1 ->
      modifies1 output h0 h1 /\ (
      let capacity = 1600 - v rate in 
      if v rate % 8 = 0 && v rate / 8 > 0 && v rate <= 1600 then
	success /\ 
	as_seq h1 output ==
	S.keccak (v rate) capacity (v inputByteLen) (as_seq h0 input) delimitedSuffix (v outputByteLen)
      else
	~ success))
let keccak rate inputByteLen input delimitedSuffix outputByteLen output = 
  let bit3mask = size 7 in 
  let rate_mod_8 = eq (logand rate bit3mask) (size 0) in 
    logand_mask rate bit3mask 3;  
  let rateInBytes = rate /. size 8 in 
  let rate_is_zero = eq rateInBytes (size 0) in 
  let rate_lte_200 = gt rateInBytes (size 200) in 
  if not rate_mod_8 || (rate_is_zero) || rate_lte_200 then begin
    false 
    end
  else begin
    keccak_ rate inputByteLen input delimitedSuffix outputByteLen output;
    true
  end
