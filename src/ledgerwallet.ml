open Sexplib.Std

module Status = struct
  type t =
    | Invalid_pin of int
    | Incorrect_length
    | Security_status_unsatisfied
    | Invalid_data
    | File_not_found
    | Incorrect_params
    | Technical_problem of int
    | Ok [@@deriving sexp]

  let of_int = function
    | 0x6700 -> Incorrect_length
    | 0x6982 -> Security_status_unsatisfied
    | 0x6a80 -> Invalid_data
    | 0x6a82 -> File_not_found
    | 0x6b00 -> Incorrect_params
    | 0x9000 -> Ok
    | v when v >= 0x63c0 && v <= 0x63cf -> Invalid_pin (v land 0x0f)
    | v when v >= 0x6f00 && v <= 0x6fff -> Technical_problem (v land 0xff)
    | v -> invalid_arg (Printf.sprintf "Status.of_int: got 0x%x" v)

  let to_string t =
    Sexplib.Sexp.to_string_hum (sexp_of_t t)
end

module Apdu = struct
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

  let adm_cla = 0xd0
  let cla = 0xe0

  type cmd =
    | Adm_cla of adm_ins
    | Cla of ins

  type t = {
    cmd : cmd ;
    p1 : int ;
    p2 : int ;
    lc : int ;
    le : int ;
    data : Cstruct.t ;
  }

  let max_data_length = 230

  let create ?(p1=0) ?(p2=0) ?(lc=0) ?(le=0) ?(data=Cstruct.create 0) cmd =
    { cmd ; p1 ; p2 ; lc ; le ; data }

  let create_string ?(p1=0) ?(p2=0) ?(lc=0) ?(le=0) ?(data="") cmd =
    let data = Cstruct.of_string data in
    { cmd ; p1 ; p2 ; lc ; le ; data }

  let length { data } = 5 + Cstruct.len data

  let write cs { cmd ; p1 ; p2 ; lc ; le ; data } =
    let len = match lc, le with | 0, _ -> le | _ -> lc in
    let datalen = Cstruct.len data in
    begin match cmd with
      | Adm_cla i ->
        Cstruct.set_uint8 cs 0 adm_cla ;
        Cstruct.set_uint8 cs 1 (int_of_adm_ins i)
      | Cla i ->
        Cstruct.set_uint8 cs 0 cla ;
        Cstruct.set_uint8 cs 1 (int_of_ins i)
    end ;
    Cstruct.set_uint8 cs 2 p1 ;
    Cstruct.set_uint8 cs 3 p2 ;
    Cstruct.set_uint8 cs 4 len ;
    Cstruct.blit data 0 cs 5 datalen ;
    Cstruct.shift cs (5 + datalen)
end

