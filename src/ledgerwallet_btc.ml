(*---------------------------------------------------------------------------
   Copyright (c) 2017 Vincent Bernardoff. All rights reserved.
   Distributed under the ISC license, see terms at the end of the file.
  ---------------------------------------------------------------------------*)

open Ledgerwallet
open Sexplib.Std

type ins =
  | Setup
  | Verify_pin
  | Get_operation_mode
  | Set_operation_mode
  | Set_keymap
  | Set_comm_protocol
  | Get_wallet_public_key
  | Get_trusted_input
  | Hash_input_start
  | Hash_input_finalize
  | Hash_sign
  | Hash_input_finalize_full
  | Get_internal_chain_index
  | Sign_message
  | Get_transaction_limit
  | Set_transaction_limit
  | Import_private_key
  | Get_public_key
  | Derive_bip32_key
  | Signverify_immediate
  | Get_random
  | Get_attestation
  | Get_firmware_version
  | Compose_mofn_address
  | Dongle_authenticate
  | Get_pos_seed

let int_of_ins = function
  | Setup -> 0x20
  | Verify_pin -> 0x22
  | Get_operation_mode -> 0x24
  | Set_operation_mode -> 0x26
  | Set_keymap -> 0x28
  | Set_comm_protocol -> 0x2a
  | Get_wallet_public_key -> 0x40
  | Get_trusted_input -> 0x42
  | Hash_input_start -> 0x44
  | Hash_input_finalize -> 0x46
  | Hash_sign -> 0x48
  | Hash_input_finalize_full -> 0x4a
  | Get_internal_chain_index -> 0x4c
  | Sign_message -> 0x4e
  | Get_transaction_limit -> 0xa0
  | Set_transaction_limit -> 0xa2
  | Import_private_key -> 0xb0
  | Get_public_key -> 0xb2
  | Derive_bip32_key -> 0xb4
  | Signverify_immediate -> 0xb6
  | Get_random -> 0xc0
  | Get_attestation -> 0xc2
  | Get_firmware_version -> 0xc4
  | Compose_mofn_address -> 0xc6
  | Dongle_authenticate -> 0xc8
  | Get_pos_seed -> 0xca

let ins_of_int = function
  | 0x20 -> Setup
  | 0x22 -> Verify_pin
  | 0x24 -> Get_operation_mode
  | 0x26 -> Set_operation_mode
  | 0x28 -> Set_keymap
  | 0x2a -> Set_comm_protocol
  | 0x40 -> Get_wallet_public_key
  | 0x42 -> Get_trusted_input
  | 0x44 -> Hash_input_start
  | 0x46 -> Hash_input_finalize
  | 0x48 -> Hash_sign
  | 0x4a -> Hash_input_finalize_full
  | 0x4c -> Get_internal_chain_index
  | 0x4e -> Sign_message
  | 0xa0 -> Get_transaction_limit
  | 0xa2 -> Set_transaction_limit
  | 0xb0 -> Import_private_key
  | 0xb2 -> Get_public_key
  | 0xb4 -> Derive_bip32_key
  | 0xb6 -> Signverify_immediate
  | 0xc0 -> Get_random
  | 0xc2 -> Get_attestation
  | 0xc4 -> Get_firmware_version
  | 0xc6 -> Compose_mofn_address
  | 0xc8 -> Dongle_authenticate
  | 0xca -> Get_pos_seed
  | _ -> invalid_arg "Adpu.ins_of_int"

type adm_ins =
  | Init_keys
  | Init_attestation
  | Get_update_id
  | Firmware_update

let int_of_adm_ins = function
  | Init_keys -> 0x20
  | Init_attestation -> 0x22
  | Get_update_id -> 0x24
  | Firmware_update -> 0x42

let adm_ins_of_int = function
  | 0x20 -> Init_keys
  | 0x22 -> Init_attestation
  | 0x24 -> Get_update_id
  | 0x42 -> Firmware_update
  | _ -> invalid_arg "Adpu.adm_ins_of_int"

type cmd =
  | Adm_cla of adm_ins
  | Cla of ins

let cla_of_cmd = function
  | Adm_cla _ -> 0xd0
  | Cla _ -> 0xe0

let ins_of_cmd = function
  | Adm_cla adm_ins -> int_of_adm_ins adm_ins
  | Cla ins -> int_of_ins ins

