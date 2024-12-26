import Lean
import Mathlib
import LeanAide.AesopSyntax
import LeanAide.CheckedSorry
open LeanAide.Meta Lean Meta Elab

open Lean Meta Tactic Parser.Tactic

def powerTactics : CoreM <| List <| TSyntax ``tacticSeq := do
  return [← `(tacticSeq| omega), ← `(tacticSeq| ring), ← `(tacticSeq| linarith), ← `(tacticSeq| norm_num), ← `(tacticSeq| positivity), ← `(tacticSeq| gcongr), ←`(tacticSeq| contradiction)]

def powerRules (weight sorryWeight strongSorryWeight: Nat) : MetaM <| List <| TSyntax `Aesop.rule_expr := do
  let tacs ← powerTactics
  let rules ← tacs.mapM fun tac => AesopSyntax.RuleExpr.ofTactic tac (some weight)
  return rules ++ [← AesopSyntax.RuleExpr.sorryRule sorryWeight, ← AesopSyntax.RuleExpr.strongSorryRule strongSorryWeight]

def suggestionRules (names: List Name) (weight: Nat := 90)
    (rwWeight: Nat := 50) : MetaM <| List <| TSyntax `Aesop.rule_expr := do
  let tacs ← names.mapM fun n => AesopSyntax.RuleExpr.ofName n (some weight)
  let rws ← names.mapM fun n => AesopSyntax.RuleExpr.rewriteName n (some rwWeight)
  let rwsFlip ← names.mapM fun n => AesopSyntax.RuleExpr.rewriteName n (some rwWeight) true
  return tacs ++ rws ++ rwsFlip

def aesopTactic (weight sorryWeight strongSorryWeight: Nat) (names: List Name := []) :
    MetaM <| Syntax.Tactic := do
  let rules ← powerRules weight sorryWeight strongSorryWeight
  let sugRules ← suggestionRules names
  AesopSyntax.fold (rules ++ sugRules).toArray

syntax (name := auto_aesop) "auto?" ("[" ident,* "]")? : tactic

-- should configure 90, 50, 10
@[tactic auto_aesop] def autoAesopImpl : Tactic := fun stx => do
unless (← getGoals).isEmpty do
  match stx with
  | `(tactic| auto?) => do
    let tac ← aesopTactic 90 50 10
    evalTactic tac
  | `(tactic| auto? [$names,*]) => do
    let names := names.getElems.map fun n => n.getId
    let tac ← aesopTactic 90 50 10 names.toList
    evalTactic tac
  | _ => throwUnsupportedSyntax
