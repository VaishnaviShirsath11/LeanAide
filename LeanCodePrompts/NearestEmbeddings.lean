import Lean
import Cache.IO
import LeanAide.Aides
import LeanCodePrompts.EpsilonClusters
import Mathlib
open Std Lean

def distL2Sq' (v₁ : FloatArray) (v₂ : Array Float) : Float :=
  let squaredDiffs : Array Float :=
    (v₁.data.zip v₂).map (fun (x, y) => (x - y) * (x - y))
  squaredDiffs.foldl (Float.add) 0.0

def distL2Sq (v₁ : FloatArray) (v₂ : Array Float) : Float :=
    Id.run do
    let mut c := 0.0
    for i in [0:v₂.size] do
      c := c + (v₁[i]! - v₂[i]!) * (v₁[i]! - v₂[i]!)
    return c

def nearestDocsToDocEmbedding (data : Array <| (String × String) ×  FloatArray)
  (embedding : Array Float) (k : Nat)
  (dist: FloatArray → Array Float → Float := distL2Sq) : List (String × String) :=
  let pairs : Array <| ((String × String) × FloatArray) × Float :=
    bestWithCost data (fun (_, flArr) ↦ dist flArr embedding) k
  (pairs.map <| fun ((doc, _), _) => doc).toList


def nearestDocsToDocFullEmbedding (data : Array <| (String × String × Bool) ×  FloatArray)
  (embedding : Array Float) (k : Nat)
  (dist: FloatArray → Array Float → Float := distL2Sq)(penalty : Float) : List (String × String × Bool × Float) :=
  let tuples : Array <| ((String × String × Bool) × FloatArray) × Float :=
    bestWithCost data (fun ((_, _, isProp), flArr) ↦
        let d := dist flArr embedding
        if isProp then d else d * penalty) k
  (tuples.map <| fun (((doc, thm, isProp), _), d) => (doc, thm, isProp, d)).toList


def nearestDocsToDocFullEmbeddingConc (data : EmbedData)
  (embedding : Array Float) (k : Nat)
  (dist: FloatArray → Array Float → Float := distL2Sq)(penalty : Float) :
   IO <| List (String × String × Bool × String × Float) := do
  -- IO.eprintln s!"finding nearest embeddings (data size: {data.size})"
  -- let start ← IO.monoMsNow
  let tuples : Array <| ((String × String × Bool × String) × FloatArray) × Float ←
    bestWithCostConc data (fun ((_, _, isProp, _), flArr) ↦
        let d := dist flArr embedding
        if isProp then d else d * penalty) k
  -- let finish ← IO.monoMsNow
  -- IO.eprintln s!"found nearest embeddings in {finish - start} ms"
  return (tuples.map <| fun (((doc, thm, isProp, name), _), d) => (doc, thm, isProp, name, d)).toList

def embedQuery (doc: String) : IO <| Except String Json := do
  let key ← openAIKey
  let dataJs := Json.mkObj
      [("input", doc), ("model", "text-embedding-3-small")]
  let data := dataJs.pretty
  let out ←  Cache.IO.runCurl #["https://api.openai.com/v1/embeddings",
        "-H", "Authorization: Bearer " ++ key,
        "-H", "Content-Type: application/json",
        "--data", data]
  return Lean.Json.parse out

-- #eval embedQuery "There are infinitely many odd numbers"


def nearestDocsToDocFromEmb (data: Array ((String × String × Bool × String) × FloatArray))
    (queryRes?: Except String Json)(k : Nat)(dist: FloatArray → Array Float → Float := distL2Sq)
    (penalty: Float) : IO (List (String × String × Bool × String × Float)) := do
  -- IO.println "query complete"
  match queryRes? with
  | Except.ok queryRes =>
    -- IO.println s!"query result obtained"
    let queryData? := queryRes.getObjVal? "data"
    match queryData? with
    | Except.error error =>
        IO.println s!"no data in query result: {error}"
        panic s!"no data in query result: {error}"
    | Except.ok queryDataArr =>
      -- IO.println s!"data in query result obtained"
      let queryData := queryDataArr.getArrVal? 0 |>.toOption.get!
      match queryData.getObjValAs? (Array Float) "embedding" with
      | Except.ok queryEmbedding =>
        -- IO.println s!"embedding in query result obtained"
        let res ←
          nearestDocsToDocFullEmbeddingConc data queryEmbedding k dist penalty
        -- IO.println s!"getNearestDocsToEmbedding complete: {res}"
        pure res
      | Except.error error =>
        panic s!"no embedding in query result: {error} in {queryData}"
  | Except.error err => panic! s!"error querying openai: {err}"

def nearestDocsToDocFull (data: Array ((String × String × Bool × String) × FloatArray))
    (doc: String)(k : Nat)(dist: FloatArray → Array Float → Float := distL2Sq)
    (penalty: Float) : IO (List (String × String × Bool × String × Float)) := do
  let start ← IO.monoMsNow
  let queryRes? ← embedQuery doc
  let finish ← IO.monoMsNow
  IO.eprintln s!"query time: {finish - start}"
  nearestDocsToDocFromEmb data queryRes? k dist penalty