let wrap_ins ins = Apdu.create_cmd ~cmd:(Cla ins) ~cla_of_cmd ~ins_of_cmd
let wrap_adm_ins ins = Apdu.create_cmd ~cmd:(Adm_cla ins) ~cla_of_cmd ~ins_of_cmd

let get_random ?buf h len =
  let random_str =
    Transport.apdu ?buf h Apdu.(create ~le:len (wrap_ins Get_random)) in
  Cstruct.to_string random_str

module Operation_mode = struct
  type mode =
    | Standard
    | Relaxed
    | Server
    | Developer
  [@@deriving sexp]

  let mode_of_int = function
    | 0 -> Standard
    | 1 -> Relaxed
    | 4 -> Server
    | 8 -> Developer
    | _ -> invalid_arg "Operation_mode.mode_of_int"

  type t = {
   mode : mode ;
   seed_not_redeemed : bool ;
  } [@@deriving sexp]

  let of_int v = {
    mode = mode_of_int (v land 7) ;
    seed_not_redeemed = (v land 8 <> 0) ;
  }
end

module Second_factor = struct
  type t =
    | Keyboard
    | Card
    | Card_screen [@@deriving sexp]

  let of_int = function
    | 0x11 -> Keyboard
    | 0x12 -> Card
    | 0x13 -> Card_screen
    | _ -> invalid_arg "Second_factor.of_int"
end

let get_operation_mode ?buf h =
  let b = Transport.apdu ?buf h Apdu.(create ~le:1 (wrap_ins Get_operation_mode)) in
  Operation_mode.of_int (Cstruct.get_uint8 b 0)

let get_second_factor ?buf h =
  let b = Transport.apdu ?buf h Apdu.(create ~p1:1 ~le:1 (wrap_ins Get_operation_mode)) in
  Second_factor.of_int (Cstruct.get_uint8 b 0)

module Firmware_version = struct
  type flag =
    | Public_key_compressed
    | Internal_screen_buttons
    | External_screen_buttons
    | Nfc
    | Ble
    | Tee
  [@@deriving sexp]

  let flag_of_bit = function
    | 0x01 -> Public_key_compressed
    | 0x02 -> Internal_screen_buttons
    | 0x04 -> External_screen_buttons
    | 0x08 -> Nfc
    | 0x10 -> Ble
    | 0x20 -> Tee
    | _ -> invalid_arg "Firmware_version.flag_of_bit"

  let flags_of_int i =
    List.fold_left begin fun a e ->
      if i land e <> 0 then
        flag_of_bit e :: a else a
    end [] [0x01; 0x02; 0x04; 0x08; 0x10; 0x20]

  type t = {
    flags : flag list ;
    arch : int ;
    major : int ;
    minor : int ;
    patch : int ;
    loader_major : int ;
    loader_minor : int ;
    loader_patch : int ;
  } [@@deriving sexp]

  let create ~flags ~arch ~major ~minor ~patch ~loader_major ~loader_minor ~loader_patch =
    let flags = flags_of_int flags in
    { flags ; arch ; major ; minor ; patch ; loader_major ; loader_minor ; loader_patch }
end

let get_firmware_version ?buf h =
  let open EndianString.BigEndian in
  let b = Transport.apdu ?buf h Apdu.(create ~le:7 (wrap_ins Get_firmware_version)) in
  let open Cstruct in
  let flags = get_uint8 b 0 in
  let arch = get_uint8 b 1 in
  let major = get_uint8 b 2 in
  let minor = get_uint8 b 3 in
  let patch = get_uint8 b 4 in
  let loader_major = get_uint8 b 5 land 0x0f in
  let loader_minor = get_uint8 b 6 lsr 4 in
  let loader_patch = get_uint8 b 6 land 0x0f in
  Firmware_version.create flags arch major minor patch loader_major loader_minor loader_patch

let verify_pin ?buf h pin =
  let lc = String.length pin in
  let b = Transport.apdu ?buf h Apdu.(create_string ~lc ~data:pin (wrap_ins Verify_pin)) in
  match Cstruct.get_uint8 b 0 with
  | 0x01 -> `Need_power_cycle
  | _ -> `Ok

let get_remaining_pin_attempts ?buf h =
  Transport.write_apdu ?buf h Apdu.(create_string ~p1:0x80 ~lc:1 ~data:"\x00" (wrap_ins Verify_pin)) ;
  match Transport.read ?buf h with
  | Transport.Status.Invalid_pin n, _ -> n
  | Ok, _ -> failwith "get_remaining_pin_attempts got OK"
  | s, _ -> failwith (Transport.Status.to_string s)

