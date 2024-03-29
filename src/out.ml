open Base
open Stdio
open Etc
open Checker_interface

type mode = UNVERIFIED | VERIFIED | LATEX | LIGHT | ENFORCE | DEBUG | DEBUGVIS

module Plain (CI: Checker_interfaceT) = struct

  open CI

  type t =
    | Explanation of (timestamp * timepoint) * Expl.t
    | ExplanationCheck of (timestamp * timepoint) * Expl.t * bool
    | ExplanationLatex of (timestamp * timepoint) * Expl.t * Formula.t
    | ExplanationLight of (timestamp * timepoint) * Expl.t
    | ExplanationEnforce of (timestamp * timepoint) * Expl.t
    | ExplanationCheckDebug of (timestamp * timepoint) * Expl.t * bool * Checker_pdt.t * Checker_trace.t
                               * (Dom.t, Dom.comparator_witness) Setc.t list list option
    | Info of string

  let expl = function
    | Explanation ((ts, tp), e) ->
       Stdio.printf "%d:%d\nExplanation: \n%s\n\n" ts tp (Expl.to_string e)
    | ExplanationCheck ((ts, tp), e, b) ->
       Stdio.printf "%d:%d\nExplanation: \n%s\n" ts tp (Expl.to_string e);
       Stdio.printf "\nChecker output: %B\n\n" b;
    | ExplanationLatex ((ts, tp), e, f) ->
       Stdio.printf "%d:%d\nExplanation: \n%s\n\n" ts tp (Expl.to_latex f e)
    | ExplanationLight ((ts, tp), e) ->
       Stdio.printf "%d:%d\nExplanation: \n%s\n\n" ts tp (Expl.to_light_string e)
    | ExplanationEnforce ((ts, tp), e) -> ()
    | ExplanationCheckDebug ((ts, tp), e, b, c_e, c_t, path_opt) ->
       Stdio.printf "%d:%d\nExplanation: \n%s\n" ts tp (Expl.to_string e);
       Stdio.printf "\nChecker output: %B\n\n" b;
       Stdio.printf "\n[debug] Checker explanation:\n%s\n\n" (Checker_interface.Checker_pdt.to_string "" c_e);
       Stdio.printf "\n[debug] Checker trace:\n%s" (Checker_trace.to_string c_t);
       (match path_opt with
        | None -> ()
        | Some(l1) -> Stdio.printf "\n[debug] Checker false path: %s\n"
                        (Etc.list_to_string "" (fun _ l2 -> Etc.list_to_string ""
                                                              (fun _ s -> Setc.to_string s) l2) l1)
        );
    | Info s -> Stdio.printf "\nInfo: %s\n\n" s

  let expls tstp_expls checker_es_opt paths_opt f_opt = function
    | UNVERIFIED
      | ENFORCE -> List.iter tstp_expls ~f:(fun ((ts, tp), e) -> expl (Explanation ((ts, tp), e)))
    | VERIFIED -> List.iter2_exn tstp_expls (Option.value_exn checker_es_opt)
                    ~f:(fun ((ts, tp), e) (b, _, _) -> expl (ExplanationCheck ((ts, tp), e, b)))
    | LATEX -> List.iter tstp_expls ~f:(fun ((ts, tp), e) ->
                   expl (ExplanationLatex ((ts, tp), e, Option.value_exn f_opt)))
    | LIGHT -> List.iter tstp_expls ~f:(fun ((ts, tp), e) -> if Expl.is_violated e then expl (ExplanationLight ((ts, tp), e)))
    | DEBUG -> List.iter2_exn (List.zip_exn tstp_expls (Option.value_exn checker_es_opt))
                 (Option.value_exn paths_opt)
                 ~f:(fun (((ts, tp), e), (b, checker_e, trace)) path_opt ->
                   expl (ExplanationCheckDebug ((ts, tp), e, b, checker_e, trace, path_opt)))
    | _ -> raise (Failure "this function is undefined for this mode")

  (*let enf_expls ts tp expls (cau, sup, coms) =
    Stdio.printf "%d:%d\n" ts tp;
    Stdio.printf "Cau: %s\n" (Etc.string_list_to_string (List.map cau ~f:Db.Event.to_string));
    Stdio.printf "Sup: %s\n" (Etc.string_list_to_string (List.map sup ~f:Db.Event.to_string));
    Stdio.printf "Future obligations:\n";
    List.iter coms ~f:(fun com -> Stdio.printf "%s\n" (Fobligation.to_string com));
    Stdio.printf "\n";
    List.iter expls ~f:(fun e -> Stdio.printf "Explanation: \n%s\n\n" (Expl.to_string e))*)

end

module Json (CI: Checker_interfaceT) = struct

  let error err =
    Printf.sprintf "ERROR: %s" (Error.to_string_hum err)

  let table_columns f =
    let sig_preds_columns = List.rev (Set.fold (Formula.pred_names f) ~init:[] ~f:(fun acc r ->
                                          let r_props = Hashtbl.find_exn Pred.Sig.table r in
                                          let var_names = fst (List.unzip r_props.ntconsts) in
                                          (Printf.sprintf "%s(%s)" r (Etc.string_list_to_string var_names)) :: acc)) in
    let subfs_columns = List.map (Formula.subfs_dfs f) ~f:Formula.op_to_string in
    let subfs_scope = List.map (Formula.subfs_scope f 0) ~f:(fun (i, (js, ks)) ->
                          Printf.sprintf "{\"col\": %d, \"leftCols\": %s, \"rightCols\": %s}" i (Etc.int_list_to_json js) (Etc.int_list_to_json ks)) in
    let subfs = List.map (Formula.subfs_dfs f) ~f:Formula.to_string in
    Printf.sprintf "{\n  \"predsColumns\": %s,\n
                    \"subfsColumns\": %s,\n
                    \"subfsScopes\": [%s],\n
                    \"subformulas\": %s }\n"
      (Etc.string_list_to_json sig_preds_columns) (Etc.string_list_to_json subfs_columns)
      (Etc.string_list_to_string subfs_scope) (Etc.string_list_to_json subfs)

  let db ts tp db f =
    Printf.sprintf "%s{\n" (String.make 4 ' ') ^
      Printf.sprintf "%s\"ts\": %d,\n" (String.make 8 ' ') ts ^
        Printf.sprintf "%s\"tp\": %d,\n" (String.make 8 ' ') tp ^
          Printf.sprintf "%s\n" (Vis.Dbs.to_json tp db f) ^
            Printf.sprintf "%s}" (String.make 4 ' ')

  let expls tpts f es =
    List.map es ~f:(fun e ->
        let tp = (CI.Expl.at e) in
        let ts = Hashtbl.find_exn tpts tp in
        Printf.sprintf "%s{\n" (String.make 4 ' ') ^
          Printf.sprintf "%s\"ts\": %d,\n" (String.make 8 ' ') ts ^
            Printf.sprintf "%s\"tp\": %d,\n" (String.make 8 ' ') tp ^
              Printf.sprintf "%s\"expl\": {\n" (String.make 8 ' ') ^
                Printf.sprintf "%s\n" (CI.Vis.to_json f e) ^
                  Printf.sprintf "}%s}" (String.make 4 ' '))

  let aggregate dbs es =
    Printf.sprintf "{\n" ^
      Printf.sprintf "%s\"dbs_objs\": [\n" (String.make 4 ' ') ^
        String.concat ~sep:",\n" dbs ^
          Printf.sprintf "],\n" ^
            Printf.sprintf "%s\"expls_objs\": [\n" (String.make 4 ' ') ^
              String.concat ~sep:",\n" es ^
                Printf.sprintf "]}"

end
