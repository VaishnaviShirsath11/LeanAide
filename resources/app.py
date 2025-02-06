from flask import Flask, request, jsonify
from sentence_transformers import SentenceTransformer
import json
import numpy as np
import os
from embed_picker import * 


app = Flask(__name__)


@app.route('/generate_embeddings', methods=['POST'])
def generate_embeddings_for_files():
    content = request.json
    json_file = content.get("json_file")
    jsonl_file = content.get("jsonl_file")

    if not json_file and not jsonl_file:
        return jsonify({"error": "Either JSON or JSONL file path is required."}), 400

    try:
        if json_file:
            json_data = sentences(json_file)
            docstrings = [entry['docString'] for entry in json_data if 'docString' in entry]
            save_embeddings(json_file, 'docString', 'all-MiniLM-L6-v2')

        if jsonl_file:
            jsonl_data = sentences(jsonl_file)
            descriptions = [entry['description'] for entry in jsonl_data if 'description' in entry]
            concise_descriptions = [entry['concise-description'] for entry in jsonl_data if 'concise-description' in entry]

            save_embeddings(jsonl_file, 'description', 'all-MiniLM-L6-v2')
            save_embeddings(jsonl_file, 'concise-description', 'all-MiniLM-L6-v2')

        return jsonify({
            "message": "Embeddings generated successfully"
        })

    except Exception as e:
        return jsonify({"error": str(e)}), 500
    

@app.route('/find_closest', methods=['POST'])
def find_closest_embeddings():
    content = request.json
    sentence = content.get("sentence")
    prompt_type = content.get("prompt_type")
    n = int(content.get("n"))

    if not sentence or prompt_type not in ['docString', 'description', 'concise-description'] or n <= 0:
        return jsonify({"error": "Invalid input"}), 400

    embeddings, data = load_embeddings(prompt_type, sentence, 'all-MiniLM-L6-v2')

    results = closest_embeddings(sentence, 'all-MiniLM-L6-v2', embeddings, data, n)

    return jsonify({"results": results})

if __name__ == "__main__":
    app.run(debug=True)
