import json
import jsonlines
from openai import OpenAI
from scripts.queries import azure_embed

def ada_embeddings():
    inp = open("resources/mathlib4-prompts.json", 'r', encoding='utf-8')
    out = open("rawdata/mathlib4-prompts-embeddings.json", 'w', encoding='utf-8')

    # read `inp` and extract json
    js = json.load(inp)
    count = 0
    print(len(js))
    # for each line, compute the embeddings
    for l in js:
        # response = openai.Embedding.create(
        # input=l["docString"],
        # model="text-embedding-ada-002"
        # )
        # embedding = response['data'][0]['embedding']
        embedding = azure_embed(l["docString"])
        l["embedding"] = embedding
        print(l["docString"])
        count = count + 1
        print(f"Completed {count} out of {len(js)}")

    # write the embeddings to `out`
    json.dump(js, out, indent=4, ensure_ascii=False)
    # close `inp` and `out`
    inp.close()
    out.close()

def small_embeddings():
    client = OpenAI()
    out_lines = []
    count = 0

    with open("rawdata/mathlib4-embeddings-small.json", 'w', encoding='utf-8') as out:
        with jsonlines.open("resources/mathlib4-descs.jsonl", 'r') as reader:
            for l in reader:
                for field in ["docString", "description", "concise-description"]:
                    if field in l and l[field]:
                        response = client.embeddings.create(
                            input=l[field],
                            model="text-embedding-3-small"
                        )
                        embedding = response.data[0].embedding
                        l[field + "-embedding"] = embedding
                        print("Field: ", field)
                        print(l[field])
                    else:
                        print(f"Field {field} not found")
                out_lines.append(l)
                count = count + 1
                print(f"Completed {count}")
            json.dump(out_lines, out, indent=4, ensure_ascii=False)
