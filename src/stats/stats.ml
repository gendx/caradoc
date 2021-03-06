(*****************************************************************************)
(*  Caradoc: a PDF parser and validator                                      *)
(*  Copyright (C) 2015 ANSSI                                                 *)
(*  Copyright (C) 2015-2017 Guillaume Endignoux                              *)
(*                                                                           *)
(*  This program is free software; you can redistribute it and/or modify     *)
(*  it under the terms of the GNU General Public License version 2 as        *)
(*  published by the Free Software Foundation.                               *)
(*                                                                           *)
(*  This program is distributed in the hope that it will be useful,          *)
(*  but WITHOUT ANY WARRANTY; without even the implied warranty of           *)
(*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the            *)
(*  GNU General Public License for more details.                             *)
(*                                                                           *)
(*  You should have received a copy of the GNU General Public License along  *)
(*  with this program; if not, write to the Free Software Foundation, Inc.,  *)
(*  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.              *)
(*****************************************************************************)


open Directobject

module Stats = struct

  type version_t =
    | NotPDF
    | Unknown
    | Version of int

  type t = {
    mutable version : version_t;
    mutable encrypted : bool;
    mutable updatecount : int;
    mutable objstm : bool;
    mutable free : bool;
    mutable objcount : int;
    mutable filters : (string, int) Hashtbl.t;
    mutable knowntypes : int;
    mutable incompletetypes : bool;
    mutable nographerror : bool;
    mutable nocontentstreamerror : bool;
    (* /Info dictionary *)
    mutable producer : string option;
    mutable creator : string option;
    mutable creation_date : string option;
    mutable mod_date : string option;
    (* /Encrypt dictionary *)
    mutable encrypt_v : int option;
    mutable encrypt_r : int option;
    mutable encrypt_u : string option;
    mutable encrypt_o : string option;
    mutable encrypt_id : string option;
    mutable verify_user : bool;
    mutable verify_owner : bool;
  }


  let create () : t =
    {
      version = NotPDF;
      encrypted = false;
      updatecount = -1;
      objstm = false;
      free = false;
      objcount = -1;
      filters = Hashtbl.create 8;
      knowntypes = -1;
      incompletetypes = false;
      nographerror = false;
      nocontentstreamerror = false;
      producer = None;
      creator = None;
      creation_date = None;
      mod_date = None;
      encrypt_v = None;
      encrypt_r = None;
      encrypt_u = None;
      encrypt_o = None;
      encrypt_id = None;
      verify_user = false;
      verify_owner = false;
    }

  let print_version (x : t) : bool * string =
    match x.version with
    | NotPDF ->
      false, Printf.sprintf "Not a PDF file\n"
    | Unknown ->
      true,  Printf.sprintf "Version : unknown\n"
    | Version v ->
      true,  Printf.sprintf "Version : 1.%d\n" v

  let to_string (x : t) : string =
    let buf = Buffer.create 16 in
    let addbuf s =
      Buffer.add_string buf s
    in

    let ispdf, ver = print_version x in
    addbuf ver;

    if ispdf then (
      if x.updatecount >= 0 then (
        addbuf (Printf.sprintf "Incremental updates : %d\n" x.updatecount);

        if x.objstm then
          addbuf (Printf.sprintf "Contains object stream(s)\n");
        if x.free then
          addbuf (Printf.sprintf "Contains free object(s)\n");
        if (not x.objstm) && (not x.free) && x.updatecount = 0 && (not x.encrypted) then
          addbuf (Printf.sprintf "Neither updates nor object streams nor free objects nor encryption\n");

        if x.encrypted then (
          addbuf (Printf.sprintf "Encrypted\n");
          addbuf (Printf.sprintf "User password is %s\n" (if x.verify_user then "valid" else "invalid"));
          addbuf (Printf.sprintf "Owner password is %s\n" (if x.verify_owner then "valid" else "invalid"));
        ) else (
          if x.objcount >= 0 then (
            addbuf (Printf.sprintf "Object count : %d\n" x.objcount);
            Hashtbl.iter (fun filter count ->
                addbuf (Printf.sprintf "Filter : %s -> %d times\n" filter count)
              ) x.filters;
            if x.knowntypes >= 0 then (
              addbuf (Printf.sprintf "Objects of known type : %d\n" x.knowntypes);
              addbuf (Printf.sprintf "Known type rate : %f\n" ((float_of_int x.knowntypes) /. (float_of_int x.objcount)));
            );

            if x.incompletetypes then
              addbuf (Printf.sprintf "Some types were not fully checked\n")
            else if (x.knowntypes = x.objcount) then
              addbuf (Printf.sprintf "All types were fully checked\n");

            if x.nographerror then
              addbuf (Printf.sprintf "Graph has no known error\n");
            if x.nocontentstreamerror then
              addbuf (Printf.sprintf "Content streams have no known error\n");
          )
        )
      )
    );

    let print_some_string (x : string option) (title : string) : unit =
      match x with
      | Some s -> addbuf (Printf.sprintf "/%s : %s\n" title (DirectObject.to_string (DirectObject.String s)))
      | None -> ()
    in
    let print_some_int (x : int option) (title : string) : unit =
      match x with
      | Some i -> addbuf (Printf.sprintf "/%s : %d\n" title i)
      | None -> ()
    in
    print_some_string x.producer "Producer";
    print_some_string x.creator "Creator";
    print_some_string x.creation_date "CreationDate";
    print_some_string x.mod_date "ModDate";
    print_some_int x.encrypt_v "Encrypt/V";
    print_some_int x.encrypt_r "Encrypt/R";
    print_some_string x.encrypt_u "Encrypt/U";
    print_some_string x.encrypt_o "Encrypt/O";
    print_some_string x.encrypt_id ((if x.encrypted then "Encrypt/" else "") ^ "ID");

    if x.nographerror && x.nocontentstreamerror && (not x.incompletetypes) && (x.knowntypes = x.objcount) then
      addbuf (Printf.sprintf "No error found\n");

    Buffer.contents buf

  let print (x : t) : unit =
    print_string (to_string x)

end

