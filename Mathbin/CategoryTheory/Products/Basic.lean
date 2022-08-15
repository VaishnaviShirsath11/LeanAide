/-
Copyright (c) 2017 Scott Morrison. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Stephen Morgan, Scott Morrison
-/
import Mathbin.CategoryTheory.EqToHom

/-!
# Cartesian products of categories

We define the category instance on `C × D` when `C` and `D` are categories.

We define:
* `sectl C Z` : the functor `C ⥤ C × D` given by `X ↦ ⟨X, Z⟩`
* `sectr Z D` : the functor `D ⥤ C × D` given by `Y ↦ ⟨Z, Y⟩`
* `fst`       : the functor `⟨X, Y⟩ ↦ X`
* `snd`       : the functor `⟨X, Y⟩ ↦ Y`
* `swap`      : the functor `C × D ⥤ D × C` given by `⟨X, Y⟩ ↦ ⟨Y, X⟩`
    (and the fact this is an equivalence)

We further define `evaluation : C ⥤ (C ⥤ D) ⥤ D` and `evaluation_uncurried : C × (C ⥤ D) ⥤ D`,
and products of functors and natural transformations, written `F.prod G` and `α.prod β`.
-/


namespace CategoryTheory

-- declare the `v`'s first; see `category_theory.category` for an explanation
universe v₁ v₂ v₃ v₄ u₁ u₂ u₃ u₄

section

variable (C : Type u₁) [Category.{v₁} C] (D : Type u₂) [Category.{v₂} D]

/-- `prod C D` gives the cartesian product of two categories.

See <https://stacks.math.columbia.edu/tag/001K>.
-/
-- the generates simp lemmas like `id_fst` and `comp_snd`
@[simps (config := { notRecursive := [] })]
instance prod : Category.{max v₁ v₂} (C × D) where
  Hom := fun X Y => (X.1 ⟶ Y.1) × (X.2 ⟶ Y.2)
  id := fun X => ⟨𝟙 X.1, 𝟙 X.2⟩
  comp := fun _ _ _ f g => (f.1 ≫ g.1, f.2 ≫ g.2)

/-- Two rfl lemmas that cannot be generated by `@[simps]`. -/
@[simp]
theorem prod_id (X : C) (Y : D) : 𝟙 (X, Y) = (𝟙 X, 𝟙 Y) :=
  rfl

@[simp]
theorem prod_comp {P Q R : C} {S T U : D} (f : (P, S) ⟶ (Q, T)) (g : (Q, T) ⟶ (R, U)) :
    f ≫ g = (f.1 ≫ g.1, f.2 ≫ g.2) :=
  rfl

theorem is_iso_prod_iff {P Q : C} {S T : D} {f : (P, S) ⟶ (Q, T)} : IsIso f ↔ IsIso f.1 ∧ IsIso f.2 := by
  constructor
  · rintro ⟨g, hfg, hgf⟩
    simp at hfg hgf
    rcases hfg with ⟨hfg₁, hfg₂⟩
    rcases hgf with ⟨hgf₁, hgf₂⟩
    exact ⟨⟨⟨g.1, hfg₁, hgf₁⟩⟩, ⟨⟨g.2, hfg₂, hgf₂⟩⟩⟩
    
  · rintro ⟨⟨g₁, hfg₁, hgf₁⟩, ⟨g₂, hfg₂, hgf₂⟩⟩
    dsimp'  at hfg₁ hgf₁ hfg₂ hgf₂
    refine' ⟨⟨(g₁, g₂), _, _⟩⟩ <;>
      · simp <;> constructor <;> assumption
        
    

section

variable {C D}

/-- Construct an isomorphism in `C × D` out of two isomorphisms in `C` and `D`. -/
@[simps]
def Iso.prod {P Q : C} {S T : D} (f : P ≅ Q) (g : S ≅ T) : (P, S) ≅ (Q, T) where
  Hom := (f.Hom, g.Hom)
  inv := (f.inv, g.inv)

end

end

section

variable (C : Type u₁) [Category.{v₁} C] (D : Type u₁) [Category.{v₁} D]

/-- `prod.category.uniform C D` is an additional instance specialised so both factors have the same
universe levels. This helps typeclass resolution.
-/
instance uniformProd : Category (C × D) :=
  CategoryTheory.prod C D

end

-- Next we define the natural functors into and out of product categories. For now this doesn't
-- address the universal properties.
namespace Prod

/-- `sectl C Z` is the functor `C ⥤ C × D` given by `X ↦ (X, Z)`. -/
@[simps]
def sectl (C : Type u₁) [Category.{v₁} C] {D : Type u₂} [Category.{v₂} D] (Z : D) : C ⥤ C × D where
  obj := fun X => (X, Z)
  map := fun X Y f => (f, 𝟙 Z)

/-- `sectr Z D` is the functor `D ⥤ C × D` given by `Y ↦ (Z, Y)` . -/
@[simps]
def sectr {C : Type u₁} [Category.{v₁} C] (Z : C) (D : Type u₂) [Category.{v₂} D] : D ⥤ C × D where
  obj := fun X => (Z, X)
  map := fun X Y f => (𝟙 Z, f)

variable (C : Type u₁) [Category.{v₁} C] (D : Type u₂) [Category.{v₂} D]

