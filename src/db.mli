open Base
open Pred
open Etc

module Event : sig
  type t = string * Dom.t list [@@deriving compare, sexp_of]

  val equal: t -> t -> bool

  val to_string: t -> string

  include Comparable.S with type t := t

  val _tp: t
  val _tick: t
end

type t = (Event.t, Event.comparator_witness) Set.t

val create: Event.t list -> t

val mem: t -> Event.t -> bool
val is_empty: t -> bool
val remove: t -> Event.t -> t
val size: t -> int

val event: string -> string list -> Event.t

val add_event: t -> Event.t -> t
val is_tick: t -> bool

val to_string: t -> string

val to_json: t -> string
