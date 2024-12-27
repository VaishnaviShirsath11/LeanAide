import Lean

open Lean

syntax:10 (name := lxor) term:10 " LXOR " term:11 : term

@[macro lxor] def lxorImpl : Macro
  | `($l:term LXOR $r:term) => `(!$l && $r) -- we can use the quotation mechanism to create `Syntax` in macros
  | _ => Macro.throwUnsupported

#eval true LXOR true -- false
#eval true LXOR false -- false
#eval false LXOR true -- true
#eval false LXOR false -- false


syntax:10 (name := uniq) "∃!" "(" term:10 "," term:11 "," term:12 ")" :term

@[macro uniq_exists] def u_exists : Macro
  | `(∃! ($l:term, $r:term, $s:term)) => `(∃! $l, ∃! $r, ∃! $s)
  | _ => Macro.throwUnsupported

example : ∀ {p : ℤ}, 1 < p → (∀ x, 0 < x ∧ x < p → Nat.Prime (x ^ 2 - x + p)) → ∃! (a b c : ℤ), b ^ 2 - 4 * a * c = 1 - 4 * p ∧ 0 < a ∧ a ≤ c ∧ -a ≤ b ∧ b < a := by sorry