/-- `fst` is the functor `(X, Y) ↦ X`. -/
@[simps]
def fst : C × D ⥤ C where
  obj := fun X => X.1
  map := fun X Y f => f.1

/-- `snd` is the functor `(X, Y) ↦ Y`. -/
@[simps]
def snd : C × D ⥤ D where
  obj := fun X => X.2
  map := fun X Y f => f.2

/-- The functor swapping the factors of a cartesian product of categories, `C × D ⥤ D × C`. -/
@[simps]
def swap : C × D ⥤ D × C where
  obj := fun X => (X.2, X.1)
  map := fun _ _ f => (f.2, f.1)

/-- Swapping the factors of a cartesion product of categories twice is naturally isomorphic
to the identity functor.
-/
@[simps]
def symmetry : swap C D ⋙ swap D C ≅ 𝟭 (C × D) where
  Hom := { app := fun X => 𝟙 X }
  inv := { app := fun X => 𝟙 X }

/-- The equivalence, given by swapping factors, between `C × D` and `D × C`.
-/
@[simps]
def braiding : C × D ≌ D × C :=
  Equivalence.mk (swap C D) (swap D C)
    (NatIso.ofComponents
      (fun X =>
        eqToIso
          (by
            simp ))
      (by
        tidy))
    (NatIso.ofComponents
      (fun X =>
        eqToIso
          (by
            simp ))
      (by
        tidy))

instance swapIsEquivalence : IsEquivalence (swap C D) :=
  (by
    infer_instance : IsEquivalence (braiding C D).Functor)

end Prod

section

variable (C : Type u₁) [Category.{v₁} C] (D : Type u₂) [Category.{v₂} D]

/-- The "evaluation at `X`" functor, such that
`(evaluation.obj X).obj F = F.obj X`,
which is functorial in both `X` and `F`.
-/
@[simps]
def evaluation : C ⥤ (C ⥤ D) ⥤ D where
  obj := fun X => { obj := fun F => F.obj X, map := fun F G α => α.app X }
  map := fun X Y f => { app := fun F => F.map f, naturality' := fun F G α => Eq.symm (α.naturality f) }

/-- The "evaluation of `F` at `X`" functor,
as a functor `C × (C ⥤ D) ⥤ D`.
-/
@[simps]
def evaluationUncurried : C × (C ⥤ D) ⥤ D where
  obj := fun p => p.2.obj p.1
  map := fun x y f => x.2.map f.1 ≫ f.2.app y.1
  map_comp' := fun X Y Z f g => by
    cases g
    cases f
    cases Z
    cases Y
    cases X
    simp only [← prod_comp, ← nat_trans.comp_app, ← functor.map_comp, ← category.assoc]
    rw [← nat_trans.comp_app, nat_trans.naturality, nat_trans.comp_app, category.assoc, nat_trans.naturality]

end

variable {A : Type u₁} [Category.{v₁} A] {B : Type u₂} [Category.{v₂} B] {C : Type u₃} [Category.{v₃} C] {D : Type u₄}
  [Category.{v₄} D]

namespace Functor

/-- The cartesian product of two functors. -/
@[simps]
def prod (F : A ⥤ B) (G : C ⥤ D) : A × C ⥤ B × D where
  obj := fun X => (F.obj X.1, G.obj X.2)
  map := fun _ _ f => (F.map f.1, G.map f.2)

/-- Similar to `prod`, but both functors start from the same category `A` -/
/- Because of limitations in Lean 3's handling of notations, we do not setup a notation `F × G`.
   You can use `F.prod G` as a "poor man's infix", or just write `functor.prod F G`. -/
@[simps]
def prod' (F : A ⥤ B) (G : A ⥤ C) : A ⥤ B × C where
  obj := fun a => (F.obj a, G.obj a)
  map := fun x y f => (F.map f, G.map f)

section

variable (C)

/-- The diagonal functor. -/
def diag : C ⥤ C × C :=
  (𝟭 C).prod' (𝟭 C)

@[simp]
theorem diag_obj (X : C) : (diag C).obj X = (X, X) :=
  rfl

@[simp]
theorem diag_map {X Y : C} (f : X ⟶ Y) : (diag C).map f = (f, f) :=
  rfl

end

end Functor

namespace NatTrans

/-- The cartesian product of two natural transformations. -/
@[simps]
def prod {F G : A ⥤ B} {H I : C ⥤ D} (α : F ⟶ G) (β : H ⟶ I) : F.Prod H ⟶ G.Prod I where
  app := fun X => (α.app X.1, β.app X.2)
  naturality' := fun X Y f => by
    cases X
    cases Y
    simp only [← functor.prod_map, ← Prod.mk.inj_iff, ← prod_comp]
    constructor <;> rw [naturality]

/- Again, it is inadvisable in Lean 3 to setup a notation `α × β`;
   use instead `α.prod β` or `nat_trans.prod α β`. -/
end NatTrans

/-- `F.flip` composed with evaluation is the same as evaluating `F`. -/
@[simps]
def flipCompEvaluation (F : A ⥤ B ⥤ C) (a) : F.flip ⋙ (evaluation _ _).obj a ≅ F.obj a :=
  (NatIso.ofComponents fun b => eqToIso rfl) <| by
    tidy

end CategoryTheory
