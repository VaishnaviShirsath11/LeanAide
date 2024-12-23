import Lean
import Batteries
open Batteries Lean

inductive IndentedList where
  | nil
  | cons (head : String) (offsetList : IndentedList) (tail : IndentedList)
  | kv_cons (head body : String) (optional: Bool)
      (offsetList : IndentedList) (tail : IndentedList)
deriving Inhabited, Repr, ToJson, FromJson

def IndentedList.append : IndentedList → IndentedList → IndentedList
  | IndentedList.nil, l => l
  | l, IndentedList.nil => l
  | IndentedList.cons h1 o1 t1, l2 => IndentedList.cons h1 o1 (t1.append l2)
  | IndentedList.kv_cons h1 b1 optional o1 t1, l2 => IndentedList.kv_cons h1 b1 optional o1 (t1.append l2)

instance : Append IndentedList := ⟨IndentedList.append⟩

def IndentedList.kvLine (head body : String) (optional: Bool) : IndentedList :=
  IndentedList.kv_cons head body optional IndentedList.nil IndentedList.nil

def IndentedList.renderAux : IndentedList → String → String
  | IndentedList.nil, _ => ""
  | IndentedList.cons h o t, indent =>
      let subList := o.renderAux (indent ++ "  ")
      "\n" ++ indent ++ "* " ++ h  ++ subList ++ t.renderAux indent
  | IndentedList.kv_cons h b optional o t, indent =>
      let subList := o.renderAux (indent ++ "  ")
      let body := if optional then s!"(OPTIONAL) {b}" else b
      "\n" ++ indent ++ s!"* **{h}**: {body}" ++
          subList ++ t.renderAux indent

def IndentedList.render (l : IndentedList) : String :=
  l.renderAux ""

/--
Building blocks for structured math documents. Additional data is given as a Std.HashMap from `Name` to `MathPara` for elements in a group.
-/
inductive MathParaStructure where
  | text (name: Name) (description : String)
  | bool (name: Name) (description : String)
  | enum (name: Name) (choices: List String)
      (description : String)
  | list (name: Name) (fieldType: Name) (describeOptions: Bool) (description : String)
  | one_of (name: Name) (choices: List MathParaStructure) (description : String)
  | list_of (name: Name) (type : MathParaStructure)
  | obj (name: Name) (fields: List MathParaStructure) (optFields : List MathParaStructure)
      (description : String)
deriving Inhabited, Repr, FromJson, ToJson, BEq
namespace MathParaStructure

def name : MathParaStructure → Name
  | text n _ => n
  | bool n _ => n
  | enum n _ _ => n
  | list n _ _ _ => n
  | one_of n _ _ => n
  | list_of n _ => n
  | obj n _ _ _ => n

def mathDoc : MathParaStructure :=
  .list `math_document (fieldType := `math_object) (describeOptions := true) "A structured math document in a custom JSON format."

namespace let_statement

def var : MathParaStructure := .text `variable ("The variable being defined (use `<anonymous>` if there is no name such as in `We have a group structure on S`)")

def value : MathParaStructure := .text `value ("The value of the variable being defined")

def kind : MathParaStructure := .text `kind ("The type of the variable, such as `real number`, `function from S to T`, `element of G` etc.")

def properties : MathParaStructure := .text `properties "Specific properties of the variable beyond the type."

end let_statement

open let_statement in
def let_statement : MathParaStructure :=
  .obj `let (fields := [var])
    (optFields := [value, kind, properties])
    (description := "A statement introducing a new variable with given value, type and/or property. For saying that **some** value of the variable is as needed, use a 'some' statement.")

def assume : MathParaStructure :=
  .text `assume "A mathematical assumption being made. In case this is a variable or structure being introduced, use a 'let' statement."

open let_statement in
def exists_statement : MathParaStructure :=
  .obj `some (fields := [var])
    (optFields := [kind, properties])
    (description := "A statement introducing a new variable and saying that **some** value of this variable is as required (i.e., an existence statement). This is possibly with given type and/or property. This corresponds to statements like 'for some integer `n` ...' or 'There exists an integer `n` ....'.")

namespace define

def statement : MathParaStructure :=
  .text `statement "The mathematical definition."

def term : MathParaStructure :=
  .text `term "The term being defined."

end define


def name_field : MathParaStructure :=
  .text `name "The name of the theorem, lemma or claim."