module Public_key = struct
  type t = {
    uncompressed : Cstruct.t ;
    b58addr : string ;
    bip32_chaincode : Cstruct.t ;
  } [@@deriving sexp]

  let create ~uncompressed ~b58addr ~bip32_chaincode = {
    uncompressed ; b58addr ; bip32_chaincode
  }

  let of_cstruct cs =
    let keylen = Cstruct.get_uint8 cs 0 in
    let uncompressed = Cstruct.create keylen in
    Cstruct.blit cs 1 uncompressed 0 keylen ;
    let addrlen = Cstruct.get_uint8 cs (1+keylen) in
    let b58addr = Bytes.create addrlen in
    Cstruct.blit_to_bytes cs (1+keylen+1) b58addr 0 addrlen ;
    let bip32_chaincode = Cstruct.create 32 in
    Cstruct.blit cs (1+keylen+1+addrlen) bip32_chaincode 0 32 ;
    create
      ~uncompressed
      ~b58addr:(Bytes.unsafe_to_string b58addr)
      ~bip32_chaincode,
    Cstruct.shift cs (1+keylen+1+addrlen+32)
end

let get_wallet_public_key ?pp ?buf h keyPath =
  let nb_derivations = List.length keyPath in
  if nb_derivations > 10 then invalid_arg "get_wallet_pubkeys: max 10 derivations" ;
  let lc = 1 + 4 * nb_derivations in
  let data_init = Cstruct.create lc in
  Cstruct.set_uint8 data_init 0 nb_derivations ;
  let data = Cstruct.shift data_init 1 in
  let _data = Bitcoin.Wallet.KeyPath.write_be_cstruct data keyPath in
  let b =
    Transport.apdu ?pp ?buf h Apdu.(create ~lc ~data:data_init (wrap_ins Get_wallet_public_key)) in
  fst (Public_key.of_cstruct b)

let ign_cs cs = ignore (cs : Cstruct.t)

