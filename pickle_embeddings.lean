import LeanCodePrompts.Embeddings
import Batteries.Util.Pickle

def main (args: List String) : IO Unit := do
  let fileName := args.getD 0 "mathlib4-newdocs-docStrings-small-embeddings.json"
  let descField := args.getD 1 "docString"
  let embedField := args.getD 2 "embedding"
  let blob ←
    IO.FS.readFile <|
      System.mkFilePath ["resources", fileName]
  let embArrFullDocs ← readEmbeddingsFullDocsArray blob descField embedField
  let outPath ← picklePathnew
  pickle outPath embArrFullDocs
  IO.println s!"Pickle file written to {outPath} for field {descField}"
