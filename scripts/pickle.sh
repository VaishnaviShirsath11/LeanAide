lake exe pickle_embeddings
# lake exe pickle_embeddings mathlib4-descs-embeddings.json description "description-embedding"
lake exe pickle_embeddings mathlib4-newdocs-docStrings-small-embeddings.json docString "embedding"

# lake exe pickle_embeddings mathlib4-descs-embeddings.json concise-description "concise-description-embedding"
# gcloud storage cp .lake/build/lib/mathlib4-*.olean  gs://leanaide_data/
