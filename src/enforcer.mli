module type EnforcerT = sig

  val exec: Formula.t -> in_channel -> int -> unit

end

module Make (C: Checker_interface.Checker_interfaceT) : EnforcerT
