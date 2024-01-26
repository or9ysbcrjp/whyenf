{
open Etc

type token = AT | LPA | RPA | LAN | RAN | COM | SEP | EOF | PLS | MNS | STR of string

}

let blank = [' ' '\t']+
let newline = ['\r' '\n' ] | "\r\n"

let lc = ['a'-'z']
let uc = ['A'-'Z']
let letter = uc | lc
let digit = ['0'-'9']

let digits = ['0'-'9']+
let string = (letter | digit | '_' | '[' | ']' | '/' | '-' | '.' | '!' | ':' | '"')+
let quoted_string = ([^ '"' '\\'] | '\\' _)*

rule token = parse
  | newline                        { Lexing.new_line lexbuf; token lexbuf }
  | blank                          { token lexbuf }
  | "@"                            { AT }
  | "("                            { LPA }
  | ")"                            { RPA }
  | ">"                            { LAN }
  | "<"                            { RAN }
  | ","                            { COM }
  | ";"                            { SEP }
  | "#"                            { skip_line lexbuf }
  | "+"                            { PLS }
  | "-"                            { MNS }
  | string as s                    { STR s }
  | '"' (quoted_string as s) '"'   { STR s }
  | eof                            { EOF }
  | _ as c                         { lexing_error lexbuf "unexpected character: `%c'" c }

and skip_line = parse
  | "\n" | "\r" | "\r\n"           { Lexing.new_line lexbuf; token lexbuf }
  | eof                            { EOF }
  | _                              { skip_line lexbuf }