def define : MathParaStructure :=
  .obj `def (fields := [define.statement, define.term]) (optFields := [name_field])
    (description := "A mathematical term being defined. In case a definition is being used, use 'assert' or 'theorem' instead.")

namespace deduced_using

def result_used : MathParaStructure := .text `result_used "An assumption or previously known results from which the deduction is made. If more than one result is used, list them in the 'deductions' field as separate `deduction` objects. If the result used needs justification, have a separate `assert` object earlier."

def in_context : MathParaStructure := .bool `proved_earlier "Whether the statement from which deduction has been proved earlier IN THIS DOCUMENT. Answer `true` or `false` (answer `false` if a result from the mathematical literature is being invoked)."


def instantiation : MathParaStructure :=  .text `instantiation "Specific numbers, functions etc to which a known result is applied. For example, if we apply uniqueness of prime factorisation to `42` write `{'result_used' : 'uniqueness of prime factorization', 'instantiation': '42'}`."

def instantiations : MathParaStructure :=
  .list_of `instantiations instantiation

end deduced_using

namespace calculate

def inline : MathParaStructure := .text `inline_calculation "A simple calculation or computation written as a single line."

def step : MathParaStructure := .text `calculation_step "A step, typically an equality or inequality, in a calculation or computation."

def sequence : MathParaStructure := .list_of `calculation_sequence step
end calculate

def calculation_step.justification : MathParaStructure :=
  .text `justification "The justification for the step in a calculation or computation."

open calculate in
def calculate : MathParaStructure :=
  .one_of `calculate [inline, sequence]  "An equation, inequality, short calculation etc."

namespace assert
open deduced_using in
def deduction : MathParaStructure :=
  .obj `deduced_from (fields := [result_used, in_context])
    (optFields := []) -- removed instantiations as it was not understood.
    (description := "A deduction of a mathematical result from assumptions or previously known results.")

def deductions : MathParaStructure :=
  .list_of `deduced_from_results deduction

def claim : MathParaStructure :=
  .text `claim "The mathematical claim being asserted, NOT INCLUDING proofs, justifications or results used. The claim should be purely a logical statement which is the *consequence* obtained."

def proof_method : MathParaStructure :=
  .text `proof_method "The method used to prove the claim. This could be a direct proof, proof by contradiction, proof by induction, etc. this should be a single phrase or a fairly simple sentence; if a longer justification is needed break the step into smaller steps. If the method is deduction from a result, use the 'deduced_using' field"

def calculations : MathParaStructure :=
  .list_of `calculate (type := calculate)
end assert

def missing_proofs : MathParaStructure :=
  .text `missing "A  problem that need to be solved or results that need to be proved to complete the proof. Standard results/criteria may be omitted from the proof: include them in the 'deduced_from' field."

def missing : MathParaStructure :=
  .list_of `missing_proofs missing_proofs

def error : MathParaStructure :=
  .text `error "An error in a proof or calculation. Report only actual errors, with missing steps reported in the 'missing' field."

def errors : MathParaStructure :=
  .list_of `errors error

open assert in
def assert : MathParaStructure :=
  .obj `assert (fields := [claim])
    (optFields := [proof_method, deductions, calculate, missing, errors])
    (description := "A mathematical statement whose proof is a straightforward consequence of given and known results following some method.")

namespace thm

def hypothesis (describeOptions := false) : MathParaStructure :=
  .list `hypothesis (fieldType := `contextBlock) (describeOptions := describeOptions)  "a JSON list of data and assumptions, i.e., **let** and **assume** statements"

def conclusion : MathParaStructure :=
  .text `conclusion "The conclusion of the theorem."

def proved : MathParaStructure :=
  .bool `proved "Whether the theorem has been proved, either here or earlier or by citing the literature."


def ref : MathParaStructure :=
  .text `ref "A reference where the result has been previously proved."

def cite : MathParaStructure :=
  .text `cite "A citation of a result from the mathematical literature which gives the proof."

end thm

def proof (describeOptions := false) : MathParaStructure :=
  .list `proof (fieldType := `math_object) (describeOptions := describeOptions) "A proof of a lemma, theorem or claim, having the same structure as (the value for) a `math_document`."

open thm in
def thm (describeOptions := false) : MathParaStructure :=
  .obj `theorem (fields := [hypothesis describeOptions, conclusion, proved])
    (optFields := [name_field, proof, ref, cite, missing, errors])
    (description := "A mathematical theorem, with a list of hypotheses and a conclusion.")

namespace problem

def statement : MathParaStructure :=
  .text `statement "The statement of the problem."

def solved : MathParaStructure :=
  .bool `solved "Whether the problem has been solved."

def answer : MathParaStructure :=
  .text `answer "The answer to the problem."

