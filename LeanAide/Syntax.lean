import LeanCodePrompts.Translate
import Lake.Toml.ParserUtil

open Lean Meta Elab Term PrettyPrinter Tactic Command Parser

namespace LeanAide.Meta

syntax (name := thmCommand) "#theorem" (ident)? str : command
@[command_elab thmCommand] def thmCommandImpl : CommandElab :=
  fun stx => Command.liftTermElabM do
  match stx with
  | `(command| #theorem $s:str) =>
    let s := s.getString
    go s stx none
  | `(command| #theorem $name:ident $s:str) =>
    let s := s.getString
    let name := name.getId
    go s stx (some name)

  | _ => throwUnsupportedSyntax
  where go (s: String) (stx: Syntax) (name? : Option Name) : TermElabM Unit := do
    if s.endsWith "." then
      let translator : Translator := {server := ← chatServer, pb := PromptExampleBuilder.embedBuilder (← promptSize) (← conciseDescSize) 0, params := ← chatParams}
      let (js, _) ←
        translator.getLeanCodeJson  s |>.run' {}
      let e ← jsonToExpr' js (← greedy) !(← chatParams).stopColEq |>.run' {}
      logTimed "obtained expression"
      let stx' ← delab e
      logTimed "obtained syntax"
      let name ← match name? with
      | some name => pure name
      | none =>
        let query := s!"Give a name following the conventions of the Lean Prover and Mathlib for the theorem: \n{s}\n\nGive ONLY the name of the theorem."
        let namesArr ←  translator.server.mathCompletions query 1
        let llm_name := namesArr.get! 0 |>.replace "`" ""
          |>.replace "\""  "" |>.trim
        logInfo llm_name
        pure llm_name.toName
      let name := mkIdent name
      let cmd ← `(command| theorem $name : $stx' := by sorry)
      TryThis.addSuggestion stx cmd
      logTimed "added suggestion"
      return
    else
      logWarning "To translate a theorem, end the string with a `.`."

syntax (name := askCommand) "#ask" (num)? str : command
@[command_elab askCommand] def askCommandImpl : CommandElab :=
  fun stx => Command.liftTermElabM do
  match stx with
  | `(command| #ask $s:str) =>
    let s := s.getString
    go s none
  | `(command| #ask $n:num $s:str) =>
    let s := s.getString
    let n := n.getNat
    go s n
  | _ => throwUnsupportedSyntax
  where go (s: String) (n?: Option Nat) : TermElabM Unit := do
    if s.endsWith "." || s.endsWith "?" then
      let server ← chatServer
      let n := n?.getD 3
      let responses ← server.mathCompletions s (n := n)
      for r in responses do
        logInfo r
    else
      logWarning "To make a query, end the string with a `.` or `?`."

/-!
# Proof Syntax
-/
open Lake.Toml
def proofFn : ParserFn := takeWhile1Fn fun c => c != '∎'

def proofBodyInit : Parser :=
  { fn := rawFn proofFn}

def proofBody : Parser := andthen proofBodyInit "∎"

@[combinator_parenthesizer proofBodyInit] def proofBodyInit.parenthesizer := PrettyPrinter.Parenthesizer.visitToken
@[combinator_formatter proofBodyInit] def proofBodyInit.formatter := PrettyPrinter.Formatter.visitAtom Name.anonymous

syntax (name := sourceCmd) withPosition("#proof" ppLine (colGt (str <|> proofBody) )) : command

def mkProofStx (s: String) : Syntax :=
  mkNode ``sourceCmd #[mkAtom "#proof", mkAtom s, mkAtom "∎"]

@[command_elab sourceCmd] def elabSource : CommandElab :=
  fun stx => Command.liftTermElabM do
  match stx with
  | `(command| #proof $t:proofBodyInit ∎) =>
    let s := stx.getArgs[1]!.reprint.get!.trim
    logInfo m!"Syntax: {stx}"
    let stx' := mkProofStx "Some proof."
    logInfo m!"Extract: {s}"
    logInfo m!"Details: {repr stx}"
    logInfo m!"{stx'}"
  | _ => throwUnsupportedSyntax

/-!
# From Descriptions
-/
syntax (name:= textProof) withPosition("#proof" ppLine (str <|> proofBody)) : tactic

open Tactic
@[tactic textProof] def textProofImpl : Tactic :=
  fun _ => do
  evalTactic (← `(tactic|sorry))

example : True := by
  #proof "trivial"

open Tactic Translator
elab "what" : tactic => do
  let goal ← getMainGoal
  let type ← relLCtx goal
  logInfo m!"goal : {type}"
  let some (transl, _, _) ← getTypeDescriptionM type {} | throwError "No description from LLM"
  logInfo transl

syntax (name:= whyTac) "why" : tactic
@[tactic whyTac] def whyTacImpl : Tactic := fun stx => do
  let goal ← getMainGoal
  let type ← relLCtx goal
  logInfo m!"goal : {type}"
  let some (transl, _, _) ← getTypeDescriptionM type {} | throwError "No description from LLM"
  let server : ChatServer := ChatServer.default
  let proof ← server.prove transl (n := 1)
  logInfo m!"Theorem: {transl}"
  logInfo m!"Proof: {proof}"
  -- let pfStx := Syntax.mkStrLit proof[0]!
  -- let proofTac ← `(tactic| #proof $pfStx)
  let proofTac : Syntax.Tactic := ⟨mkProofStx proof[0]!⟩
  TryThis.addSuggestion stx proofTac

syntax (name:= addDocs) "#doc" "theorem" ident declSig declVal : command

open Command in
@[command_elab addDocs] def elabAddDocsImpl : CommandElab := fun stx =>
  match stx with
  | `(#doc theorem $id:ident $ty:declSig $val:declVal) =>
    Command.liftTermElabM do
    let name := id.getId
    let stx' ← `(command| theorem $id:ident $ty $val)
    let fmt ← PrettyPrinter.ppCommand stx'
    let type : Expr ← elabFrontThmExprM fmt.pretty name true
    let some (desc, _) ←
      Translator.getTypeDescriptionM type {} | throwError "No description found for type {type}"
    let docs := mkNode ``Lean.Parser.Command.docComment #[mkAtom "/--", mkAtom (desc ++ " -/")]
    let stx' ← `(command| $docs:docComment theorem $id:ident $ty $val)
    TryThis.addSuggestion stx stx'
  | _ => throwError "unexpected syntax"