let get_trusted_input ?pp ?buf h (tx : Bitcoin.Protocol.Transaction.t) index =
  let open Bitcoin in
  let ins = Get_trusted_input in
  let cs = Cstruct.create 100000 in
  Cstruct.BE.set_uint32 cs 0 (Int32.of_int index) ;
  Cstruct.LE.set_uint32 cs 4 (Int32.of_int tx.version) ;
  let cs' =
    Util.CompactSize.to_cstruct_int (Cstruct.shift cs 8) (List.length tx.inputs) in
  ign_cs (Transport.write_payload ?pp ~cmd:(wrap_ins ins)
            ?buf ~msg:"init" h (Cstruct.sub cs 0 cs'.off)) ;
  let p1 = 0x80 in
  ListLabels.iter tx.inputs ~f:begin fun txi ->
    let cs' = Protocol.TxIn.to_cstruct cs txi in
    match cs'.off mod Apdu.max_data_length with
    | len when len > 0 && len < 4 ->
      let cs1 = Cstruct.sub cs 0 (cs'.off - 4) in
      let cs2 = Cstruct.sub cs (cs'.off - 4) 4 in
      ign_cs (Transport.write_payload ?pp ~p1 ~cmd:(wrap_ins ins)
                h cs1 ~msg:"partial in 1") ;
      ign_cs (Transport.write_payload ?pp ~p1 ~cmd:(wrap_ins ins)
                h cs2 ~msg:"partial in 2")
    | _ ->
      ign_cs (Transport.write_payload ?pp ~p1 ~cmd:(wrap_ins ins) h
                ~msg:"complete in" (Cstruct.sub cs 0 cs'.off))
  end ;
  let cs' = Util.CompactSize.to_cstruct_int cs (List.length tx.outputs) in
  ign_cs (Transport.write_payload ?pp ~p1 ~cmd:(wrap_ins ins)
            h (Cstruct.sub cs 0 cs'.off) ~msg:"out len") ;
  ListLabels.iter tx.outputs ~f:begin fun txo ->
    let cs' = Protocol.TxOut.to_cstruct cs txo in
    ign_cs (Transport.write_payload ?pp ~p1 ~cmd:(wrap_ins ins)
              h (Cstruct.sub cs 0 cs'.off) ~msg:"out")
  end ;
  let cs' = Protocol.Transaction.LockTime.to_cstruct cs tx.lock_time in
  Transport.write_payload ?pp ~p1 ~cmd:(wrap_ins ins)
    h (Cstruct.sub cs 0 cs'.off) ~msg:"locktime"

type input_type =
  | Untrusted
  | Trusted of Cstruct.t list
  | Segwit of Int64.t list

let hash_tx_input_start
    ?pp ?buf ~new_transaction ~input_type h (tx : Bitcoin.Protocol.Transaction.t) index =
  let open Bitcoin in
  let open Bitcoin.Util in
  let open Bitcoin.Protocol in
  let cmd = wrap_ins Hash_input_start in
  let p2 = match new_transaction, input_type with
    | false, _ -> 0x80
    | true, Segwit _ -> 0x02
    | _ -> 0x00 in
  let cs = Cstruct.create 100000 in
  Cstruct.LE.set_uint32 cs 0 (Int32.of_int tx.version) ;
  let cs' =
    Bitcoin.Util.CompactSize.to_cstruct_int (Cstruct.shift cs 4) (List.length tx.inputs) in
  let lc = cs'.off in
  ign_cs (Transport.write_payload ?pp ?buf h ~cmd ~p2 (Cstruct.sub cs 0 lc)) ;
  match input_type with
  | Segwit amounts ->
    List.iter2 begin fun { TxIn.prev_out ; script ; seq } amount ->
      Cstruct.set_uint8 cs 0 0x02 ;
      let cs' = Outpoint.to_cstruct (Cstruct.shift cs 1) prev_out in
      Cstruct.LE.set_uint64 cs' 0 amount ;
      let cs' = Cstruct.shift cs' 8 in
      let cs' =
        if new_transaction then
          CompactSize.to_cstruct_int cs' 0
        else
          let cs' = CompactSize.to_cstruct_int cs' (Script.size script) in
          Script.to_cstruct cs' script
      in
      Cstruct.LE.set_uint32 cs' 0 seq ;
      let lc = cs'.off + 4 in
      ign_cs (Transport.write_payload ?pp ?buf h ~cmd ~p1:0x80 (Cstruct.sub cs 0 lc))
    end tx.inputs amounts
  | Trusted inputs ->
    let _ = List.fold_left2 begin fun i { TxIn.prev_out ; script ; seq } input ->
      let input_len = Cstruct.len input in
      Cstruct.set_uint8 cs 0 0x01 ;
      Cstruct.set_uint8 cs 1 input_len ;
      Cstruct.blit input 0 cs 2 input_len ;
      let cs' = Cstruct.shift cs (2+input_len) in
      let cs' =
        if i = index then
          let cs' =
            CompactSize.to_cstruct_int cs' (Script.size script) in
          Script.to_cstruct cs' script
        else
          CompactSize.to_cstruct_int cs' 0
      in
      Cstruct.LE.set_uint32 cs' 0 seq ;
      let lc = cs'.off + 4 in
      ign_cs (Transport.write_payload ?pp ?buf h ~cmd ~p1:0x80 (Cstruct.sub cs 0 lc)) ;
      succ i
      end 0 tx.inputs inputs in
    ()
  | _ -> invalid_arg "unsupported input type"

let hash_tx_finalize_full ?pp ?buf h (tx : Bitcoin.Protocol.Transaction.t) =
  let open Bitcoin in
  let cs = Cstruct.create 100000 in
  let cs' = Util.CompactSize.to_cstruct_int cs (List.length tx.outputs) in
  let cs' = List.fold_left Protocol.TxOut.to_cstruct cs' tx.outputs in
  Transport.write_payload ?pp ~msg:"hash_tx_finalize_full" ~mark_last:true
    ?buf h ~cmd:(wrap_ins Hash_input_finalize_full) (Cstruct.sub cs 0 cs'.off)

module HashType = struct
  type typ =
    | All
    | None
    | Single

  let int_of_typ = function
    | All -> 1
    | None -> 2
    | Single -> 3

  let typ_of_int = function
    | 1 -> All
    | 2 -> None
    | 3 -> Single
    | _ -> invalid_arg "HashType.typ_of_int"

  type flag =
    | ForkId
    | AnyoneCanPay

  let int_of_flag = function
    | ForkId -> 0x40
    | AnyoneCanPay -> 0x80

  let flags_of_int i =
    let forkid = i land 0x40 <> 0 in
    let anyonecanpay = i land 0x80 <> 0 in
    ListLabels.fold_left ~init:[] ~f:begin fun a (flag, is_present) ->
      if is_present then flag :: a else a
    end [ForkId, forkid ; AnyoneCanPay, anyonecanpay]

  type t = {
    typ: typ ;
    flags: flag list ;
  }

  let create ~typ ~flags = { typ ; flags }

  let to_int { typ ; flags } =
    List.fold_left begin fun a flag ->
      a lor (int_of_flag flag)
    end (int_of_typ typ) flags

  let of_int i =
    { typ = typ_of_int (i land 0x07) ; flags = flags_of_int i }
end

let hash_sign ?pp ?buf ~path ~hash_type ~hash_flags h (tx : Bitcoin.Protocol.Transaction.t) =
  let open Bitcoin in
  let nb_derivations = List.length path in
  if nb_derivations > 10 then invalid_arg "hash_sign: max 10 derivations" ;
  let lc = 1 + 4 * nb_derivations + 1 + 4 + 1 in
  let cs = Cstruct.create lc in
  Cstruct.set_uint8 cs 0 nb_derivations ;
  let cs' = Bitcoin.Wallet.KeyPath.write_be_cstruct (Cstruct.shift cs 1) path in
  Cstruct.set_uint8 cs' 0 0 ;
  Cstruct.BE.set_uint32 cs' 1 (Protocol.Transaction.LockTime.to_int32 tx.lock_time) ;
  Cstruct.set_uint8 cs' 5 HashType.(create hash_type hash_flags |> to_int) ;
  assert (cs'.off + 6 = lc) ;
  let signature =
    Transport.apdu ?pp ~msg:"hash_sign" ?buf h Apdu.(create ~lc ~data:cs (wrap_ins Hash_sign)) in
  Cstruct.set_uint8 signature 0 0x30 ;
  signature

let sign ?pp ?buf ~path ~prev_outputs h (tx : Bitcoin.Protocol.Transaction.t) =
  let trusted_inputs =
    ListLabels.map prev_outputs ~f:(fun (tx, i) -> get_trusted_input ?buf h tx i) in
  ListLabels.iter trusted_inputs ~f:(fun input -> assert (Cstruct.len input = 56)) ;
  let _, signatures =
    ListLabels.fold_left ~init:(0, []) tx.inputs ~f:begin fun (i, acc) _ ->
      hash_tx_input_start ?pp ?buf
        ~new_transaction:(i = 0)
        ~input_type:(Trusted trusted_inputs) h tx i ;
      let _ret = hash_tx_finalize_full ?pp ?buf h tx in
      let signature =
        hash_sign ?pp ?buf ~path ~hash_type:All ~hash_flags:[] h tx in
      succ i, signature :: acc
    end in
  signatures

let sign_segwit ?pp ?(bch=false) ?buf ~path ~prev_amounts h (tx : Bitcoin.Protocol.Transaction.t) =
  let nb_prev_amounts = List.length prev_amounts in
  let nb_inputs = List.length tx.inputs in
  if nb_prev_amounts <> nb_inputs then invalid_arg
      (Printf.sprintf "Bch.sign: prev_amounts do not match inputs (%d inputs vs %d amounts)"
         nb_inputs nb_prev_amounts) ;
  let open Bitcoin.Protocol in
  hash_tx_input_start
    ?pp ?buf ~new_transaction:true ~input_type:(Segwit prev_amounts) h tx 0 ;
  let _pin_required = hash_tx_finalize_full ?pp ?buf h tx in
  ListLabels.map2 tx.inputs prev_amounts ~f:begin fun txi prev_amount ->
    let virtual_tx = { tx with inputs = [txi] ; outputs = [] } in
    hash_tx_input_start ?pp ?buf
      ~new_transaction:false
      ~input_type:(Segwit [prev_amount]) h virtual_tx 0 ;
    let hash_flags = if bch then [HashType.ForkId] else [] in
    let signature =
      hash_sign ?pp ?buf ~path ~hash_type:All ~hash_flags h virtual_tx in
    signature
  end

(*---------------------------------------------------------------------------
   Copyright (c) 2017 Vincent Bernardoff

   Permission to use, copy, modify, and/or distribute this software for any
   purpose with or without fee is hereby granted, provided that the above
   copyright notice and this permission notice appear in all copies.

   THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
   WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
   MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
   ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
   WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
   ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
   OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
  ---------------------------------------------------------------------------*)