end problem

open problem in
def problem : MathParaStructure :=
  .obj `problem (fields := [statement, solved])
    (optFields := [answer, proof, missing, errors])
    (description := "A mathematical problem, with a statement and an answer.")

namespace case

def condition : MathParaStructure :=
  .text `condition "The case condition or pattern; for induction one of 'base' or 'induction-step'; for a side of an 'iff' statement write the claim being proved (i.e., the statement `P => Q` or `Q => P`)."

end case

open case in
def case (describeOptions := false) : MathParaStructure :=
  .obj `case (fields := [condition, proof describeOptions])
    (optFields := [missing, errors])
    (description := "A case in a proof by cases or proof by induction.")

namespace cases

def on : MathParaStructure :=
  .text `on "The variable or expression on which the cases are being done. Write 'implication direction' for an 'iff' statement."

def split_kind : MathParaStructure :=
  .enum `split_kind ["implication_direction", "match", "condition", "groups"] "one of 'implication_direction' (for two sides of an 'iff' implication), 'match' (for pattern matching), 'condition' (if based on a condition being true or false) and 'groups' (for more complex cases)."

def exhaustiveness (describeOptions := false) : MathParaStructure :=
  .list `exhaustiveness (fieldType := `math_object) (describeOptions := describeOptions) "Proof that the cases are exhaustive, similar to (the value for) 'math_document'."

end cases

def proof_cases (describeOptions := false) : MathParaStructure :=
  .list_of `proof_cases <| case describeOptions

open cases in
def cases (describeOptions := false) : MathParaStructure :=
  .obj `cases (fields := [split_kind, on, proof_cases describeOptions])
    (optFields := [exhaustiveness, missing, errors])
    (description := "A proof by cases or proof by induction, with a list of cases.")

namespace induction

def on : MathParaStructure :=
  .text `on "The variable or expression on which induction is being done."

end induction

open induction in
def induction (describeOptions := false) : MathParaStructure :=
  .obj `induction (fields := [on, proof_cases describeOptions])
    (optFields := [])
    (description := "A proof by induction, with a base case and an induction step.")

namespace contradiction
def assumption : MathParaStructure :=
  .text `assumption "The assumption being made to be contradicted."

def proof (describeOptions := false) : MathParaStructure :=
  .list `proof (fieldType := `math_object) (describeOptions := describeOptions) "The proof of the contradiction given the assumption."

end contradiction

open contradiction in
def contradiction (describeOptions := false) : MathParaStructure :=
  .obj `contradiction (fields := [assumption, contradiction.proof describeOptions])
    (optFields := [missing, errors])
    (description := "A proof by contradiction, with an assumption and a proof of the contradiction.")

namespace conclude

def claim : MathParaStructure :=
  .text `claim "The conclusion of the proof."

end conclude

open conclude in
def conclude : MathParaStructure :=
  .obj `conclude (fields := [claim])
    (optFields := [missing, errors])
    (description := "Conclude a claim obtained from the steps so far. This is typically the final statement of a proof giving the conclusion of the theorem.")

def end_of_source : MathParaStructure :=
  .text `eos_error "For the source ending when proofs are not complete, state what proofs were left incomplete."