module Transport = struct
  let packet_length = 64
  let channel = 0x0101
  let apdu = 0x05
  let ping = 0x02

  module Header = struct
    type t = {
      cmd : [`Ping | `Apdu] ;
      seq : int ;
    }

    let read cs =
      let open Cstruct in
      if BE.get_uint16 cs 0 <> channel then
        invalid_arg "Transport.read_header: invalid channel id" ;
      let cmd = match get_uint8 cs 2 with
        | 0x05 -> `Apdu
        | 0x02 -> `Ping
        | _ -> invalid_arg "Transport.read_header: invalid command tag"
      in
      let seq = BE.get_uint16 cs 3 in
      { cmd ; seq }, Cstruct.shift cs 5

    let check_exn ?cmd ?seq t =
      begin match cmd with
      | None -> ()
      | Some expected ->
        if expected <> t.cmd then failwith "Header.check: unexpected command"
      end ;
      begin match seq with
        | None -> ()
        | Some expected ->
          if expected <> t.seq then failwith "Header.check: unexpected seq num"
      end

    let check ?cmd ?seq t =
      try Result.Ok (check_exn ?cmd ?seq t)
      with Failure msg -> Result.Error msg

    let length = 5
  end

  let write_ping ?(buf=Cstruct.create packet_length) h =
    let open Cstruct in
    BE.set_uint16 buf 0 channel ;
    set_uint8 buf 2 ping ;
    BE.set_uint16 buf 3 0 ;
    memset (sub buf 5 59) 0 ;
    let nb_written =
      Hidapi.hid_write h (sub buf 0 packet_length) in
    if nb_written <> packet_length then failwith "Transport.write_ping"

  let write_apdu
      ?(buf=Cstruct.create packet_length)
      h ({ Apdu.cmd ; p1 ; p2 ; lc ; le ; data } as p) =
    let apdu_len = Apdu.length p in
    let apdu_buf = Cstruct.create apdu_len in
    let _nb_written = Apdu.write apdu_buf p in
    let apdu_p = ref 0 in (* pos in the apdu buf *)
    let i = ref 0 in (* packet id *)
    let open Cstruct in

    (* write first packet *)
    BE.set_uint16 buf 0 channel ;
    set_uint8 buf 2 apdu ;
    BE.set_uint16 buf 3 !i ;
    BE.set_uint16 buf 5 apdu_len ;
    let nb_to_write = (min apdu_len (packet_length - 7)) in
    blit apdu_buf 0 buf 7 nb_to_write ;
    let nb_written = Hidapi.hid_write h (sub buf 0 packet_length) in
    if nb_written <> packet_length then failwith "Transport.write_apdu" ;
    apdu_p := !apdu_p + nb_to_write ;
    incr i ;

    (* write following packets *)
    while !apdu_p < apdu_len do
      memset buf 0 ;
      BE.set_uint16 buf 0 channel ;
      set_uint8 buf 2 apdu ;
      BE.set_uint16 buf 3 !i ;
      let nb_to_write = (min (apdu_len - !apdu_p) (packet_length - 5)) in
      blit apdu_buf !apdu_p buf 5 nb_to_write ;
      let nb_written = Hidapi.hid_write h (sub buf 0 packet_length) in
      if nb_written <> packet_length then failwith "Transport.write_apdu" ;
      apdu_p := !apdu_p + nb_to_write ;
      incr i
    done

  let read ?(buf=Cstruct.create packet_length) h =
    let expected_seq = ref 0 in
    let full_payload = ref (Cstruct.create 0) in
    let payload = ref (Cstruct.create 0) in
    (* let pos = ref 0 in *)
    let rec inner () =
      let nb_read = Hidapi.hid_read ~timeout:600000 h buf packet_length in
      if nb_read <> packet_length then
        failwith (Printf.sprintf "Transport.read: read %d bytes" nb_read) ;
      let hdr, buf = Header.read buf in
      Header.check_exn ~seq:!expected_seq hdr ;
      if hdr.seq = 0 then begin (* first frame *)
        let len = Cstruct.BE.get_uint16 buf 0 in
        let cs = Cstruct.shift buf 2 in
        payload := Cstruct.create len ;
        full_payload := !payload ;
        let nb_to_read = min len (packet_length - 7) in
        Cstruct.blit cs 0 !payload 0 nb_to_read ;
        payload := Cstruct.shift !payload nb_to_read ;
        (* pos := !pos + nb_to_read ; *)
        expected_seq := !expected_seq + 1 ;
      end else begin (* next frames *)
        (* let rem = Bytes.length !payload - !pos in *)
        let nb_to_read = min (Cstruct.len !payload) (packet_length - 5) in
        Cstruct.blit buf 0 !payload 0 nb_to_read ;
        payload := Cstruct.shift !payload nb_to_read ;
        (* pos := !pos + nb_to_read ; *)
        expected_seq := !expected_seq + 1
      end ;
      if Cstruct.len !payload = 0 then
        if hdr.cmd = `Ping then Status.Ok, Cstruct.create 0
        else
          (* let sw_pos = Bytes.length !payload - 2 in *)
          let payload_len = Cstruct.len !full_payload in
          Status.of_int Cstruct.(BE.get_uint16 !full_payload (payload_len -2)),
          Cstruct.sub !full_payload 0 (payload_len - 2)
      else inner ()
    in
    inner ()

  let ping ?(msg="") ?buf h =
    write_ping ?buf h ;
    match read ?buf h with
    | Status.Ok, _ -> ()
    | s, _ -> failwith ((Status.to_string s) ^ " " ^ msg)

  let apdu ?(msg="") ?buf h apdu =
    write_apdu ?buf h apdu ;
    match read ?buf h with
    | Status.Ok, payload -> payload
    | s, _ -> failwith ((Status.to_string s) ^ " " ^ msg)
end

let ping ?buf h = Transport.ping ?buf h

let get_random ?buf h len =
  let random_str =
    Transport.apdu ?buf h Apdu.(create ~le:len (Cla Get_random)) in
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
  let b = Transport.apdu ?buf h Apdu.(create ~le:1 (Cla Get_operation_mode)) in
  Operation_mode.of_int (Cstruct.get_uint8 b 0)

let get_second_factor ?buf h =
  let b = Transport.apdu ?buf h Apdu.(create ~p1:1 ~le:1 (Cla Get_operation_mode)) in
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
  } [@@deriving sexp]

  let create ~flags ~arch ~major ~minor ~patch ~loader_major ~loader_minor =
    let flags = flags_of_int flags in
    { flags ; arch ; major ; minor ; patch ; loader_major ; loader_minor }
end

let get_firmware_version ?buf h =
  let open EndianString.BigEndian in
  let b = Transport.apdu ?buf h Apdu.(create ~le:7 (Cla Get_firmware_version)) in
  let open Cstruct in
  let flags = get_uint8 b 0 in
  let arch = get_uint8 b 1 in
  let major = get_uint8 b 2 in
  let minor = get_uint8 b 3 in
  let patch = get_uint8 b 4 in
  let loader_major = get_uint8 b 5 in
  let loader_minor = get_uint8 b 6 in
  Firmware_version.create flags arch major minor patch loader_major loader_minor

let verify_pin ?buf h pin =
  let lc = String.length pin in
  let b = Transport.apdu ?buf h Apdu.(create_string ~lc ~data:pin (Cla Verify_pin)) in
  match Cstruct.get_uint8 b 0 with
  | 0x01 -> `Need_power_cycle
  | _ -> `Ok

let get_remaining_pin_attempts ?buf h =
  Transport.write_apdu ?buf h Apdu.(create_string ~p1:0x80 ~lc:1 ~data:"\x00" (Cla Verify_pin)) ;
  match Transport.read ?buf h with
  | Status.Invalid_pin n, _ -> n
  | Status.Ok, _ -> failwith "get_remaining_pin_attempts got OK"
  | s, _ -> failwith (Status.to_string s)

module Public_key = struct
  type t = {
    uncompressed : string ;
    b58addr : string ;
    bip32_chaincode : string ;
  } [@@deriving sexp]

  let create ~uncompressed ~b58addr ~bip32_chaincode = {
    uncompressed ; b58addr ; bip32_chaincode
  }

  let of_cstruct cs =
    let keylen = Cstruct.get_uint8 cs 0 in
    let uncompressed = Bytes.create keylen in
    Cstruct.blit_to_bytes cs 1 uncompressed 0 keylen ;
    let addrlen = Cstruct.get_uint8 cs (1+keylen) in
    let b58addr = Bytes.create addrlen in
    Cstruct.blit_to_bytes cs (1+keylen+1) b58addr 0 addrlen ;
    let bip32_chaincode = Bytes.create 32 in
    Cstruct.blit_to_bytes cs (1+keylen+1+addrlen) bip32_chaincode 0 32 ;
    create ~uncompressed ~b58addr ~bip32_chaincode,
    Cstruct.shift cs (1+keylen+1+addrlen+32)
end

let get_wallet_pubkeys ?buf h keyPath =
  let nb_derivations = List.length keyPath in
  if nb_derivations > 10 then invalid_arg "get_wallet_pubkeys: max 10 derivations" ;
  let lc = 1 + 4 * nb_derivations in
  let data_init = Cstruct.create lc in
  Cstruct.memset data_init 0 ;
  Cstruct.set_uint8 data_init 0 nb_derivations ;
  let data = Cstruct.shift data_init 1 in
  let _data = Bitcoin.Util.KeyPath.write_be_cstruct data keyPath in
  let b = Transport.apdu ?buf h Apdu.(create ~lc ~data:data_init (Cla Get_wallet_public_key)) in
  fst (Public_key.of_cstruct b)

let rec write_payload ?(finalize_full=false) ?buf ?(msg="write_payload") ~ins ?p1 ?p2 h cs =
  let rec inner acc cs =
    let cs_len = Cstruct.len cs in
    let lc = min Apdu.max_data_length cs_len in
    let last = lc = cs_len in
    let p1 = if finalize_full && last then Some 0x80 else p1 in
    let acc = Transport.apdu ~msg ?buf h
        Apdu.(create ?p1 ?p2 ~lc ~data:(Cstruct.sub cs 0 lc) (Cla ins)) in
    if last then acc
    else inner acc (Cstruct.shift cs lc) in
  if Cstruct.len cs = 0 then cs else inner (Cstruct.create 0) cs

let ign_cs cs = ignore (cs : Cstruct.t)

let get_trusted_input ?buf h (tx : Bitcoin.Protocol.Transaction.t) index =
  let open Bitcoin in
  let ins = Apdu.Get_trusted_input in
  let cs = Cstruct.create 100000 in
  Cstruct.BE.set_uint32 cs 0 (Int32.of_int index) ;
  Cstruct.LE.set_uint32 cs 4 (Int32.of_int tx.version) ;
  let cs' =
    Util.CompactSize.to_cstruct_int (Cstruct.shift cs 8) (List.length tx.inputs) in
  ign_cs (write_payload ~ins ?buf ~msg:"init" h (Cstruct.sub cs 0 cs'.off)) ;
  let p1 = 0x80 in
  ListLabels.iter tx.inputs ~f:begin fun txi ->
    let cs' = Protocol.TxIn.to_cstruct cs txi in
    match cs'.off mod Apdu.max_data_length with
    | len when len > 0 && len < 4 ->
      let cs1 = Cstruct.sub cs 0 (cs'.off - 4) in
      let cs2 = Cstruct.sub cs (cs'.off - 4) 4 in
      ign_cs (write_payload ~p1 ~ins h cs1 ~msg:"partial in 1") ;
      ign_cs (write_payload ~p1 ~ins h cs2 ~msg:"partial in 2")
    | _ ->
      let _ = write_payload ~p1 ~ins h ~msg:"complete in" (Cstruct.sub cs 0 cs'.off) in
      ()
  end ;
  let cs' = Util.CompactSize.to_cstruct_int cs (List.length tx.outputs) in
  ign_cs (write_payload ~p1 ~ins h (Cstruct.sub cs 0 cs'.off) ~msg:"out len") ;
  ListLabels.iter tx.outputs ~f:begin fun txo ->
    let cs' = Protocol.TxOut.to_cstruct cs txo in
    ign_cs (write_payload ~p1 ~ins h (Cstruct.sub cs 0 cs'.off) ~msg:"out")
  end ;
  let cs' = Protocol.Transaction.LockTime.to_cstruct cs tx.lock_time in
  write_payload ~p1 ~ins h (Cstruct.sub cs 0 cs'.off) ~msg:"locktime"

type input_type =
  | Untrusted
  | Trusted of Cstruct.t list
  | Segwit of Int64.t list

let hash_tx_input_start ?buf ~new_transaction ~input_type h (tx : Bitcoin.Protocol.Transaction.t) =
  let open Bitcoin in
  let open Bitcoin.Util in
  let open Bitcoin.Protocol in
  let p2 = match new_transaction, input_type with
    | false, _ -> 0x80
    | true, Segwit _ -> 0x02
    | _ -> 0x00 in
  let cs = Cstruct.create 100000 in
  Cstruct.LE.set_uint32 cs 0 (Int32.of_int tx.version) ;
  let cs' = Cstruct.shift cs 4 in
  let cs' = Bitcoin.Util.CompactSize.to_cstruct_int cs' (List.length tx.inputs) in
  let lc = cs'.off in
  ign_cs (write_payload ?buf h ~ins:Hash_input_start ~p2 (Cstruct.sub cs 0 lc)) ;
  match input_type with
  | Segwit amounts ->
    List.iter2 begin fun { TxIn.prev_out ; script ; seq } amount ->
      Cstruct.set_uint8 cs 0 0x02 ;
      let cs' = Cstruct.shift cs 1 in
      let cs' = Outpoint.to_cstruct cs' prev_out in
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
      ign_cs (write_payload ?buf h ~ins:Hash_input_start ~p1:0x80 (Cstruct.sub cs 0 lc))
    end tx.inputs amounts
  | _ -> invalid_arg "unsupported input type"

let hash_tx_finalize_full ?buf h (tx : Bitcoin.Protocol.Transaction.t) =
  let open Bitcoin in
  let cs = Cstruct.create 100000 in
  let cs' = Util.CompactSize.to_cstruct_int cs (List.length tx.outputs) in
  let cs' = List.fold_left Protocol.TxOut.to_cstruct cs' tx.outputs in
  let res =
    write_payload ~msg:"hash_tx_finalize_full" ~finalize_full:true
      ?buf h ~ins:Hash_input_finalize_full (Cstruct.sub cs 0 cs'.off) in
  match Cstruct.get_uint8 res 0 with
  | 0x00 -> false
  | _ -> true

module HashType = struct
  type typ =
    | All
    | None
    | Single

  let int_of_typ = function
    | All -> 1
    | None -> 2
    | Single -> 3

  type flag =
    | ForkId
    | AnyoneCanPay

  let int_of_flag = function
    | ForkId -> 0x40
    | AnyoneCanPay -> 0x80

  type t = {
    typ: typ ;
    flags: flag list ;
  }

  let create ~typ ~flags = { typ ; flags }

  let to_int { typ ; flags } =
    List.fold_left begin fun a flag ->
      a lor (int_of_flag flag)
    end (int_of_typ typ) flags
end

let hash_sign ?buf ~path ~hash_type ~hash_flags h (tx : Bitcoin.Protocol.Transaction.t) =
  let open Bitcoin in
  let nb_derivations = List.length path in
  if nb_derivations > 10 then invalid_arg "hash_sign: max 10 derivations" ;
  let lc = 1 + 4 * nb_derivations + 1 + 4 + 1 in
  let cs = Cstruct.create lc in
  Cstruct.memset cs 0 ;
  Cstruct.set_uint8 cs 0 nb_derivations ;
  let cs' = Bitcoin.Util.KeyPath.write_be_cstruct (Cstruct.shift cs 1) path in
  Cstruct.set_uint8 cs' 0 0 ;
  Cstruct.BE.set_uint32 cs' 1 (Protocol.Transaction.LockTime.to_int32 tx.lock_time) ;
  Cstruct.set_uint8 cs' 5 HashType.(create hash_type hash_flags |> to_int) ;
  Transport.apdu ~msg:"hash_sign" ?buf h Apdu.(create ~lc ~data:cs (Cla Hash_sign))

module Bch = struct
  let sign ?buf ~path h (tx : Bitcoin.Protocol.Transaction.t) prev_amounts =
    let nb_prev_amounts = List.length prev_amounts in
    let nb_inputs = List.length tx.inputs in
    if nb_prev_amounts <> nb_inputs then invalid_arg
        (Printf.sprintf "Bch.sign: prev_amounts do not match inputs (%d inputs vs %d amounts)"
           nb_inputs nb_prev_amounts) ;
    let open Bitcoin.Protocol in
    hash_tx_input_start
      ?buf ~new_transaction:true ~input_type:(Segwit prev_amounts) h tx ;
    let _pin_required = hash_tx_finalize_full ?buf h tx in
    ListLabels.map2 tx.inputs prev_amounts ~f:begin fun txi prev_amount ->
      let virtual_tx = { tx with inputs = [txi] } in
      hash_tx_input_start ?buf h virtual_tx
        ~new_transaction:false
        ~input_type:(Segwit [prev_amount]) ;
      let signature =
        hash_sign ?buf ~path ~hash_type:All ~hash_flags:[ForkId] h virtual_tx in
      Cstruct.set_uint8 signature 0 0x30 ;
      signature
    end
end
