import Lean
import Mathlib
import Plausible
import LeanSearchClient.Syntax

open Lean Meta Elab Term PrettyPrinter Tactic Parser

@[aesop unsafe 10% tactic]
def myRing : TacticM Unit := do
  evalTactic (← `(tactic|ring))

attribute [aesop simp] Real.sin_two_mul

open Real
example : ∀(x: ℝ), (x + sin x + cos (tan x)) * 2 =
  2 * cos (tan x) + 2 * x + sin x + sin x := by
  aesop


example : ∀(x: ℝ), ((x + sin x + cos (tan x)) * 2)/ (x + 1) =
  (2 * cos (tan x) + 2 * x + sin x + sin x)/ (x + 1) := by
  intro x
  ring

example : ∀ x: ℝ, (x + sin (2 * (cos x))) / (tan x + 1) =
  (sin (cos x) * cos (cos x) + x)/(tan x + 1) +
  (cos (cos x) * sin (cos x))/ (tan x + 1) := by
  aesop

#check HasDerivAt

#check deriv -- 0 if the function is not differentiable at x.

-- code of Adam Topaz
def parseFloat (s : String) : Except String Float :=
  match Lean.Json.parse s with
    | .ok (.num t) => .ok t.toFloat
    | _ => throw "Failed to parse as float."

#eval parseFloat "25.123651"

def checkTermType (s: String) (type: Expr) : TermElabM Bool := do
  let termStx := Parser.runParserCategory (← getEnv) `term s
  match termStx with
  | Except.ok termStx =>
    withoutErrToSorry do
      try
        let _ ← elabTermEnsuringType termStx type
        return true
      catch err =>
        logWarning m!"{err.toMessageData}"
        return false
  | Except.error err =>
    logWarning m!"{err}"
    return false

def checkTermNat (s: String) : TermElabM Bool := do
  let type :=  Lean.mkConst `Nat
  checkTermType s type

#eval checkTermNat "3" -- true
#eval checkTermNat "3 + 4" -- true
#eval checkTermNat "3 + 4 + 5" -- true
#eval checkTermNat "3 + 4 + 5 + six" -- false
#eval checkTermNat "Nat" -- false

def diffNat (n: Nat)(m: Nat := n) : Nat :=
  n - m

#eval diffNat 4 3

#eval diffNat 4

opaque P : Prop

axiom p_eq_true : P = True

example  : P := by
  aesop (add unsafe (by rw [p_eq_true]))

#check Aesop.Frontend.Parser.«tactic_clause(Add_)»

open Lean.Parser.Tactic

def egStx : MetaM <| TSyntax `tactic := do
  let tac ← `(tacticSeq| rw [p_eq_true])
  let n := Syntax.mkNumLit <| toString (10 + 20)
  let stx ← `(rule_expr|(unsafe $n% by $tac))
  let stx' ← `(rule_expr| unsafe apply Nat.add)
  let stx₁ ← `(rule_expr| unsafe 10% Nat.add)
  let cl ← `(tactic_clause| (add $stx))
  let cls := #[cl, cl]
  let check ← `(tactic| aesop $cls*)
  `(tactic| aesop (add unsafe [$stx, $stx']))

#eval egStx

def myName: MetaM Name :=  do
  let env ← getEnv
  pure env.mainModule


#eval myName


initialize mn : IO.Mutex Nat
        ← IO.Mutex.new 0

def mnVal : IO Nat := mn.atomically do
  let m ← get
  pure m

def mnIncr : IO Unit := mn.atomically do
  modify (· + 1)

def mnSet (n: Nat) : IO Unit := mn.atomically do
  set n

structure Description (α : Sort u) where
  text : String

example : Description Prop := ⟨ "This is a proposition" ⟩ -- it is not
example : Description Nat := ⟨ "Three" ⟩ -- again, it is not

opaque Description.extract [Inhabited α] : Description α → α

def quote [Inhabited α] (text: String) : α :=
  Description.extract ⟨ text ⟩ -- arbitrary

def not_three : Nat := Description.extract ⟨ "Three" ⟩ -- 0

def not_four : Nat := quote "four" -- 0

#reduce not_four -- Description.extract { text := "four" }

def descString : Expr → MetaM String := fun expr =>
  do
    let type ← inferType expr
    let descType ← mkAppM ``Description #[type]
    let mvar ←  mkFreshExprMVar (some descType)
    let sExp ←  mkAppM ``Description.extract #[mvar]
    if ← isDefEq sExp expr then
      match (← whnf mvar).getAppFnArgs with
      | (``Description.mk, #[_, Expr.lit (Literal.strVal s)]) => pure s
      | _ => throwError m!"{mvar} is not a string"
    else
      throwError m!"{expr} not from a description"

elab "desc"  x:term : term => do
  let x ← elabTerm x none
  let s ← descString x
  return Expr.lit (Literal.strVal s)

#check desc not_four

def sampleNats (lo hi n: Nat) : MetaM (Format) := do
  let sample ←  List.replicate n 0 |>.mapM fun _ =>
    IO.rand lo hi
  let s := sample.toString
  let stx? := Parser.runParserCategory (← getEnv) `term s
  match stx? with
  | Except.ok stx =>
    let stx : TSyntax `term := ⟨ stx ⟩
    let lst := mkIdent `List
    let nat := mkIdent `Nat
    let sample := mkIdent `sample
    let result ← `(command|def $sample : $lst $nat := $stx)
    logInfo m!"{← ppCommand result}.pretty"
    ppCommand result
  | Except.error err =>
    throwError m!"{err}"

#eval sampleNats 0 10 5
#print max_min_distrib_left
#print max

#check Lean.Environment.getModuleIdx?
def modules : CoreM (Array Name) := do
  let env ← getEnv
  let mods := env.header.moduleNames
  let mods := mods.filter <| fun name => (`Lean).isPrefixOf name
  pure mods

#eval modules

def someData : CoreM (List (Array Name)) := do
  let env ← getEnv
  let mods := env.header.moduleData |>.toList.take 20
  let names := mods.map (fun data => data.constNames)
  return names

#eval someData
#check Array.zip
#check findDocString? -- findDocString? : Environment → Name → Option String
#check Nat.Prime

#check getModuleDoc? -- getModuleDoc? : Environment → Name → Option String

example : 2 ≤ 1 := by
  try plausible
  sorry

-- example : 2 * (k + 1) * (2 * (k + 1)) = 2 * (2 * k ^ 2 + 3 * k + 1) := by plausible

#check Nat.infinite_setOf_prime
#check lambdaTelescope

def omitEg : MetaM Syntax := do
  let stx ← `(⋯)
  let stx' ← `(($stx : Nat))
  pure stx'

#check delab
#check withOptions
#check Lean.exprDependsOn

set_option pp.match false in
set_option pp.proofs false in
set_option pp.proofs.withType true in
#print List.get

set_option pp.proofs.threshold 40

set_option pp.match false in
set_option pp.proofs false in
set_option pp.proofs.withType true in
#print List.sizeOf_dedupKeys

#check Syntax.getKind

example (P Q: Prop) : P := by
  have ass : Q := sorry
  have imp : Q → P := sorry
  aesop?

example (P : Nat → Prop)(f : Nat → Nat): P (f 5) := by
  have ass : ∀ n, P n := sorry
  aesop?

example (p₁ p₂ p₃ q: Prop) : q := by
  have : p₁ ∨ p₂ ∨ p₃ := by sorry
  have : p₁ → q := by sorry
  have : p₂ → q := by sorry
  have : p₃ → q := by sorry
  aesop?

example (n: Nat) (q: Prop) : q := by
  have : (n = 1) ∨ (n = 2) ∨ (n = 3) := by sorry
  have : (n = 1) → q := by sorry
  have : (n = 3) → q := by sorry
  have : (n = 4) → q := by sorry
  have : (n = 2) → q := by sorry
  aesop

example : True := by
  by_cases 1 = 2
  case pos => simp
  case neg => simp

#check Nat.exists_infinite_primes
-- #moogle "There are infinitely many even numbers."

#check False.elim

def lineFn : ParserFn := takeUntilFn fun c => c == '\n'

def lineBody : Parser :=
  { fn := rawFn lineFn}

@[combinator_parenthesizer lineBody] def lineBody.parenthesizer := PrettyPrinter.Parenthesizer.visitToken
@[combinator_formatter lineBody] def lineBody.formatter := PrettyPrinter.Formatter.visitAtom Name.anonymous


declare_syntax_cat block
syntax (name := block) lineBody*  : block
open Command

syntax (name := sourceCmd) withPosition("#source" ppLine (colGt commentBody)) : command

open Command
@[command_elab sourceCmd] def elabSource : CommandElab :=
  fun stx => Command.liftTermElabM do
  let s := stx.getArgs[1]!.reprint.get!.trim.dropRight 2
  logInfo m!"{s}"

#check 1

#source
  This is not the most elegant way

  but it works.
  -/

#check 1