def remark : MathParaStructure :=
  .text `remark "A remark or comment that is NOT MATHEMATICAL, instead being for motivation, attention, sectioning etc."

def math_objectElems := [let_statement, exists_statement, assume, define, assert, thm, problem, cases, induction, contradiction, calculate, conclude, remark]

def contextBlockElems := [let_statement, exists_statement, assume]

def elemMap : Std.HashMap Name <| List MathParaStructure :=
  Std.HashMap.ofList [(`math_object, math_objectElems), (`contextBlock, contextBlockElems)]

def suppress (s: String) := s!"{s} Give the corresponding source text as a JSON string (this will be processed subsequently)."

open IndentedList in
def toIndendentList (p: MathParaStructure) (optional : Bool := false)
  (elemMap : Std.HashMap Name <| List MathParaStructure := elemMap) (maxDepth: Nat := 5): IndentedList :=
  match p with
  | .text name description =>
    kvLine name.toString (description ++ " Give a JSON string.") optional
  | .bool name description =>
    kvLine name.toString (description ++ " Give a JSON boolean.") optional
  | .enum name _ description =>
      kvLine name.toString description optional
  | .list name fieldType describeOptions description =>
    match maxDepth with
    | 0 => kvLine name.toString (suppress description) optional
    | k + 1 =>
      let fields := elemMap.getD fieldType []
      let names := fields.map (fun elem => elem.name)
      let namesBlob := names.foldl (fun acc elem => acc ++ s!"`{elem}`" ++ ", ") "" |>.dropRight 2
      let innerList :=
        fields.map (fun elem => toIndendentList elem false elemMap k)
      let inner := innerList.foldl (fun acc elem => acc.append elem) nil
      let body := description ++ s!" Give a JSON list, with each element of the list is a JSON object with exactly one *key-value pair*, with the *key* one of {namesBlob}."
      if describeOptions then
        .kv_cons name.toString (body ++ " The descriptions for the choices of *key* and corresponding *value* are as follows:") optional inner .nil
      else kvLine name.toString body optional
  | .one_of name choices description =>
    match maxDepth with
    | 0 => kvLine name.toString (suppress description) optional
    | k + 1 =>
      let names := choices.map (fun elem => elem.name)
      let namesBlob := names.foldl (fun acc elem => acc ++ s!"`{elem}`" ++ ", ") "" |>.dropRight 2
      let body := description ++ s!" Give a JSON object with exactly one *key-value pair*, with the *key* one of {namesBlob}."
      let innerList :=
        choices.map (fun elem => toIndendentList elem false elemMap k)
      let inner := innerList.foldl (fun acc elem => acc.append elem) nil
      .kv_cons name.toString body optional inner .nil
  | .list_of name type =>
    match maxDepth with
    | 0 =>
      kvLine name.toString (suppress s!"A list of elements of type `{type.name}`.") optional
    | k + 1 =>
          let inner :=
              toIndendentList type false elemMap k
          .kv_cons name.toString s!"A list of elements of type `{type.name}`. Each element of type `{type.name}` is as follows:" optional inner .nil
  | .obj name fields optFields description =>
    match maxDepth with
    | k + 1 =>
      let innerList :=
        fields.map (fun elem => toIndendentList elem false elemMap k)
      let optInnerList :=
        optFields.map (fun elem => toIndendentList elem true elemMap k)
      let inner := innerList ++ optInnerList
        |>.foldl (fun acc elem => acc.append elem) nil
      .kv_cons name.toString (description ++ " Give a JSON object. The keys and corresponding values are as follows.") optional inner .nil
    | 0 => kvLine name.toString description optional

def suppressed (p: MathParaStructure)
  (elemMap : Std.HashMap Name <| List MathParaStructure := elemMap) (maxDepth: Nat := 5): List MathParaStructure :=
  match p with
  | .list _ fieldType describeOptions _ =>
    match maxDepth with
    | 0 => [p]
    | k + 1 =>
      if describeOptions then
        let fields := elemMap.getD fieldType []
        let innerList :=
          fields.map (fun elem => suppressed elem elemMap k)
        innerList.flatten
      else []
  | .obj _ fields optFields _ =>
    match maxDepth with
    | k + 1 =>
      let innerList :=
        fields.map (fun elem => suppressed elem elemMap k)
      let optInnerList :=
        optFields.map (fun elem => suppressed elem elemMap k)
      innerList.flatten ++ optInnerList.flatten
    | 0 => [p]
  | .list_of _ type =>
    match maxDepth with
    | 0 => [p]
    | k + 1 => suppressed type elemMap k
  | .one_of _ choices _ =>
    match maxDepth with
    | 0 => [p]
    | k + 1 =>
      choices.map (fun elem => suppressed elem elemMap k)
        |>.flatten
  | _ => []


end MathParaStructure

-- #eval MathParaStructure.mathDoc.toIndendentList |>.render


-- #eval MathParaStructure.mathDoc.suppressed (maxDepth := 4) |>.eraseDups |>.map (·.name)

def writeMathDoc : IO Unit :=
  IO.FS.writeFile "resources/MathDoc.md"
    (MathParaStructure.mathDoc.toIndendentList |>.render)

#eval writeMathDoc

def MathDoc.instructions (alertErrors : Bool := false) : IO String := do
  let jsonProofInstructions := MathParaStructure.mathDoc.toIndendentList |>.render
  let alert := if alertErrors then " Note that the proof may not be complete and may have some errors, which you should note in the appropriate fields." else ""
  return s!"The following is a custom JSON format, which we call `mathDocJSON`, for mathematical documents. Note that a document is translated to a JSON object with a single key 'math_document' and a corresponding value.\n\n {jsonProofInstructions}\n---\n\nWrite the following theorem and proof into `MathDocJSON` format.{alert} Output JSON only. The theorem and proof are as follows:"
