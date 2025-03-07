import Lean
import Lean.Meta
import Lean.Elab
import LeanAide.Aides
import LeanAide.TheoremElab
import LeanAide.AesopTacticRuleSet
import Mathlib.Tactic
open Lean Meta Elab Parser Tactic

macro "add_aesop_power_tactic" tac:tactic : command =>
  let decl := mkIdentFrom tac.raw (`Aesop ++ (.mkSimple tac.raw.reprint.get!) ++ `tactic)
  `(command|
      @[aesop unsafe tactic (rule_sets [PowerTactic])] def $decl : TacticM Unit :=
        `(tactic| $tac) >>= evalTactic ∘ TSyntax.raw)

elab "add_aesop_power_tactics" tacs:tactic,* : command => do
  for tac in tacs.getElems do
    `(command| add_aesop_power_tactic $tac) >>= Command.elabCommand ∘ TSyntax.raw

-- add_aesop_power_tactics gcongr, ring, linarith, norm_num, positivity, polyrith, ext, norm_cast

/-!
## Equality of statements

An API based on Aesop. Should use a refined conguration for `aesop` to make it more effective.
-/

def provedEqual (e₁ e₂ : Expr) : MetaM Bool :=
  if e₁ == e₂ then return true else
 withoutModifyingState do
  let type ← mkEq e₁ e₂
  let mvar ← mkFreshExprMVar <| some type
  let mvarId := mvar.mvarId!
  let stx ← `(tactic| aesop)
  let res ←  runTactic mvarId stx
  let (remaining, _) := res
  return remaining.isEmpty

def provedEquiv (e₁ e₂ : Expr) : TermElabM Bool :=
  if e₁ == e₂ then return true else
  withoutModifyingState do
  try
  let type ← mkAppM ``Iff #[e₁, e₂]
  let mvar ← mkFreshExprMVar <| some type
  let mvarId := mvar.mvarId!
  let stx ← `(tactic| aesop)
  mvarId.withContext do
    checkTacticSafe mvarId stx
  catch _ => pure false

def provedSufficient (e₁ e₂ : Expr) : TermElabM Bool :=
  if e₁ == e₂ then return true else
  withoutModifyingState do
  let type ← mkArrow e₁ e₂
  let mvar ← mkFreshExprMVar <| some type
  let mvarId := mvar.mvarId!
  let stx ← `(tactic| aesop)
  mvarId.withContext do
    checkTacticSafe mvarId stx

def compareThms(s₁ s₂ : String)
  (levelNames : List Lean.Name := levelNames)
  : TermElabM <| Except String Bool := do
  let e₁ ← elabThm s₁ levelNames
  let e₂ ← elabThm s₂ levelNames
  match e₁ with
  | Except.ok e₁ => match e₂ with
    | Except.ok e₂ =>
        let p ←  (provedEqual e₁ e₂) <||>  (provedEquiv e₁ e₂)
        return Except.ok p
    | Except.error e₂ => return Except.error e₂
  | Except.error e₁ => return Except.error e₁

def compareThmsCore(s₁ s₂ : String)
  (levelNames : List Lean.Name := levelNames)
  : CoreM <| Except String Bool :=
    (compareThms s₁ s₂ levelNames).run'.run'

def compareThmExps(e₁ e₂: Expr)
  : TermElabM <| Except String Bool := do
      let p ← provedEqual e₁ e₂ <||>  provedEquiv e₁ e₂
      return Except.ok p

def compareThmExpsCore(e₁ e₂: Expr)
  : CoreM <| Except String Bool := do
      (compareThmExps e₁ e₂).run'.run'


def equalThms(s₁ s₂ : String)
  (levelNames : List Lean.Name := levelNames)
  : TermElabM Bool := do
  match ← compareThms s₁ s₂ levelNames with
  | Except.ok p => return p
  | Except.error _ => return false

def compareThmNameExprM(n: Name) (e: Expr)
  : TermElabM Bool := do
      let info ← getConstInfo n
      let e' := info.type
      IO.eprintln s!"Comparing {← ppExpr e} and {← ppExpr e'}"
      let f ← ppExpr e
      let f' ← ppExpr e'
      equalThms f.pretty f'.pretty

def compareThmNameExprCore(n: Name) (e: Expr)
  : CoreM Bool := do
      (compareThmNameExprM n e).run'.run'


def groupThms(ss: Array String)
  (levelNames : List Lean.Name := levelNames)
  : TermElabM (Array (Array String)) := do
    let mut groups: Array (Array String) := Array.empty
    for s in ss do
      match ← groups.findIdxM? (fun g =>
          equalThms s g[0]! levelNames) with
      |none  =>
        groups := groups.push #[s]
      | some j =>
        groups := groups.set! j (groups[j]!.push s)
    return groups

def groupThmExprs(ss: Array Expr)
  : TermElabM (Array (Array Expr)) := do
    let mut groups: Array (Array Expr) := Array.empty
    for s in ss do
      match ← groups.findIdxM? (fun g =>
          provedEquiv s g[0]! ) with
      |none  =>
        groups := groups.push #[s]
      | some j =>
        groups := groups.set! j (groups[j]!.push s)
    return groups

def groupThmExprsSorted(ss: Array Expr)
  : TermElabM (Array (Array Expr)) := do
  let gps ← groupThmExprs ss
  return gps.qsort (fun xs ys => xs.size > ys.size)

def groupTheoremsCore(ss: Array String)
  (levelNames : List Lean.Name := levelNames)
  : CoreM (Array (Array String)) :=
    (groupThms ss levelNames).run'.run'

def groupThmsSort(ss: Array String)
  (levelNames : List Lean.Name := levelNames)
  : TermElabM (Array (Array String)) := do
  let gps ← groupThms ss levelNames
  return gps.qsort (fun xs ys => xs.size > ys.size)

def groupThmsSortCore(ss: Array String)
  (levelNames : List Lean.Name := levelNames)
  : CoreM (Array (Array String)) :=
    (groupThmsSort ss levelNames).run'.run'

example : (∀ {A: Sort}, False → A) ↔ (∀ {A: Sort}, false = true → A) := by
  aesop

example : (∀ (a b c: Nat),
  a + (b + c) = (a + b) + c) ↔ (∀ (a b c: Nat), (a + b) + c = a + (b + c)) := by
  aesop


-- #eval compareThms "(s: String)(a b c: Nat): a + (b + c) = (a + b) + c" "(b a c: Nat): (a + b) + c = a + (b + c)"
