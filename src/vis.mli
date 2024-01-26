module E = Expl

module Dbs : sig

  val to_json: Etc.timepoint -> Db.t -> Formula.t -> string

end

module Expl : sig

  val to_json: Formula.t -> E.Proof.t E.Pdt.t -> string

end

module LightExpl : sig

  val to_json: Formula.t -> E.LightProof.t E.Pdt.t -> string

end
